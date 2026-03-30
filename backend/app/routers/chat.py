"""AI companion chat endpoint with RAG retrieval and safety guardrails."""

from __future__ import annotations

import json

import httpx
import structlog
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sse_starlette.sse import EventSourceResponse

from app.config import settings
from app.database import get_db
from app.dependencies import get_current_user
from app.models import Profile
from app.rag import build_context, retrieve
from app.rate_limit import limiter
from app.schemas import ChatRequest, ChatResponse, ChatSource

logger = structlog.get_logger()
router = APIRouter(prefix="/ai", tags=["ai-chat"])

OPENAI_URL = f"{settings.openai_base_url}/chat/completions"

SYSTEM_PROMPT = """Ты - Аура, ментальный компаньон в приложении Meditator.

ТВОЯ РОЛЬ:
- Ты тёплый, поддерживающий и внимательный собеседник
- Ты помогаешь пользователям разобраться в своих эмоциях, мыслях и переживаниях
- Ты используешь техники когнитивно-поведенческой терапии (КПТ), осознанности (mindfulness), рефлексии и валидации эмоций
- Ты говоришь на русском языке

ТОН ОБЩЕНИЯ:
- Тёплый, но не панибратский
- Уважительный и профессиональный
- Эмпатичный: всегда сначала валидируй чувства пользователя
- Конкретный: давай практические советы и упражнения
- Краткий: отвечай по существу, не растекайся

СТРУКТУРА ОТВЕТА:
1. Валидация чувств (1-2 предложения)
2. Инсайт или перспектива (основная часть)
3. Практический совет или упражнение (если уместно)

СТРОГИЕ ПРАВИЛА (GUARDRAILS):
- НИКОГДА не ставь диагнозов (не говори "у вас депрессия", "это тревожное расстройство")
- НИКОГДА не назначай лекарства и не обсуждай медикаменты
- При упоминании суицидальных мыслей, самоповреждения или насилия:
  * Вырази заботу и поддержку
  * Настоятельно рекомендуй обратиться к специалисту
  * Дай номер телефона доверия: 8-800-2000-122 (бесплатно, круглосуточно)
- Не заменяй психотерапевта — напоминай, что ты AI-компаньон
- Не давай юридических или финансовых советов
- Если пользователь спрашивает не по теме ментального здоровья, мягко перенаправь разговор

КОНТЕКСТ ИЗ БАЗЫ ЗНАНИЙ:
{rag_context}"""

CRISIS_KEYWORDS = [
    "суицид", "покончить", "убить себя", "не хочу жить", "самоубийств",
    "повеситься", "прыгнуть", "порезать", "самоповрежден", "вскрыть вены",
    "suicide", "kill myself", "end my life", "self-harm",
]


def _is_crisis(text: str) -> bool:
    lower = text.lower()
    return any(kw in lower for kw in CRISIS_KEYWORDS)


CRISIS_ADDENDUM = (
    "\n\nВАЖНО: В сообщении пользователя обнаружены признаки кризисного состояния. "
    "Обязательно: 1) вырази искреннюю заботу, 2) предложи позвонить на телефон доверия "
    "8-800-2000-122, 3) рекомендуй обратиться к специалисту. НЕ обесценивай переживания."
)


@router.post("/chat", response_model=ChatResponse)
@limiter.limit("20/minute")
async def chat(
    request: Request,
    body: ChatRequest,
    db: AsyncSession = Depends(get_db),
    user: Profile = Depends(get_current_user),
):
    if not settings.openai_api_key:
        raise HTTPException(status_code=503, detail="OpenAI API key not configured")

    last_message = body.messages[-1].content

    chunks = await retrieve(last_message, db)
    rag_context = build_context(chunks) if chunks else "База знаний пуста или недоступна."

    system = SYSTEM_PROMPT.format(rag_context=rag_context)

    if body.user_context:
        system += f"\n\nКОНТЕКСТ ПОЛЬЗОВАТЕЛЯ:\n{body.user_context}"

    if _is_crisis(last_message):
        system += CRISIS_ADDENDUM

    messages = [{"role": "system", "content": system}]
    for msg in body.messages:
        messages.append({"role": msg.role, "content": msg.content})

    if body.stream:
        return EventSourceResponse(_stream_response(messages, chunks))

    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(
            OPENAI_URL,
            headers={
                "Authorization": f"Bearer {settings.openai_api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": settings.openai_model,
                "temperature": 0.7,
                "max_tokens": 1000,
                "messages": messages,
            },
        )

    if resp.status_code != 200:
        logger.error("chat_openai_error", status=resp.status_code, body=resp.text[:500])
        raise HTTPException(status_code=502, detail="AI service unavailable")

    data = resp.json()
    reply = data.get("choices", [{}])[0].get("message", {}).get("content", "")

    if not reply:
        raise HTTPException(status_code=502, detail="Empty AI response")

    sources = [
        ChatSource(content=c["content"][:200], source=c["source"], category=c["category"])
        for c in chunks[:3]
    ]

    logger.info("chat_response", user_id=str(user.id), chunks_used=len(chunks))
    return ChatResponse(reply=reply, sources=sources)


async def _stream_response(messages: list[dict], chunks: list[dict]):
    """SSE streaming for real-time typing effect."""
    async with httpx.AsyncClient(timeout=120) as client:
        async with client.stream(
            "POST",
            OPENAI_URL,
            headers={
                "Authorization": f"Bearer {settings.openai_api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": settings.openai_model,
                "temperature": 0.7,
                "max_tokens": 1000,
                "messages": messages,
                "stream": True,
            },
        ) as resp:
            if resp.status_code != 200:
                yield {"event": "error", "data": json.dumps({"detail": "AI error"})}
                return

            async for line in resp.aiter_lines():
                if not line.startswith("data: "):
                    continue
                payload = line[6:]
                if payload == "[DONE]":
                    break
                try:
                    chunk = json.loads(payload)
                    delta = chunk["choices"][0].get("delta", {})
                    content = delta.get("content", "")
                    if content:
                        yield {"event": "message", "data": json.dumps({"content": content})}
                except (json.JSONDecodeError, KeyError, IndexError):
                    continue

    sources_data = [
        {"content": c["content"][:200], "source": c["source"], "category": c["category"]}
        for c in chunks[:3]
    ]
    yield {"event": "sources", "data": json.dumps({"sources": sources_data})}
    yield {"event": "done", "data": "{}"}
