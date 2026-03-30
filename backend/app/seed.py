"""Seed 55 meditations from the original 002_seed.sql data."""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Meditation

MEDITATIONS = [
    ("sleep-01-med", "Тихая ночь и мягкое засыпание", "sleep", 5, True, "Иван", 4.30, 100),
    ("sleep-02-med", "Глубокий сон без тревоги", "sleep", 10, True, "Марина", 4.39, 7919),
    ("sleep-03-med", "Путешествие в покой перед сном", "sleep", 15, True, "Станислав", 4.48, 15838),
    ("sleep-04-med", "Расслабление тела для сна", "sleep", 3, False, "Иван", 4.57, 23757),
    ("sleep-05-med", "Сон в объятиях тишины", "sleep", 8, False, "Марина", 4.66, 31676),
    ("sleep-06-med", "Отпускание дня перед сном", "sleep", 13, False, "Станислав", 4.75, 39595),
    ("stress-01-med", "Сброс напряжения после дня", "stress", 18, False, "Иван", 4.84, 47514),
    ("stress-02-med", "Волны спокойствия", "stress", 4, False, "Марина", 4.93, 5533),
    ("stress-03-med", "Якорь в настоящем моменте", "stress", 9, True, "Станислав", 4.30, 13452),
    ("stress-04-med", "Мягкое освобождение от стресса", "stress", 14, False, "Иван", 4.39, 21371),
    ("stress-05-med", "Внутреннее пространство тишины", "stress", 19, False, "Марина", 4.48, 29290),
    ("stress-06-med", "Восстановление после перегрузки", "stress", 6, False, "Станислав", 4.57, 37209),
    ("focus-01-med", "Ясность ума и концентрация", "focus", 11, False, "Иван", 4.66, 45128),
    ("focus-02-med", "Точка опоры для внимания", "focus", 16, True, "Марина", 4.75, 30447),
    ("focus-03-med", "Собранность перед важным делом", "focus", 20, True, "Станислав", 4.84, 20966),
    ("focus-04-med", "Чистый фокус без отвлечений", "focus", 7, False, "Иван", 4.93, 6885),
    ("focus-05-med", "Энергия внимания", "focus", 12, False, "Марина", 4.30, 14804),
    ("anxiety-01-med", "Успокоение тревожных мыслей", "anxiety", 17, True, "Станислав", 4.39, 22723),
    ("anxiety-02-med", "Безопасное место внутри", "anxiety", 5, True, "Иван", 4.48, 30642),
    ("anxiety-03-med", "Дыхание против тревоги", "anxiety", 10, False, "Марина", 4.57, 38561),
    ("anxiety-04-med", "Мягкая опора при беспокойстве", "anxiety", 15, True, "Станислав", 4.66, 46480),
    ("anxiety-05-med", "Возврат к спокойствию", "anxiety", 3, False, "Иван", 4.75, 24399),
    ("morning-01-med", "Мягкое пробуждение", "morning", 8, False, "Марина", 4.84, 12318),
    ("morning-02-med", "Настрой на светлый день", "morning", 13, True, "Станислав", 4.93, 20237),
    ("morning-03-med", "Энергия утра без спешки", "morning", 18, False, "Иван", 4.30, 28156),
    ("morning-04-med", "Благодарность за новый день", "morning", 4, False, "Марина", 4.39, 36075),
    ("morning-05-med", "Ясное начало дня", "morning", 9, True, "Станислав", 4.48, 43994),
    ("evening-01-med", "Завершение дня с благодарностью", "evening", 14, False, "Иван", 4.57, 11913),
    ("evening-02-med", "Вечернее расслабление", "evening", 19, True, "Марина", 4.66, 19832),
    ("evening-03-med", "Отпускание забот", "evening", 6, False, "Станислав", 4.75, 27751),
    ("evening-04-med", "Тихий вечерний покой", "evening", 11, False, "Иван", 4.84, 35670),
    ("evening-05-med", "Переход к отдыху", "evening", 16, False, "Марина", 4.93, 43589),
    ("gratitude-01-med", "Сердце благодарности", "gratitude", 20, False, "Станислав", 4.30, 21508),
    ("gratitude-02-med", "Маленькие радости дня", "gratitude", 7, True, "Иван", 4.39, 19427),
    ("gratitude-03-med", "Свет в повседневности", "gratitude", 12, False, "Марина", 4.48, 27346),
    ("gratitude-04-med", "Благодарность себе и миру", "gratitude", 17, False, "Станислав", 4.57, 35265),
    ("selfLove-01-med", "Нежность к себе", "selfLove", 5, True, "Иван", 4.66, 43184),
    ("selfLove-02-med", "Принятие без условий", "selfLove", 10, True, "Марина", 4.75, 21103),
    ("selfLove-03-med", "Внутренняя поддержка", "selfLove", 15, False, "Станислав", 4.84, 9022),
    ("selfLove-04-med", "Доброта к своему телу", "selfLove", 3, False, "Иван", 4.93, 16941),
    ("bodyScan-01-med", "Сканирование тела от макушки до стоп", "bodyScan", 8, True, "Марина", 4.30, 24860),
    ("bodyScan-02-med", "Мягкое внимание к ощущениям", "bodyScan", 13, True, "Станислав", 4.39, 32779),
    ("bodyScan-03-med", "Освобождение зажимов", "bodyScan", 18, False, "Иван", 4.48, 10698),
    ("bodyScan-04-med", "Связь с телом", "bodyScan", 4, False, "Марина", 4.57, 18617),
    ("breathing-01-med", "Ровное дыхание покоя", "breathing", 9, True, "Станислав", 4.66, 26536),
    ("breathing-02-med", "Дыхание 4-7-8 для спокойствия", "breathing", 14, False, "Иван", 4.75, 34455),
    ("breathing-03-med", "Животное дыхание расслабления", "breathing", 19, True, "Марина", 4.84, 42374),
    ("breathing-04-med", "Дыхание — якорь внимания", "breathing", 6, False, "Станислав", 4.93, 40293),
    ("visualization-01-med", "Лесная тропа спокойствия", "visualization", 11, True, "Иван", 4.30, 18212),
    ("visualization-02-med", "Морской берег внутри", "visualization", 16, False, "Марина", 4.39, 26131),
    ("visualization-03-med", "Горная ясность", "visualization", 20, False, "Станислав", 4.48, 34050),
    ("visualization-04-med", "Сад внутреннего мира", "visualization", 7, True, "Иван", 4.57, 41969),
    ("emergency-01-med", "Быстрое успокоение за несколько минут", "emergency", 12, True, "Марина", 4.66, 19888),
    ("emergency-02-med", "Срочная передышка при панике", "emergency", 17, False, "Станислав", 4.75, 17807),
    ("emergency-03-med", "Стабилизация здесь и сейчас", "emergency", 5, False, "Иван", 4.84, 25726),
]

DESC_SUFFIX = " Практика на русском языке с мягким голосом ведущего, без резких переходов и с заботой о вашем темпе."


async def seed_meditations(db: AsyncSession):
    existing = await db.execute(select(Meditation.id))
    existing_ids = {r[0] for r in existing.all()}

    added = 0
    for mid, title, cat, dur, premium, voice, rating, play_count in MEDITATIONS:
        if mid in existing_ids:
            continue
        db.add(Meditation(
            id=mid,
            title=title,
            description=title + "." + DESC_SUFFIX,
            category=cat,
            duration_minutes=dur,
            audio_url=f"https://cdn.meditator.app/audio/{mid}.mp3",
            image_url=f"https://cdn.meditator.app/img/{cat}/{mid}.webp",
            is_premium=premium,
            voice_name=voice,
            rating=rating,
            play_count=play_count,
        ))
        added += 1

    if added:
        await db.commit()
    return added
