"""
Generate meditation scripts (GPT-4o) and audio (OpenAI TTS-1-HD) for all 55 meditations.

Usage:
    cd backend
    PYTHONPATH=. .venv/bin/python scripts/generate_meditations.py

Requires: OPENAI_API_KEY and OPENAI_BASE_URL in .env (ProxyAPI).
Produces: ../assets/audio/<meditation_id>.mp3
"""

import asyncio
import json
import os
import subprocess
import tempfile
import time
from pathlib import Path

import httpx
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

SCRIPT_DIR = Path(__file__).resolve().parent
BACKEND_DIR = SCRIPT_DIR.parent
PROJECT_DIR = BACKEND_DIR.parent
AUDIO_DIR = PROJECT_DIR / "assets" / "audio"
SCRIPTS_CACHE_DIR = BACKEND_DIR / "scripts" / "_meditation_scripts"

AUDIO_DIR.mkdir(parents=True, exist_ok=True)
SCRIPTS_CACHE_DIR.mkdir(parents=True, exist_ok=True)

API_KEY = os.getenv("OPENAI_API_KEY", "")
BASE_URL = os.getenv("OPENAI_BASE_URL", "https://api.proxyapi.ru/openai/v1")

VOICE_MAP = {
    "Иван": "onyx",
    "Марина": "nova",
    "Станислав": "echo",
}

CATEGORY_DESCRIPTIONS = {
    "sleep": "засыпание и глубокий восстанавливающий сон",
    "stress": "снятие стресса и напряжения",
    "focus": "концентрация внимания и ясность ума",
    "anxiety": "успокоение тревоги и обретение внутреннего покоя",
    "morning": "мягкое пробуждение и позитивный настрой на день",
    "evening": "расслабление и подведение итогов дня",
    "gratitude": "практика благодарности и ценности жизни",
    "selfLove": "самопринятие, доброта и забота о себе",
    "bodyScan": "сканирование тела и осознание телесных ощущений",
    "breathing": "осознанное дыхание и телесное расслабление",
    "visualization": "визуализация и путешествие воображения",
    "emergency": "экстренная помощь при панике или сильной тревоге",
}

MEDITATIONS = [
    ("sleep-01-med", "Тихая ночь и мягкое засыпание", "sleep", 5, "Иван"),
    ("sleep-02-med", "Глубокий сон без тревоги", "sleep", 10, "Марина"),
    ("sleep-03-med", "Путешествие в покой перед сном", "sleep", 15, "Станислав"),
    ("sleep-04-med", "Расслабление тела для сна", "sleep", 3, "Иван"),
    ("sleep-05-med", "Сон в объятиях тишины", "sleep", 8, "Марина"),
    ("sleep-06-med", "Отпускание дня перед сном", "sleep", 13, "Станислав"),
    ("stress-01-med", "Сброс напряжения после дня", "stress", 18, "Иван"),
    ("stress-02-med", "Волны спокойствия", "stress", 4, "Марина"),
    ("stress-03-med", "Якорь в настоящем моменте", "stress", 9, "Станислав"),
    ("stress-04-med", "Мягкое освобождение от стресса", "stress", 14, "Иван"),
    ("stress-05-med", "Внутреннее пространство тишины", "stress", 19, "Марина"),
    ("stress-06-med", "Восстановление после перегрузки", "stress", 6, "Станислав"),
    ("focus-01-med", "Ясность ума и концентрация", "focus", 11, "Иван"),
    ("focus-02-med", "Точка опоры для внимания", "focus", 16, "Марина"),
    ("focus-03-med", "Собранность перед важным делом", "focus", 20, "Станислав"),
    ("focus-04-med", "Чистый фокус без отвлечений", "focus", 7, "Иван"),
    ("focus-05-med", "Энергия внимания", "focus", 12, "Марина"),
    ("anxiety-01-med", "Успокоение тревожных мыслей", "anxiety", 17, "Станислав"),
    ("anxiety-02-med", "Безопасное место внутри", "anxiety", 5, "Иван"),
    ("anxiety-03-med", "Дыхание против тревоги", "anxiety", 10, "Марина"),
    ("anxiety-04-med", "Мягкая опора при беспокойстве", "anxiety", 15, "Станислав"),
    ("anxiety-05-med", "Возврат к спокойствию", "anxiety", 3, "Иван"),
    ("morning-01-med", "Мягкое пробуждение", "morning", 8, "Марина"),
    ("morning-02-med", "Настрой на светлый день", "morning", 13, "Станислав"),
    ("morning-03-med", "Энергия утра без спешки", "morning", 18, "Иван"),
    ("morning-04-med", "Благодарность за новый день", "morning", 4, "Марина"),
    ("morning-05-med", "Ясное начало дня", "morning", 9, "Станислав"),
    ("evening-01-med", "Завершение дня с благодарностью", "evening", 14, "Иван"),
    ("evening-02-med", "Вечернее расслабление", "evening", 19, "Марина"),
    ("evening-03-med", "Отпускание забот", "evening", 6, "Станислав"),
    ("evening-04-med", "Тихий вечерний покой", "evening", 11, "Иван"),
    ("evening-05-med", "Переход к отдыху", "evening", 16, "Марина"),
    ("gratitude-01-med", "Сердце благодарности", "gratitude", 20, "Станислав"),
    ("gratitude-02-med", "Маленькие радости дня", "gratitude", 7, "Иван"),
    ("gratitude-03-med", "Свет в повседневности", "gratitude", 12, "Марина"),
    ("gratitude-04-med", "Благодарность себе и миру", "gratitude", 17, "Станислав"),
    ("selfLove-01-med", "Нежность к себе", "selfLove", 5, "Иван"),
    ("selfLove-02-med", "Принятие без условий", "selfLove", 10, "Марина"),
    ("selfLove-03-med", "Внутренняя поддержка", "selfLove", 15, "Станислав"),
    ("selfLove-04-med", "Доброта к своему телу", "selfLove", 3, "Иван"),
    ("bodyScan-01-med", "Сканирование тела от макушки до стоп", "bodyScan", 8, "Марина"),
    ("bodyScan-02-med", "Мягкое внимание к ощущениям", "bodyScan", 13, "Станислав"),
    ("bodyScan-03-med", "Освобождение зажимов", "bodyScan", 18, "Иван"),
    ("bodyScan-04-med", "Связь с телом", "bodyScan", 4, "Марина"),
    ("breathing-01-med", "Ровное дыхание покоя", "breathing", 9, "Станислав"),
    ("breathing-02-med", "Дыхание 4-7-8 для спокойствия", "breathing", 14, "Иван"),
    ("breathing-03-med", "Животное дыхание расслабления", "breathing", 19, "Марина"),
    ("breathing-04-med", "Дыхание — якорь внимания", "breathing", 6, "Станислав"),
    ("visualization-01-med", "Лесная тропа спокойствия", "visualization", 11, "Иван"),
    ("visualization-02-med", "Морской берег внутри", "visualization", 16, "Марина"),
    ("visualization-03-med", "Горная ясность", "visualization", 20, "Станислав"),
    ("visualization-04-med", "Сад внутреннего мира", "visualization", 7, "Иван"),
    ("emergency-01-med", "Быстрое успокоение за несколько минут", "emergency", 12, "Марина"),
    ("emergency-02-med", "Срочная передышка при панике", "emergency", 17, "Станислав"),
    ("emergency-03-med", "Стабилизация здесь и сейчас", "emergency", 5, "Иван"),
]

WORDS_PER_MINUTE = 120
TTS_CHAR_LIMIT = 4000


def estimate_word_count(duration_minutes: int) -> int:
    return duration_minutes * WORDS_PER_MINUTE


def build_script_prompt(title: str, category: str, duration: int) -> tuple[str, str]:
    cat_desc = CATEGORY_DESCRIPTIONS.get(category, category)
    word_count = estimate_word_count(duration)

    system = (
        "Ты профессиональный ведущий медитаций с 20-летним опытом. "
        "Создай полный текст медитации на русском языке.\n\n"
        "СТИЛЬ:\n"
        "- Спокойный, тёплый, уважительный тон\n"
        "- Обращение на \"ты\"\n"
        "- Без панибратства, без медицинских обещаний и диагнозов\n"
        "- Мягкие переходы между частями\n"
        "- Используй многоточия (...) для обозначения плавных пауз в речи\n\n"
        "СТРУКТУРА:\n"
        "1. Мягкое приветствие и настройка позы/положения тела (10% текста)\n"
        "2. Работа с дыханием - несколько циклов осознанного дыхания (15% текста)\n"
        "3. Основная практика по теме медитации (60% текста)\n"
        "4. Мягкое завершение и возвращение (15% текста)\n\n"
        "ВАЖНО:\n"
        "- НЕ используй заголовки, нумерацию, скобки или любое форматирование\n"
        "- Только чистый текст для озвучивания вслух\n"
        "- Между смысловыми блоками вставляй пустую строку\n"
        f"- Текст должен быть примерно {word_count} слов "
        f"(для {duration} минут спокойной речи)\n"
        "- Каждое предложение должно быть отдельной мыслью\n"
        "- Избегай длинных перечислений"
    )

    user_msg = (
        f"Категория: {category} ({cat_desc}).\n"
        f"Название: \"{title}\".\n"
        f"Длительность: {duration} минут.\n"
        f"Целевой объём: примерно {word_count} слов."
    )

    return system, user_msg


async def generate_script(
    client: httpx.AsyncClient,
    med_id: str,
    title: str,
    category: str,
    duration: int,
) -> str:
    cache_file = SCRIPTS_CACHE_DIR / f"{med_id}.txt"
    if cache_file.exists():
        return cache_file.read_text(encoding="utf-8")

    system, user_msg = build_script_prompt(title, category, duration)

    max_tokens = min(4096, max(600, estimate_word_count(duration) * 3))

    resp = await client.post(
        f"{BASE_URL}/chat/completions",
        headers={
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json",
        },
        json={
            "model": "gpt-4o",
            "temperature": 0.75,
            "max_tokens": max_tokens,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user_msg},
            ],
        },
    )

    if resp.status_code != 200:
        raise RuntimeError(f"GPT-4o error for {med_id}: {resp.status_code} {resp.text[:300]}")

    data = resp.json()
    script = data["choices"][0]["message"]["content"]

    cache_file.write_text(script, encoding="utf-8")
    return script


def split_script(text: str, limit: int = TTS_CHAR_LIMIT) -> list[str]:
    if len(text) <= limit:
        return [text]

    chunks = []
    paragraphs = text.split("\n\n")
    current = ""

    for para in paragraphs:
        if len(current) + len(para) + 2 <= limit:
            current = current + "\n\n" + para if current else para
        else:
            if current:
                chunks.append(current.strip())
            if len(para) <= limit:
                current = para
            else:
                sentences = para.replace(". ", ".\n").split("\n")
                for sent in sentences:
                    if len(current) + len(sent) + 1 <= limit:
                        current = current + " " + sent if current else sent
                    else:
                        if current:
                            chunks.append(current.strip())
                        current = sent

    if current.strip():
        chunks.append(current.strip())

    return chunks


async def generate_audio_chunk(
    client: httpx.AsyncClient,
    text: str,
    voice: str,
    retries: int = 3,
) -> bytes:
    for attempt in range(retries):
        try:
            resp = await client.post(
                f"{BASE_URL}/audio/speech",
                headers={
                    "Authorization": f"Bearer {API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "tts-1-hd",
                    "voice": voice,
                    "input": text,
                    "response_format": "mp3",
                    "speed": 0.9,
                },
            )
            if resp.status_code == 200:
                return resp.content
            if resp.status_code == 429:
                wait = 30 * (attempt + 1)
                print(f"    Rate limited, waiting {wait}s...")
                await asyncio.sleep(wait)
                continue
            raise RuntimeError(f"TTS error: {resp.status_code} {resp.text[:300]}")
        except httpx.ReadTimeout:
            if attempt < retries - 1:
                print(f"    Timeout, retrying ({attempt + 1}/{retries})...")
                await asyncio.sleep(5)
            else:
                raise
    raise RuntimeError("Max retries exceeded for TTS")


def concat_mp3_files(chunk_paths: list[Path], output_path: Path):
    if len(chunk_paths) == 1:
        output_path.write_bytes(chunk_paths[0].read_bytes())
        return

    list_file = output_path.parent / f"{output_path.stem}_list.txt"
    with open(list_file, "w") as f:
        for p in chunk_paths:
            f.write(f"file '{p}'\n")

    subprocess.run(
        ["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(list_file),
         "-c", "copy", str(output_path)],
        capture_output=True,
        check=True,
    )
    list_file.unlink()


async def generate_meditation_audio(
    client: httpx.AsyncClient,
    med_id: str,
    title: str,
    category: str,
    duration: int,
    voice_name: str,
    index: int,
    total: int,
):
    output_path = AUDIO_DIR / f"{med_id}.mp3"
    if output_path.exists() and output_path.stat().st_size > 10000:
        print(f"  [{index}/{total}] SKIP {med_id} (already exists, {output_path.stat().st_size / 1024:.0f} KB)")
        return

    voice = VOICE_MAP.get(voice_name, "nova")

    print(f"  [{index}/{total}] {med_id} ({duration} min, voice={voice})")

    print(f"    Generating script...")
    script = await generate_script(client, med_id, title, category, duration)
    word_count = len(script.split())
    print(f"    Script: {len(script)} chars, ~{word_count} words")

    chunks = split_script(script)
    print(f"    TTS: {len(chunks)} chunk(s)...")

    chunk_paths = []
    for i, chunk_text in enumerate(chunks):
        print(f"    Chunk {i + 1}/{len(chunks)} ({len(chunk_text)} chars)...")
        audio_data = await generate_audio_chunk(client, chunk_text, voice)
        chunk_path = AUDIO_DIR / f"{med_id}_chunk{i}.mp3"
        chunk_path.write_bytes(audio_data)
        chunk_paths.append(chunk_path)
        if i < len(chunks) - 1:
            await asyncio.sleep(1)

    concat_mp3_files(chunk_paths, output_path)

    for cp in chunk_paths:
        if cp != output_path and cp.exists():
            cp.unlink()

    size_kb = output_path.stat().st_size / 1024
    print(f"    Done: {size_kb:.0f} KB")


async def main():
    if not API_KEY:
        print("ERROR: OPENAI_API_KEY not set. Check .env")
        return

    print(f"=== Meditation Audio Generator ===")
    print(f"API: {BASE_URL}")
    print(f"Output: {AUDIO_DIR}")
    print(f"Meditations: {len(MEDITATIONS)}")
    print()

    already_done = sum(1 for mid, *_ in MEDITATIONS if (AUDIO_DIR / f"{mid}.mp3").exists())
    remaining = len(MEDITATIONS) - already_done
    print(f"Already generated: {already_done}")
    print(f"Remaining: {remaining}")
    print()

    async with httpx.AsyncClient(timeout=180) as client:
        for idx, (mid, title, cat, dur, voice_name) in enumerate(MEDITATIONS, 1):
            try:
                await generate_meditation_audio(
                    client, mid, title, cat, dur, voice_name, idx, len(MEDITATIONS)
                )
                await asyncio.sleep(2)
            except Exception as e:
                print(f"  ERROR on {mid}: {e}")
                print(f"  Continuing to next meditation...")
                await asyncio.sleep(5)

    generated = sum(1 for mid, *_ in MEDITATIONS if (AUDIO_DIR / f"{mid}.mp3").exists())
    print(f"\n=== DONE ===")
    print(f"Generated: {generated}/{len(MEDITATIONS)}")

    total_size = sum(
        (AUDIO_DIR / f"{mid}.mp3").stat().st_size
        for mid, *_ in MEDITATIONS
        if (AUDIO_DIR / f"{mid}.mp3").exists()
    )
    print(f"Total size: {total_size / 1024 / 1024:.1f} MB")


if __name__ == "__main__":
    asyncio.run(main())
