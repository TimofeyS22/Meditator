"""
AI Companion Engine v3 — Stateful emotional intelligence system.

Architecture:
  SignalCollector → StateEngine → DecisionEngine → ResponseGenerator
  MemorySystem provides anti-repetition and learning feedback.
"""

from __future__ import annotations

import json
import random
from collections import Counter
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone

import httpx
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import User, MoodEntry, Session, CompanionMemory
from app.config import settings, logger

# ─── Constants ────────────────────────────────────────────────────────────────

UNIVERSE_MOODS = ("calm", "anxiety", "fatigue", "overload", "emptiness", "focus", "joy", "sleepy")

MOOD_RU = {
    "anxiety": "тревога", "fatigue": "усталость", "overload": "перегрузка",
    "emptiness": "пустота", "calm": "спокойствие",
}

MOOD_SEVERITY = {"calm": 0, "emptiness": 1, "fatigue": 2, "anxiety": 3, "overload": 4}

TIME_CONTEXTS = {
    range(0, 5): "deep_night", range(5, 7): "waking", range(7, 12): "morning",
    range(12, 17): "day", range(17, 22): "evening", range(22, 24): "sleeping",
}

TIME_CONTEXTS_RU = {
    "deep_night": "глубокая ночь", "waking": "раннее утро", "morning": "утро",
    "day": "день", "evening": "вечер", "sleeping": "ночь",
}

ACTIONS: dict[str, dict] = {
    "anxiety":   {"label": "Сбросить за 1 мин", "short_prompt": "Дыхание замедлит всё",    "session_type": "anxiety_relief",  "duration_seconds": 60},
    "fatigue":   {"label": "Перезагрузка",      "short_prompt": "Мягкий ресет для тела",    "session_type": "energy_reset",    "duration_seconds": 90},
    "overload":  {"label": "Стоп. Тишина.",     "short_prompt": "Просто дыши",              "session_type": "overload_relief", "duration_seconds": 60},
    "emptiness": {"label": "Почувствовать",     "short_prompt": "Мягкое возвращение к себе", "session_type": "grounding",       "duration_seconds": 90},
    "calm":      {"label": "Углубиться",        "short_prompt": "Хороший момент",            "session_type": "deepen",          "duration_seconds": 90},
}

BREATH_SPEED = {
    "calm": 1.0, "anxiety": 0.5, "overload": 0.4,
    "fatigue": 0.7, "emptiness": 0.8, "focus": 0.9,
    "joy": 1.1, "sleepy": 0.6,
}

FALLBACK_TEMPLATES: dict[str, dict[str, list[str]]] = {
    "minimal": {
        "anxiety":   ["Я рядом.", "Тише.", "Дыши.", "Здесь безопасно.", "Замедлимся.", "Ты в порядке."],
        "fatigue":   ["Отдохни.", "Не спеши.", "Тебе можно остановиться.", "Пауза.", "Мягче."],
        "overload":  ["Стоп.", "Тишина.", "Просто дыши.", "Ничего не нужно делать.", "Здесь тихо."],
        "emptiness": ["Я здесь.", "Ты не один.", "Подождём вместе.", "Рядом.", "Ничего не нужно."],
        "calm":      [],
    },
    "suggestion": {
        "anxiety":   ["Попробуем дыхание?", "Минута тишины поможет.", "Давай замедлим дыхание."],
        "fatigue":   ["Мягкая перезагрузка?", "Короткий отдых поможет.", "Минута для тела?"],
        "overload":  ["Просто закрой глаза на минуту.", "Дыхание. Прямо сейчас.", "Стоп. Дышим."],
        "emptiness": ["Послушаем тишину вместе?", "Попробуем почувствовать?", "Мягкое возвращение?"],
        "calm":      ["Углубим это?", "Хороший момент для практики."],
    },
    "reflective": {
        "anxiety":   ["Тревога приходит часто. Замечаешь?", "Вечерний паттерн. Видишь?"],
        "fatigue":   ["Усталость стала привычной. Замечаешь?"],
        "overload":  ["Перегрузка повторяется. Что если замедлиться?"],
        "emptiness": ["Пустота возвращается. Но ты приходишь сюда — это важно."],
        "calm":      [],
    },
}

# ─── State Engine ─────────────────────────────────────────────────────────────

@dataclass
class EmotionalContext:
    raw_emotion: str
    intensity: int
    computed_urgency: float
    trajectory: str          # escalating | deescalating | stuck | fluctuating | stable
    volatility: float        # 0.0-1.0
    time_context: str        # deep_night | waking | morning | day | evening | sleeping
    relationship_stage: str  # stranger | acquaintance | familiar | trusted
    pattern_match: str | None
    recent_sequence: list[str] = field(default_factory=list)
    dominant: str = "calm"
    calm_ratio: float = 0.0
    trend: str = "stable"
    total_checkins: int = 0
    effective_types: list[str] = field(default_factory=list)
    morning_dominant: str | None = None
    evening_dominant: str | None = None
    days_since_first: int = 0
    last_response_text: str = ""


class StateEngine:
    """Computes rich emotional context from raw signals + DB history."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def compute(
        self, user: User, mood: str, intensity: int, hour: int,
        seconds_since_last: int | None = None,
    ) -> EmotionalContext:
        cutoff = datetime.now(timezone.utc) - timedelta(days=30)

        entries = await self._load_entries(user.id, cutoff)
        total = len(entries)
        emotions = [e.emotion for e in entries]

        time_ctx = self._time_context(hour)
        days_since = (datetime.now(timezone.utc) - user.created_at.replace(tzinfo=timezone.utc)).days if user.created_at else 0

        if total < 3:
            return EmotionalContext(
                raw_emotion=mood, intensity=intensity,
                computed_urgency=self._urgency(intensity, 0, mood),
                trajectory="stable", volatility=0.0,
                time_context=time_ctx,
                relationship_stage="stranger",
                pattern_match=None,
                recent_sequence=emotions,
                total_checkins=total,
                days_since_first=days_since,
            )

        counter = Counter(emotions)
        dominant = counter.most_common(1)[0][0]
        calm_ratio = counter.get("calm", 0) / total

        recent_5 = emotions[-5:] if len(emotions) >= 5 else emotions
        trajectory = self._trajectory(recent_5)
        volatility = self._volatility(entries)

        split = max(total - 7, 0)
        recent_entries = entries[split:]
        older_entries = entries[:split] if split else entries
        trend = self._trend(recent_entries, older_entries)

        effective = await self._effective_types(user.id, cutoff)
        morning, evening = self._time_dominants(entries)
        pattern = self._detect_pattern(entries, mood, hour)
        last_resp = await self._load_last_response(user.id)

        rel_stage = self._relationship_stage(total, days_since)
        urgency = self._urgency(intensity, volatility, mood)

        return EmotionalContext(
            raw_emotion=mood, intensity=intensity,
            computed_urgency=urgency,
            trajectory=trajectory, volatility=volatility,
            time_context=time_ctx,
            relationship_stage=rel_stage,
            pattern_match=pattern,
            recent_sequence=[e.emotion for e in recent_entries],
            dominant=dominant, calm_ratio=calm_ratio, trend=trend,
            total_checkins=total,
            effective_types=effective,
            morning_dominant=morning, evening_dominant=evening,
            days_since_first=days_since,
            last_response_text=last_resp,
        )

    async def _load_entries(self, user_id: str, cutoff: datetime) -> list[MoodEntry]:
        rows = await self.db.execute(
            select(MoodEntry)
            .where(MoodEntry.user_id == user_id, MoodEntry.created_at >= cutoff)
            .order_by(MoodEntry.created_at.asc())
        )
        return list(rows.scalars().all())

    @staticmethod
    def _time_context(hour: int) -> str:
        for hours_range, ctx in TIME_CONTEXTS.items():
            if hour in hours_range:
                return ctx
        return "day"

    @staticmethod
    def _trajectory(recent: list[str]) -> str:
        if len(recent) < 3:
            return "stable"

        severities = [MOOD_SEVERITY.get(m, 2) for m in recent]

        if len(set(recent)) == 1 and recent[0] != "calm":
            return "stuck"

        diffs = [severities[i+1] - severities[i] for i in range(len(severities)-1)]
        avg_diff = sum(diffs) / len(diffs)

        if avg_diff > 0.5:
            return "escalating"
        if avg_diff < -0.5:
            return "deescalating"

        ups = sum(1 for d in diffs if d > 0)
        downs = sum(1 for d in diffs if d < 0)
        if ups >= 2 and downs >= 1:
            return "fluctuating"

        return "stable"

    @staticmethod
    def _volatility(entries: list[MoodEntry]) -> float:
        last_24h = [e for e in entries if e.created_at > datetime.now(timezone.utc) - timedelta(hours=24)]
        if len(last_24h) < 2:
            return 0.0
        distinct = len(set(e.emotion for e in last_24h))
        return min(distinct / 4.0, 1.0)

    @staticmethod
    def _trend(recent: list[MoodEntry], older: list[MoodEntry]) -> str:
        if not recent:
            return "stable"
        r_calm = sum(1 for e in recent if e.emotion == "calm") / len(recent)
        o_calm = (sum(1 for e in older if e.emotion == "calm") / len(older)) if older else r_calm
        if r_calm > o_calm + 0.15:
            return "improving"
        if r_calm < o_calm - 0.15:
            return "declining"
        return "stable"

    @staticmethod
    def _relationship_stage(total_checkins: int, days: int) -> str:
        if total_checkins < 3:
            return "stranger"
        if total_checkins < 15:
            return "acquaintance"
        if total_checkins < 50:
            return "familiar"
        return "trusted"

    @staticmethod
    def _urgency(intensity: int, volatility: float, mood: str) -> float:
        base = intensity / 5.0
        mood_weight = MOOD_SEVERITY.get(mood, 2) / 4.0
        return min((base * 0.5 + mood_weight * 0.3 + volatility * 0.2), 1.0)

    @staticmethod
    def _detect_pattern(entries: list[MoodEntry], current_mood: str, current_hour: int) -> str | None:
        if len(entries) < 7:
            return None

        hour_bracket = (current_hour // 4) * 4
        same_time_same_mood = [
            e for e in entries
            if e.emotion == current_mood
            and abs(e.created_at.hour - current_hour) <= 2
        ]
        if len(same_time_same_mood) >= 3:
            return f"recurring_{TIME_CONTEXTS_RU.get(StateEngine._time_context(current_hour), '')}_{MOOD_RU.get(current_mood, current_mood)}"

        return None

    @staticmethod
    def _time_dominants(entries: list[MoodEntry]) -> tuple[str | None, str | None]:
        morning = [e.emotion for e in entries if 5 <= e.created_at.hour < 12]
        evening = [e.emotion for e in entries if 17 <= e.created_at.hour < 23]
        m_dom = Counter(morning).most_common(1)[0][0] if morning else None
        e_dom = Counter(evening).most_common(1)[0][0] if evening else None
        return m_dom, e_dom

    async def _effective_types(self, user_id: str, cutoff: datetime) -> list[str]:
        rows = await self.db.execute(
            select(Session).where(
                Session.user_id == user_id,
                Session.completed.is_(True),
                Session.mood_before.isnot(None),
                Session.mood_after.isnot(None),
                Session.created_at >= cutoff,
            )
        )
        counts: dict[str, int] = {}
        for s in rows.scalars():
            before = MOOD_SEVERITY.get(s.mood_before, 2)
            after = MOOD_SEVERITY.get(s.mood_after, 2)
            if after < before:
                counts[s.session_type] = counts.get(s.session_type, 0) + 1
        return [t for t, _ in sorted(counts.items(), key=lambda x: -x[1])[:3]]

    async def _load_last_response(self, user_id: str) -> str:
        row = await self.db.execute(
            select(CompanionMemory.value)
            .where(
                CompanionMemory.user_id == user_id,
                CompanionMemory.memory_type == "last_response",
                CompanionMemory.key == "last_presence",
            )
        )
        result = row.scalar_one_or_none()
        if result:
            try:
                data = json.loads(result)
                return data.get("text", "")
            except (json.JSONDecodeError, TypeError):
                pass
        return ""


# ─── Decision Engine ──────────────────────────────────────────────────────────

@dataclass
class Decision:
    response_mode: str      # silent | minimal | suggestion | reflective
    universe_mood: str
    max_words: int
    should_call_gpt: bool
    action: dict | None


class DecisionEngine:
    """Deterministic decisions BEFORE GPT is called."""

    @staticmethod
    def decide(ctx: EmotionalContext, user: User, seconds_since_last: int | None) -> Decision:
        mode = DecisionEngine._decide_mode(ctx, seconds_since_last)
        universe_mood = DecisionEngine._decide_universe_mood(ctx, user)
        max_words = {"silent": 0, "minimal": 8, "suggestion": 15, "reflective": 25}.get(mode, 10)
        should_call = mode != "silent" and ctx.relationship_stage != "stranger"
        action = DecisionEngine._decide_action(ctx, mode, universe_mood)

        return Decision(
            response_mode=mode,
            universe_mood=universe_mood,
            max_words=max_words,
            should_call_gpt=should_call,
            action=action,
        )

    @staticmethod
    def _decide_mode(ctx: EmotionalContext, seconds_since_last: int | None) -> str:
        if ctx.computed_urgency > 0.8 and ctx.trajectory == "escalating":
            return "suggestion"

        if ctx.relationship_stage == "stranger":
            return "minimal"

        if ctx.time_context in ("deep_night", "sleeping"):
            return "silent"

        if ctx.trajectory == "stuck" and ctx.relationship_stage in ("familiar", "trusted"):
            return "reflective"

        if ctx.raw_emotion == "calm" and ctx.volatility < 0.2:
            return "silent"

        if seconds_since_last is not None and seconds_since_last < 300:
            return "silent"

        if ctx.pattern_match and ctx.relationship_stage in ("familiar", "trusted"):
            return "reflective"

        return "minimal"

    @staticmethod
    def _decide_universe_mood(ctx: EmotionalContext, user: User) -> str:
        if ctx.time_context in ("deep_night", "sleeping"):
            return "sleepy"
        if ctx.raw_emotion == "calm" and user.current_streak >= 10:
            return "joy"
        if ctx.raw_emotion == "calm" and ctx.time_context == "waking":
            return "focus"
        return ctx.raw_emotion if ctx.raw_emotion in UNIVERSE_MOODS else "calm"

    @staticmethod
    def _decide_action(ctx: EmotionalContext, mode: str, universe_mood: str) -> dict | None:
        if mode == "silent" and ctx.raw_emotion == "calm":
            return None

        late = ctx.time_context in ("deep_night", "sleeping")
        if late:
            action = {"label": "Уснуть", "short_prompt": "Дыши и отпусти день",
                       "session_type": "sleep_reset", "duration_seconds": 90}
        else:
            action = ACTIONS.get(ctx.raw_emotion, ACTIONS["calm"]).copy()

        action["color_hex"] = _color_for_mood(universe_mood)
        return action


# ─── Memory System ────────────────────────────────────────────────────────────

class MemorySystem:
    """Persistent memory for anti-repetition and learning."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def save_response(self, user_id: str, text: str, mode: str) -> None:
        await self._upsert(user_id, "last_response", "last_presence",
                           json.dumps({"text": text, "mode": mode,
                                       "at": datetime.now(timezone.utc).isoformat()}))

    async def save_pattern(self, user_id: str, pattern_key: str, confidence: float) -> None:
        existing = await self._get(user_id, "pattern", pattern_key)
        if existing:
            data = json.loads(existing)
            data["confidence"] = round(confidence, 2)
            data["seen_count"] = data.get("seen_count", 1) + 1
        else:
            data = {"confidence": round(confidence, 2), "seen_count": 1,
                    "first_seen": datetime.now(timezone.utc).isoformat()}
        await self._upsert(user_id, "pattern", pattern_key, json.dumps(data))

    async def save_effectiveness(self, user_id: str, session_type: str, improvement: float) -> None:
        existing = await self._get(user_id, "effective_session", session_type)
        if existing:
            data = json.loads(existing)
            count = data.get("count", 0) + 1
            old_avg = data.get("avg_improvement", 0)
            data["avg_improvement"] = round((old_avg * (count - 1) + improvement) / count, 2)
            data["count"] = count
        else:
            data = {"avg_improvement": round(improvement, 2), "count": 1}
        await self._upsert(user_id, "effective_session", session_type, json.dumps(data))

    async def _upsert(self, user_id: str, mem_type: str, key: str, value: str) -> None:
        row = await self.db.execute(
            select(CompanionMemory).where(
                CompanionMemory.user_id == user_id,
                CompanionMemory.memory_type == mem_type,
                CompanionMemory.key == key,
            )
        )
        mem = row.scalar_one_or_none()
        if mem:
            mem.value = value
            mem.updated_at = datetime.now(timezone.utc)
        else:
            self.db.add(CompanionMemory(
                user_id=user_id, memory_type=mem_type, key=key, value=value,
            ))
        await self.db.flush()

    async def _get(self, user_id: str, mem_type: str, key: str) -> str | None:
        row = await self.db.execute(
            select(CompanionMemory.value).where(
                CompanionMemory.user_id == user_id,
                CompanionMemory.memory_type == mem_type,
                CompanionMemory.key == key,
            )
        )
        return row.scalar_one_or_none()


# ─── Response Generator ──────────────────────────────────────────────────────

SYSTEM_PROMPT_TEMPLATE = """\
Ты — эмоциональное присутствие. Не чат-бот, не терапевт, не ассистент.
Спокойная сущность, которая чувствует.

ОГРАНИЧЕНИЯ:
- Режим: {mode}
- Максимум слов: {max_words}
- Язык: русский, на "ты"
- НЕ ПОВТОРЯЙ: "{last_response}"
- Отношения: {stage} — {stage_instruction}
- Траектория: {trajectory} — {trajectory_instruction}
{pattern_instruction}

Верни JSON: {{"presence_message": "...", "insight": ... }}
- insight: строка если режим reflective, иначе null
"""

STAGE_INSTRUCTIONS = {
    "stranger": "Будь мягким. Только присутствие, никаких советов.",
    "acquaintance": "Можешь предложить действие. Коротко.",
    "familiar": "Можешь указать на паттерн. Аккуратно.",
    "trusted": "Можешь быть прямым. Пользователь тебе доверяет.",
}

TRAJECTORY_INSTRUCTIONS = {
    "escalating": "Состояние ухудшается. Будь рядом, предложи помощь.",
    "deescalating": "Становится лучше. Поддержи тихо.",
    "stuck": "Застрял в одном состоянии. Мягко обрати внимание.",
    "fluctuating": "Эмоции скачут. Стабильность важнее слов.",
    "stable": "Стабильно. Не навязывайся.",
}


class ResponseGenerator:
    """Generates response via GPT or fallback templates."""

    @staticmethod
    async def generate(
        ctx: EmotionalContext, decision: Decision, user: User,
    ) -> dict:
        presence = ""
        insight = None

        if decision.response_mode != "silent":
            if decision.should_call_gpt:
                gpt_result = await ResponseGenerator._call_gpt(ctx, decision)
                if gpt_result:
                    presence = gpt_result.get("presence_message", "")
                    insight = gpt_result.get("insight")

            if not presence:
                presence = ResponseGenerator._fallback_text(
                    decision.response_mode, ctx.raw_emotion, ctx.last_response_text,
                )

        return {
            "response_mode": decision.response_mode,
            "presence": presence,
            "insight": insight,
            "universe_mood": decision.universe_mood,
            "action": decision.action,
            "universe": _universe_params(decision.universe_mood, ctx, user),
            "tone": _tone_from_mode(decision.response_mode),
            "patterns_summary": _summary(ctx),
            "orb_breath_speed": BREATH_SPEED.get(decision.universe_mood, 1.0),
        }

    @staticmethod
    async def _call_gpt(ctx: EmotionalContext, decision: Decision) -> dict | None:
        api_key = settings.ai_api_key or settings.openai_api_key
        if not api_key:
            return None

        pattern_line = ""
        if ctx.pattern_match:
            pattern_line = f"- Обнаружен паттерн: {ctx.pattern_match}"

        system = SYSTEM_PROMPT_TEMPLATE.format(
            mode=decision.response_mode,
            max_words=decision.max_words,
            last_response=ctx.last_response_text or "(нет предыдущего)",
            stage=ctx.relationship_stage,
            stage_instruction=STAGE_INSTRUCTIONS.get(ctx.relationship_stage, ""),
            trajectory=ctx.trajectory,
            trajectory_instruction=TRAJECTORY_INSTRUCTIONS.get(ctx.trajectory, ""),
            pattern_instruction=pattern_line,
        )

        context_lines = [
            f"Эмоция: {MOOD_RU.get(ctx.raw_emotion, ctx.raw_emotion)}",
            f"Интенсивность: {ctx.intensity}/5",
            f"Срочность: {ctx.computed_urgency:.1f}",
            f"Траектория: {ctx.trajectory}",
            f"Время: {ctx.time_context} ({TIME_CONTEXTS_RU.get(ctx.time_context, '')})",
            f"Чекинов всего: {ctx.total_checkins}",
            f"Тренд: {ctx.trend}",
            f"Последние: {', '.join(MOOD_RU.get(m, m) for m in ctx.recent_sequence[-5:])}",
        ]
        if ctx.effective_types:
            context_lines.append(f"Эффективные сессии: {', '.join(ctx.effective_types)}")
        if ctx.pattern_match:
            context_lines.append(f"Паттерн: {ctx.pattern_match}")

        context_str = "\n".join(context_lines)

        try:
            async with httpx.AsyncClient(timeout=20) as client:
                resp = await client.post(
                    f"{settings.ai_base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {api_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": settings.ai_model,
                        "temperature": 0.7,
                        "max_tokens": decision.max_words * 8,
                        "response_format": {"type": "json_object"},
                        "messages": [
                            {"role": "system", "content": system},
                            {"role": "user", "content": context_str},
                        ],
                    },
                )

            if resp.status_code != 200:
                logger.warning("GPT returned %d", resp.status_code)
                return None

            raw = resp.json()["choices"][0]["message"]["content"]
            return json.loads(raw)

        except Exception as exc:
            logger.error("GPT companion request failed: %s", exc, exc_info=True)
            return None

    @staticmethod
    def _fallback_text(mode: str, emotion: str, last_text: str) -> str:
        templates = FALLBACK_TEMPLATES.get(mode, FALLBACK_TEMPLATES["minimal"])
        options = templates.get(emotion, [])
        if not options:
            options = templates.get("calm", [""])

        available = [t for t in options if t != last_text]
        if not available:
            available = options

        return random.choice(available) if available else ""


# ─── Companion Engine (public API) ────────────────────────────────────────────

RECOGNITION_MESSAGES = {
    "recovery_faster": "Ты восстанавливаешься быстрее.",
    "evenings_calmer": "Вечера становятся легче.",
    "streak_7": "Неделя подряд. Это ощущается.",
    "streak_14": "Две недели. Твоя вселенная это чувствует.",
    "streak_30": "Месяц. Это уже часть тебя.",
    "first_calm_after_storm": "Перелом.",
    "consistent_practice": "Практика становится привычкой.",
    "returning_after_absence": "Хорошо, что вернулся.",
    "universe_growing": "Твоя вселенная растёт.",
}


class CompanionEngine:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.state_engine = StateEngine(db)
        self.memory = MemorySystem(db)

    async def get_response(
        self, user: User, mood: str, hour: int,
        intensity: int = 3, seconds_since_last: int | None = None,
    ) -> dict:
        ctx = await self.state_engine.compute(user, mood, intensity, hour, seconds_since_last)
        decision = DecisionEngine.decide(ctx, user, seconds_since_last)
        result = await ResponseGenerator.generate(ctx, decision, user)

        # Check recognition moments (max 1 per 7 days)
        recognition = await self._check_recognition(user, ctx)
        if recognition:
            result["recognition"] = recognition

        # Persist memory
        if result["presence"]:
            await self.memory.save_response(user.id, result["presence"], decision.response_mode)
        if ctx.pattern_match:
            await self.memory.save_pattern(user.id, ctx.pattern_match, 0.7)

        # Persist user analytics
        await self._persist_user(user, ctx)

        return result

    async def _check_recognition(self, user: User, ctx: EmotionalContext) -> str | None:
        last_recognition = await self.memory._get(user.id, "last_response", "last_recognition")
        if last_recognition:
            try:
                data = json.loads(last_recognition)
                last_at = datetime.fromisoformat(data.get("at", "2000-01-01"))
                if (datetime.now(timezone.utc) - last_at).days < 7:
                    return None
            except (json.JSONDecodeError, ValueError):
                pass

        recognition = None

        if seconds_since_last := ctx.days_since_first:
            pass

        if ctx.trajectory == "deescalating" and ctx.raw_emotion == "calm":
            recent_neg = sum(1 for m in ctx.recent_sequence if m != "calm")
            if recent_neg >= 3:
                recognition = "first_calm_after_storm"

        elif user.current_streak == 7:
            recognition = "streak_7"
        elif user.current_streak == 14:
            recognition = "streak_14"
        elif user.current_streak == 30:
            recognition = "streak_30"

        elif ctx.trend == "improving" and ctx.total_checkins >= 10:
            recognition = "recovery_faster"

        elif ctx.total_checkins >= 10 and ctx.total_checkins % 10 == 0:
            recognition = "consistent_practice"

        if recognition:
            msg = RECOGNITION_MESSAGES.get(recognition, "")
            await self.memory._upsert(
                user.id, "last_response", "last_recognition",
                json.dumps({"key": recognition, "at": datetime.now(timezone.utc).isoformat()}),
            )
            return msg

        return None

    async def _persist_user(self, user: User, ctx: EmotionalContext) -> None:
        user.companion_tone = _tone_from_mode("minimal")
        user.dominant_emotion = ctx.dominant
        user.emotional_trend = ctx.trend
        user.calm_ratio = ctx.calm_ratio
        eff = ctx.effective_types
        user.effective_session_types = json.dumps(eff) if eff else None
        await self.db.commit()


# ─── Shared helpers ───────────────────────────────────────────────────────────

def _color_for_mood(mood: str) -> str:
    return {
        "calm": "#406882", "anxiety": "#FF5E5B", "fatigue": "#4B4453",
        "overload": "#451A75", "emptiness": "#1F2833", "focus": "#FCA311",
        "joy": "#FFCA3A", "sleepy": "#1A508B",
    }.get(mood, "#8B7FFF")


def _tone_from_mode(mode: str) -> str:
    return {
        "minimal": "balanced", "suggestion": "affirming",
        "silent": "minimal", "reflective": "warm_supportive",
    }.get(mode, "balanced")


def _universe_params(mood: str, ctx: EmotionalContext, user: User) -> dict:
    calm_est = int(user.total_sessions * ctx.calm_ratio) if ctx.calm_ratio else 0
    evo = min(calm_est * 0.02 + user.current_streak * 0.05, 1.0)

    configs = {
        "calm":      (0.65, 0.7, 0.6, 0.15, "#406882", "#1A374D"),
        "anxiety":   (0.30, 0.9, 0.3, 0.70, "#0D1B2A", "#FF5E5B"),
        "fatigue":   (0.20, 0.4, 0.4, 0.10, "#4B4453", "#3A2731"),
        "overload":  (0.40, 1.2, 0.5, 0.90, "#451A75", "#2F1B3D"),
        "emptiness": (0.08, 0.1, 0.1, 0.02, "#0B0C10", "#1F2833"),
        "focus":     (0.55, 0.7, 0.4, 0.20, "#14213D", "#FCA311"),
        "joy":       (0.80, 0.9, 0.7, 0.35, "#FFCA3A", "#FF595E"),
        "sleepy":    (0.15, 0.3, 0.3, 0.05, "#0A2342", "#1A508B"),
    }
    base = configs.get(mood, configs["calm"])
    return {
        "brightness": round(min(base[0] + evo * 0.2, 1.5), 3),
        "star_density": round(min(base[1] + evo * 0.3, 2.0), 3),
        "nebula_intensity": round(min(base[2] + evo * 0.15, 1.5), 3),
        "particle_speed": base[3],
        "dominant_color_hex": base[4],
        "accent_color_hex": base[5],
    }


def _summary(ctx: EmotionalContext) -> str:
    trend_ru = {"improving": "Улучшение", "declining": "Напряжение", "stable": "Стабильно"}
    parts = [trend_ru.get(ctx.trend, "")]
    if ctx.dominant != "calm":
        parts.append(f"Чаще: {MOOD_RU.get(ctx.dominant, ctx.dominant)}")
    if ctx.pattern_match:
        parts.append(f"Паттерн: {ctx.pattern_match}")
    return ". ".join(p for p in parts if p) + "." if any(parts) else ""
