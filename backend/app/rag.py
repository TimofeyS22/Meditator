"""RAG engine: embed user query -> cosine similarity search in pgvector -> assemble context."""

from __future__ import annotations

import httpx
import structlog
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import KnowledgeChunk

logger = structlog.get_logger()

OPENAI_EMBED_URL = f"{settings.openai_base_url}/embeddings"


async def get_embedding(query: str) -> list[float]:
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            OPENAI_EMBED_URL,
            json={"input": query[:8000], "model": settings.openai_embedding_model},
            headers={"Authorization": f"Bearer {settings.openai_api_key}"},
        )
    if resp.status_code != 200:
        logger.error("embedding_error", status=resp.status_code, body=resp.text[:300])
        raise RuntimeError(f"OpenAI embedding failed: {resp.status_code}")
    data = resp.json()["data"]
    return data[0]["embedding"]


async def retrieve(
    query: str,
    db: AsyncSession,
    top_k: int | None = None,
    category_filter: str | None = None,
) -> list[dict]:
    """Retrieve top-k most relevant knowledge chunks for a query."""
    top_k = top_k or settings.rag_top_k
    query_embedding = await get_embedding(query)

    stmt = (
        select(
            KnowledgeChunk.id,
            KnowledgeChunk.content,
            KnowledgeChunk.source,
            KnowledgeChunk.category,
            KnowledgeChunk.language,
            KnowledgeChunk.embedding.cosine_distance(query_embedding).label("distance"),
        )
        .order_by("distance")
        .limit(top_k)
    )

    if category_filter:
        stmt = stmt.where(KnowledgeChunk.category == category_filter)

    result = await db.execute(stmt)
    rows = result.fetchall()

    return [
        {
            "content": row.content,
            "source": row.source,
            "category": row.category,
            "distance": round(float(row.distance), 4),
        }
        for row in rows
    ]


def build_context(chunks: list[dict], max_tokens: int = 3000) -> str:
    """Build context string from retrieved chunks, respecting token budget."""
    context_parts: list[str] = []
    total_words = 0
    approx_word_limit = max_tokens * 0.75

    for chunk in chunks:
        words = chunk["content"].split()
        if total_words + len(words) > approx_word_limit:
            break
        context_parts.append(chunk["content"])
        total_words += len(words)

    if not context_parts:
        return ""
    return "\n\n---\n\n".join(context_parts)
