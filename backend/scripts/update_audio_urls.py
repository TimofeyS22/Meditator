"""
Update meditation audio_url in database to point to the backend static server.

Usage:
    cd backend
    PYTHONPATH=. .venv/bin/python scripts/update_audio_urls.py
"""

import asyncio
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

from sqlalchemy import select, update
from app.database import async_session, engine
from app.models import Meditation

AUDIO_DIR = Path(__file__).resolve().parent.parent.parent / "assets" / "audio"


async def main():
    existing_files = {p.stem for p in AUDIO_DIR.glob("*.mp3")}
    print(f"Audio files found: {len(existing_files)}")

    async with async_session() as db:
        result = await db.execute(select(Meditation))
        meditations = result.scalars().all()

        updated = 0
        missing = []
        for m in meditations:
            if m.id in existing_files:
                new_url = f"/audio/{m.id}.mp3"
                if m.audio_url != new_url:
                    m.audio_url = new_url
                    updated += 1
            else:
                missing.append(m.id)

        if updated:
            await db.commit()

        print(f"Updated: {updated}")
        if missing:
            print(f"Missing audio ({len(missing)}): {', '.join(missing[:10])}...")


asyncio.run(main())
