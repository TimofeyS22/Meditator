"""
Data pipeline: download mental-health datasets -> clean -> chunk -> embed -> insert into pgvector.

Usage:
    DATABASE_URL="postgresql+asyncpg://meditator:meditator_secret@localhost:5433/meditator" \
    OPENAI_API_KEY="sk-..." \
    python -m scripts.build_knowledge_base
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import os
import re
import sys
import time
import uuid
from dataclasses import dataclass, field

import httpx
from datasets import load_dataset
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

EMBEDDING_MODEL = os.getenv("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small")
EMBEDDING_DIM = 1536
CHUNK_WORDS = 350
OVERLAP_WORDS = 50
BATCH_SIZE = 100
EMBED_BATCH = 64
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_BASE_URL = os.getenv("OPENAI_BASE_URL", "https://api.proxyapi.ru/openai/v1")
OPENAI_EMBED_URL = f"{OPENAI_BASE_URL}/embeddings"
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://meditator:meditator_secret@localhost:5433/meditator",
)

engine = create_async_engine(DATABASE_URL, echo=False, pool_size=5)
async_session_factory = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


@dataclass
class RawEntry:
    text: str
    source: str
    category: str
    language: str
    metadata: dict = field(default_factory=dict)


@dataclass
class Chunk:
    content: str
    source: str
    category: str
    language: str
    metadata: dict
    embedding: list[float] | None = None


def clean_text(s: str) -> str:
    s = re.sub(r"\s+", " ", s).strip()
    s = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", s)
    return s


def chunk_text(t: str, max_words: int = CHUNK_WORDS, overlap: int = OVERLAP_WORDS) -> list[str]:
    words = t.split()
    if len(words) <= max_words:
        return [t]
    chunks: list[str] = []
    start = 0
    while start < len(words):
        end = start + max_words
        chunks.append(" ".join(words[start:end]))
        start = end - overlap
    return chunks


def _dedup_key(t: str) -> str:
    return hashlib.md5(t.strip().lower().encode()).hexdigest()


CATEGORY_KEYWORDS = {
    "depression": ["depres", "sadness", "hopeless", "worthless", "депресс", "тоска", "безнадёж"],
    "anxiety": ["anxi", "worry", "panic", "fear", "тревог", "паник", "страх", "беспокой"],
    "stress": ["stress", "overwhelm", "burnout", "стресс", "выгоран", "перегруз"],
    "grief": ["grief", "loss", "mourning", "горе", "утрат", "потер"],
    "anger": ["anger", "angry", "rage", "гнев", "злость", "раздраж"],
    "loneliness": ["lonely", "isolation", "одиноч", "изоляц"],
    "self_esteem": ["self-esteem", "confidence", "самооценк", "уверенн"],
    "relationships": ["relationship", "partner", "family", "отношен", "партнёр", "семь"],
    "sleep": ["sleep", "insomnia", "сон", "бессонниц"],
    "cbt": ["cbt", "cognitive", "когнитивн", "кпт"],
    "mindfulness": ["mindful", "meditation", "осознанн", "медитац"],
}


def _guess_category(t: str) -> str:
    lower = t.lower()
    best, best_count = "general", 0
    for cat, keywords in CATEGORY_KEYWORDS.items():
        count = sum(1 for kw in keywords if kw in lower)
        if count > best_count:
            best, best_count = cat, count
    return best


# ── Dataset loaders ────────────────────────────────────────────

def load_mentalchat16k() -> list[RawEntry]:
    print("[1/5] MentalChat16K...")
    try:
        ds = load_dataset("ShenLab/MentalChat16K", split="train")
    except Exception as e:
        print(f"  SKIP: {e}")
        return []
    entries: list[RawEntry] = []
    for row in ds:
        inp = row.get("input", "") or ""
        out = row.get("output", "") or ""
        combined = clean_text(f"Question: {inp}\nAnswer: {out}" if inp and out else (inp or out))
        if len(combined.split()) < 15:
            continue
        entries.append(RawEntry(text=combined, source="mentalchat16k", category=_guess_category(combined), language="en"))
    print(f"  -> {len(entries)} entries")
    return entries


def load_esconv() -> list[RawEntry]:
    print("[2/5] ESConv...")
    try:
        ds = load_dataset("thu-coai/esconv", split="train")
    except Exception as e:
        print(f"  SKIP: {e}")
        return []
    entries: list[RawEntry] = []
    for row in ds:
        raw_text = row.get("text", "")
        try:
            data = json.loads(raw_text)
        except (json.JSONDecodeError, TypeError):
            continue
        dialog = data.get("dialog", [])
        if not dialog:
            continue
        lines = []
        for turn in dialog:
            speaker = "Seeker" if turn.get("speaker") == "usr" else "Supporter"
            t = turn.get("text", "")
            if t:
                lines.append(f"{speaker}: {t}")
        combined = clean_text("\n".join(lines))
        if len(combined.split()) < 20:
            continue
        emotion = data.get("emotion_type", "emotional_support")
        entries.append(RawEntry(
            text=combined, source="esconv", category=emotion, language="en",
            metadata={"problem_type": data.get("problem_type", "")},
        ))
    print(f"  -> {len(entries)} entries")
    return entries


def load_cognitive_distortions_ru() -> list[RawEntry]:
    print("[3/5] Cognitive Distortions RU...")
    try:
        ds = load_dataset("psytechlab/cognitive_distortions_dataset_ru", split="train")
    except Exception as e:
        print(f"  SKIP: {e}")
        return []
    entries: list[RawEntry] = []
    for row in ds:
        q_ru = row.get("patient_question_rus", "") or ""
        dist_ru = row.get("distorted_part_rus", "") or ""
        dominant = row.get("dominant_distortion", "") or ""
        combined = clean_text(f"{q_ru}\nИскажение ({dominant}): {dist_ru}")
        if len(combined.split()) < 10:
            continue
        entries.append(RawEntry(
            text=combined, source="cognitive_distortions_ru",
            category=f"cbt_{dominant.lower().replace(' ', '_')}" if dominant else "cbt",
            language="ru",
            metadata={"distortion": dominant, "secondary": row.get("secondary_distortion", "")},
        ))
    print(f"  -> {len(entries)} entries")
    return entries


def load_counseling_conversations() -> list[RawEntry]:
    print("[4/5] Mental Health Counseling Conversations...")
    try:
        ds = load_dataset("Amod/mental_health_counseling_conversations", split="train")
    except Exception as e:
        print(f"  SKIP: {e}")
        return []
    entries: list[RawEntry] = []
    for row in ds:
        context = row.get("Context", "") or ""
        response = row.get("Response", "") or ""
        combined = clean_text(f"Client: {context}\nCounselor: {response}")
        if len(combined.split()) < 20:
            continue
        entries.append(RawEntry(text=combined, source="counseling_conversations", category=_guess_category(combined), language="en"))
    print(f"  -> {len(entries)} entries")
    return entries


def load_counsel_chat() -> list[RawEntry]:
    print("[5/5] CounselChat...")
    try:
        ds = load_dataset("nbertagnolli/counsel-chat", split="train")
    except Exception as e:
        print(f"  SKIP: {e}")
        return []
    entries: list[RawEntry] = []
    for row in ds:
        question = row.get("questionText", "") or ""
        answer = row.get("answerText", "") or ""
        topic = row.get("topic", "") or ""
        combined = clean_text(f"Question: {question}\nTherapist: {answer}")
        if len(combined.split()) < 20:
            continue
        entries.append(RawEntry(
            text=combined, source="counsel_chat", category=topic or _guess_category(combined),
            language="en",
            metadata={"topic": topic, "therapist": row.get("therapistInfo", "")},
        ))
    print(f"  -> {len(entries)} entries")
    return entries


# ── Embedding ──────────────────────────────────────────────────

async def get_embeddings_batch(texts: list[str], client: httpx.AsyncClient) -> list[list[float]]:
    resp = await client.post(
        OPENAI_EMBED_URL,
        json={"input": texts, "model": EMBEDDING_MODEL},
        headers={"Authorization": f"Bearer {OPENAI_API_KEY}"},
        timeout=120,
    )
    if resp.status_code != 200:
        raise RuntimeError(f"OpenAI embedding error {resp.status_code}: {resp.text[:500]}")
    data = resp.json()["data"]
    data.sort(key=lambda x: x["index"])
    return [d["embedding"] for d in data]


# ── DB insert ──────────────────────────────────────────────────

INSERT_SQL = text("""
INSERT INTO knowledge_chunks (id, content, source, category, language, embedding, metadata_, created_at)
VALUES (:id, :content, :source, :category, :language, :embedding, CAST(:metadata_ AS jsonb), now())
ON CONFLICT DO NOTHING
""")


async def insert_chunks(chunks: list[Chunk]) -> int:
    inserted = 0
    async with async_session_factory() as db:
        for i in range(0, len(chunks), BATCH_SIZE):
            batch = chunks[i : i + BATCH_SIZE]
            for c in batch:
                meta_json = json.dumps(c.metadata, ensure_ascii=False) if c.metadata else "{}"
                await db.execute(INSERT_SQL, {
                    "id": str(uuid.uuid4()),
                    "content": c.content,
                    "source": c.source,
                    "category": c.category,
                    "language": c.language,
                    "embedding": str(c.embedding),
                    "metadata_": meta_json,
                })
            await db.commit()
            inserted += len(batch)
            if inserted % 1000 == 0:
                print(f"  Inserted {inserted}...")
    return inserted


# ── Main pipeline ──────────────────────────────────────────────

async def run_pipeline():
    print("=" * 60)
    print("  Meditator Knowledge Base Builder")
    print("=" * 60)

    if not OPENAI_API_KEY:
        print("ERROR: Set OPENAI_API_KEY env var.")
        sys.exit(1)

    async with engine.begin() as conn:
        await conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
    print("pgvector extension OK\n")

    all_entries: list[RawEntry] = []
    for loader in [load_mentalchat16k, load_esconv, load_cognitive_distortions_ru,
                   load_counseling_conversations, load_counsel_chat]:
        all_entries.extend(loader())

    print(f"\nTotal raw entries: {len(all_entries)}")

    seen: set[str] = set()
    deduped: list[RawEntry] = []
    for e in all_entries:
        key = _dedup_key(e.text)
        if key not in seen:
            seen.add(key)
            deduped.append(e)
    print(f"After dedup: {len(deduped)}")

    all_chunks: list[Chunk] = []
    for entry in deduped:
        for tc in chunk_text(entry.text):
            all_chunks.append(Chunk(
                content=tc, source=entry.source, category=entry.category,
                language=entry.language, metadata=entry.metadata,
            ))
    print(f"Total chunks: {len(all_chunks)}\n")

    print("Generating embeddings...")
    t0 = time.time()
    async with httpx.AsyncClient() as client:
        for i in range(0, len(all_chunks), EMBED_BATCH):
            batch = all_chunks[i : i + EMBED_BATCH]
            texts = [c.content[:8000] for c in batch]
            try:
                embeddings = await get_embeddings_batch(texts, client)
                for c, emb in zip(batch, embeddings):
                    c.embedding = emb
            except Exception as e:
                print(f"  ERROR at batch {i}: {e}")
                for c in batch:
                    c.embedding = [0.0] * EMBEDDING_DIM

            done = min(i + EMBED_BATCH, len(all_chunks))
            elapsed = time.time() - t0
            print(f"  {done}/{len(all_chunks)} ({done / elapsed:.0f} chunks/s)" if elapsed > 0 else f"  {done}/{len(all_chunks)}")

    print(f"Embeddings done in {time.time() - t0:.1f}s\n")

    print("Inserting into database...")
    inserted = await insert_chunks(all_chunks)
    print(f"Inserted {inserted} chunks.")

    async with async_session_factory() as db:
        result = await db.execute(text("SELECT count(*) FROM knowledge_chunks"))
        total = result.scalar()
        result2 = await db.execute(text("SELECT source, count(*) FROM knowledge_chunks GROUP BY source ORDER BY count(*) DESC"))
        stats = result2.fetchall()

    print(f"\nTotal knowledge_chunks: {total}")
    for src, cnt in stats:
        print(f"  {src}: {cnt}")

    await engine.dispose()
    print("\nDone!")


if __name__ == "__main__":
    asyncio.run(run_pipeline())
