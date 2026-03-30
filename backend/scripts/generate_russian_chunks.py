"""
Generate Russian mental-health RAG chunks via GPT-4o and insert into pgvector.

Usage:
    cd backend
    PYTHONPATH=. .venv/bin/python -m scripts.generate_russian_chunks
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import os
import sys
import uuid
from pathlib import Path

import httpx
from dotenv import load_dotenv
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_BASE_URL = os.getenv("OPENAI_BASE_URL", "https://api.proxyapi.ru/openai/v1")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o")
EMBED_MODEL = os.getenv("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small")
EMBED_URL = f"{OPENAI_BASE_URL}/embeddings"
CHAT_URL = f"{OPENAI_BASE_URL}/chat/completions"
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://meditator:meditator_secret@localhost:5433/meditator",
)

engine = create_async_engine(DATABASE_URL, echo=False, pool_size=5)
async_session_factory = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

TOPICS = [
    ("mindfulness", "Осознанность и присутствие в моменте: техники, научные исследования, практические упражнения"),
    ("mindfulness", "Медитация для начинающих: как начать, типичные ошибки, пошаговые инструкции"),
    ("anxiety", "Тревожность: природа тревоги, когнитивные искажения, техники снижения тревожности"),
    ("anxiety", "Паническая атака: что это, как распознать, техники самопомощи в момент приступа"),
    ("stress", "Управление стрессом: хронический стресс, кортизол, техники саморегуляции"),
    ("stress", "Профессиональное выгорание: признаки, профилактика, восстановление"),
    ("sleep", "Гигиена сна: научные рекомендации, циркадные ритмы, техники засыпания"),
    ("sleep", "Бессонница: причины, когнитивно-поведенческая терапия бессонницы, медитации перед сном"),
    ("depression", "Депрессия: признаки, самопомощь, когда обращаться к специалисту"),
    ("depression", "Самосострадание: техника Кристин Нефф, практики самосострадания, научные исследования"),
    ("breathing", "Дыхательные техники: диафрагмальное дыхание, когерентное дыхание, техника 4-7-8"),
    ("breathing", "Пранаяма и современная наука: влияние дыхания на вегетативную нервную систему"),
    ("focus", "Концентрация и внимание: тренировка фокуса, техники однонаправленного внимания"),
    ("focus", "Цифровой детокс: влияние экранов на ментальное здоровье, практики осознанного использования технологий"),
    ("emotion", "Эмоциональный интеллект: распознавание эмоций, регуляция, техника RAIN"),
    ("emotion", "Гнев и раздражительность: механизмы, техники управления, осознанный ответ vs реакция"),
    ("body", "Телесная осознанность: body scan, прогрессивная мышечная релаксация, связь тела и разума"),
    ("body", "Психосоматика: как эмоции влияют на тело, техники снятия телесных блоков"),
    ("relationship", "Осознанные отношения: практика активного слушания, медитация любящей доброты"),
    ("relationship", "Одиночество и изоляция: природа, влияние на здоровье, практики самоподдержки"),
    ("gratitude", "Практика благодарности: научные исследования, дневник благодарности, техники"),
    ("gratitude", "Позитивная психология: теория потока Чиксентмихайи, сильные стороны характера"),
    ("selfcare", "Самозаботa: границы, приоритизация, баланс работы и жизни"),
    ("selfcare", "Утренние и вечерние ритуалы: создание осознанной рутины для ментального здоровья"),
    ("trauma", "Посттравматический рост: как трудный опыт может стать источником силы"),
    ("trauma", "Техника заземления (grounding): 5-4-3-2-1, ориентация в пространстве, работа с флешбэками"),
    ("children", "Медитация для детей и подростков: адаптированные техники, игровые практики"),
    ("children", "Осознанность в школе: как помочь ребёнку справляться со стрессом и тревогой"),
    ("science", "Нейронаука медитации: как медитация меняет мозг, исследования Гарварда и Стэнфорда"),
    ("science", "Вегетативная нервная система: симпатическая vs парасимпатическая, вагус-нерв, практики тонусирования"),
]


async def generate_chunk(topic: str, prompt: str) -> list[str]:
    """Generate 3-5 informative paragraphs in Russian on the topic."""
    system = (
        "Ты эксперт по ментальному здоровью, психологии и медитации. "
        "Пиши на русском языке. Стиль: информативный, поддерживающий, научно обоснованный. "
        "Не ставь диагнозы. Давай практические рекомендации. "
        "Пиши 4-6 содержательных абзацев (800-1200 слов). "
        "Включай конкретные техники, упражнения, ссылки на исследования. "
        "Возвращай ТОЛЬКО текст, без JSON-обёрток."
    )
    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(
            CHAT_URL,
            headers={
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": OPENAI_MODEL,
                "temperature": 0.7,
                "messages": [
                    {"role": "system", "content": system},
                    {"role": "user", "content": prompt},
                ],
            },
        )
    if resp.status_code != 200:
        print(f"  ERROR generating {topic}: {resp.status_code} {resp.text[:200]}")
        return []
    content = resp.json().get("choices", [{}])[0].get("message", {}).get("content", "")
    if not content:
        return []
    paragraphs = [p.strip() for p in content.split("\n\n") if len(p.strip()) > 50]
    return paragraphs


async def get_embedding(text: str) -> list[float]:
    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.post(
            EMBED_URL,
            headers={
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "Content-Type": "application/json",
            },
            json={"model": EMBED_MODEL, "input": text},
        )
    if resp.status_code != 200:
        print(f"  EMBED ERROR: {resp.status_code}")
        return []
    return resp.json()["data"][0]["embedding"]


async def insert_chunk(session: AsyncSession, text: str, source: str, category: str, embedding: list[float]):
    content_hash = hashlib.sha256(text.encode()).hexdigest()
    existing = await session.execute(
        text("SELECT id FROM knowledge_chunks WHERE content_hash = :h"),
        {"h": content_hash},
    )
    if existing.scalar_one_or_none():
        return False
    chunk_id = str(uuid.uuid4())
    await session.execute(
        text(
            "INSERT INTO knowledge_chunks (id, content, source, category, content_hash, embedding) "
            "VALUES (:id, :content, :source, :category, :hash, :emb)"
        ),
        {
            "id": chunk_id,
            "content": text,
            "source": source,
            "category": category,
            "hash": content_hash,
            "emb": json.dumps(embedding),
        },
    )
    return True


async def main():
    if not OPENAI_API_KEY:
        print("ERROR: OPENAI_API_KEY not set")
        sys.exit(1)

    total_inserted = 0
    print(f"Generating {len(TOPICS)} Russian mental-health topics...")

    for i, (category, prompt) in enumerate(TOPICS, 1):
        print(f"\n[{i}/{len(TOPICS)}] {category}: {prompt[:60]}...")
        paragraphs = await generate_chunk(category, prompt)
        if not paragraphs:
            print("  No content generated, skipping")
            continue

        print(f"  Generated {len(paragraphs)} paragraphs")
        async with async_session_factory() as session:
            for j, para in enumerate(paragraphs):
                embedding = await get_embedding(para)
                if not embedding:
                    continue
                inserted = await insert_chunk(
                    session, para, f"ai_generated_ru_{category}_{i}", category, embedding
                )
                if inserted:
                    total_inserted += 1
                    print(f"    Paragraph {j+1}: inserted ({len(para)} chars)")
                else:
                    print(f"    Paragraph {j+1}: already exists, skipped")
            await session.commit()

    print(f"\nDone! Inserted {total_inserted} new Russian chunks.")


if __name__ == "__main__":
    asyncio.run(main())
