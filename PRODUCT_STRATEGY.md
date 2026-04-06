# Aura — Product Strategy: Meaning, Ritual, Retention, Premium

---

## PHASE 1: MEANING LAYER — Evolution Markers

Each visual change in the cosmos has a psychological meaning. The user should feel these changes as reflections of inner growth, not decorative upgrades.

### Evolution Markers (15 stages)

| Level | Sessions | Visual Change | Emotional Meaning | Profile Label |
|-------|----------|--------------|-------------------|---------------|
| 0 | 0 | Sparse stars, minimal bloom | Beginning — empty but full of potential | Рождение |
| 1 | 1-2 | First subtle bloom appears | First step taken — courage | Первый шаг |
| 3 | 3-5 | Star count increases to 56 | Returning — building a habit | Возвращение |
| 5 | 6-9 | Nebula subtly intensifies | Depth — emotional awareness growing | Пробуждение |
| 8 | 10-14 | Bloom warmth increases | Trust — the space feels safe | Доверие |
| 12 | 15-22 | Stars become brighter | Stability — emotional baseline strengthening | Стабильность |
| 16 | 23-30 | Second nebula layer visible | Resilience — recovering faster from stress | Устойчивость |
| 20 | 31-40 | Particle alpha increases | Openness — willing to look deeper | Открытость |
| 25 | 41-55 | Bloom radius expands | Groundedness — rooted in practice | Укоренение |
| 30 | 56-70 | Star field becomes denser | Inner richness — complexity feels manageable | Глубина |
| 35 | 71-90 | Vignette softens | Expansiveness — less constricted | Простор |
| 40 | 91-120 | Subtle color warmth shift | Compassion — warmth toward self | Тепло |
| 45 | 121-160 | Full nebula depth | Wisdom — patterns become visible | Мудрость |
| 48 | 161-200 | Maximum bloom + star density | Radiance — the universe is alive | Сияние |
| 50 | 200+ | Subtle ambient glow pulses | Presence — being here is enough | Присутствие |

Key principle: the user never sees a number. They see their sky change and occasionally the AI reflects it: "Твоя вселенная стабилизировалась на этой неделе."

---

## PHASE 2: RITUAL LAYER

### Morning Open (30-60 seconds)

- **Emotional goal:** Grounding before the day starts
- **UI flow:** Cosmos fades in slowly (1.5s instead of default 0.6s). AI presence enters `observing` state. After 2 seconds, a single question: "Как начинается утро?" with the 5 emotion chips. No intensity slider for morning — keep it fast.
- **AI role:** If morning mood is negative and yesterday was also negative, AI says something acknowledging continuity: "Опять непросто. Я здесь." If positive: silent mode. If first morning in 3+ days: "Давно не виделись."
- **Cosmos behavior:** Morning opens should use `waking` time context — slightly brighter bloom, particles slower than daytime.
- **Duration:** Under 30 seconds to check-in. The app respects morning time.

### Evening Check-in (60-90 seconds)

- **Emotional goal:** Release and reflection before sleep
- **UI flow:** Cosmos shifts toward sleepy palette automatically based on time. AI enters `calming` state. After check-in, if trajectory is "deescalating" or "stable", offer a short 60-second wind-down session instead of full session.
- **AI role:** Evening is the only time `reflective` mode should feel natural. "Сегодня было непросто. Но ты здесь." Pattern recognition works best in evening context.
- **Cosmos behavior:** Deeper vignette, slower particles, muted colors. The space contracts gently — like a room dimming.
- **Duration:** Check-in (15s) + optional micro-session (60s) + close.

### Post-Stress Recovery (triggered by high-intensity check-in)

- **Emotional goal:** Immediate relief
- **UI flow:** When intensity >= 4 on anxiety/overload, skip the standard home view and immediately offer Reality Break or a guided breathing session. The cosmos reacts to urgency — particles speed up briefly, then the system takes control and begins calming them.
- **AI role:** `suggestion` mode. Direct. "Дыши. Прямо сейчас." No options, just the action.
- **Cosmos behavior:** Start chaotic, transition to calm over 45-90 seconds.
- **Duration:** 45-90 seconds. Must feel fast.

### Post-Session Reflection (15-30 seconds)

- **Emotional goal:** Integration — connecting the practice to the feeling
- **UI flow:** After mood_after selection in afterglow, if mood improved, the cosmos does a visible brightness pulse (evolution feedback). If this is a milestone session (every 10th), a subtle recognition moment appears.
- **AI role:** Silent for most sessions. On milestones or significant improvement: a brief line.
- **Duration:** 15 seconds max. Don't over-process.

### Return After Absence (3+ days)

- **Emotional goal:** Welcome back without guilt
- **UI flow:** Normal cosmos loads but slightly dimmer (bloom reduced 15%). As the user checks in, bloom restores to full. Visual message: "Your space was waiting for you."
- **AI role:** `minimal` mode. Something like "Хорошо, что вернулся." Never "Where were you?" Never guilt.
- **Cosmos behavior:** Bloom reduction on load + restoration on first interaction.

---

## PHASE 3: RETENTION LAYER

### Principles

1. **Emotional attachment, not streak pressure.** The cosmos remembers. That's the hook. Users return because they want to see their space, not because a counter resets.

2. **Visual continuity as gravity.** The personal seed means no two users have the same sky. The evolution level means the sky has grown with them. Leaving means leaving a place that knows them.

3. **Subtle anticipation.** After a session, the cosmos is slightly brighter. By next morning, it settles to baseline. The user notices — not consciously, but emotionally — that the space feels best right after practice.

4. **Self-recognition.** The AI occasionally (not every time — maybe every 7-10 check-ins) says something that proves it sees the pattern: "По вечерам легче, чем раньше." This creates a feeling of being known.

### Anti-Pattern Avoidance

- No streak counters on the home screen (moved to profile only)
- No "You missed X days!" notifications
- No badges, no points, no leaderboards
- No artificial urgency

### Healthy Retention Mechanics

- **Bloom decay:** Cosmos very slowly dims (over 7+ days of no use). Not punishment — just natural settling. Like a garden that needs tending.
- **Morning notification (opt-in):** Not "Open the app!" but "Как утро?" — the question itself is the value. Single notification per day maximum.
- **Evening wind-down:** Gentle notification at user's chosen hour: "Пора замедлиться." Links directly to a 60-second session.

---

## PHASE 4: RECOGNITION MOMENTS

### Design Rules

- Maximum 1 recognition per week
- Only when data clearly supports the claim
- Shown as a brief AI presence message, not a modal or popup
- Must feel like the AI noticed, not like the system tracked

### Recognition Types

| Trigger | Data Source | AI Message Example | When Shown |
|---------|-----------|-------------------|-----------|
| Recovery speed improving | mood_after shows faster improvement over 5+ sessions | "Ты восстанавливаешься быстрее." | After session |
| Evening pattern improving | 7+ evening check-ins trending calmer | "Вечера становятся легче." | Evening check-in |
| Streak milestone (7, 14, 30) | streak counter | "Неделя подряд. Это ощущается." | Morning check-in |
| Universe evolution milestone | evolutionLevel crosses named threshold | "Твоя вселенная растёт." | After session |
| First calm after extended negative | 3+ negative check-ins then calm | "Перелом." | Check-in |
| Consistent practice | 10+ sessions in 14 days | "Практика становится привычкой." | Check-in |
| Returning after absence | 3+ days gap then check-in | "Хорошо, что вернулся." | Check-in |

### Implementation

Add `recognition` field to CompanionEngine response. Backend checks recognition conditions in StateEngine after computing EmotionalContext. At most one recognition per 7-day window per user (tracked in CompanionMemory).

---

## PHASE 5: PREMIUM VALUE LAYER

### Free Tier (complete, meaningful experience)

- Unlimited check-ins
- 5 emotion states
- Basic AI presence (minimal + silent modes)
- Standard cosmos evolution (up to level 25)
- 3 session types (anxiety_relief, energy_reset, deepen)
- Reality Break (always free — never gate emergency help)
- Basic timeline

### Premium Tier (deeper, more personal)

- **Deep AI Memory:** AI remembers beyond 30 days. Can reference "В марте ты часто чувствовал тревогу вечерами." Free tier: 30-day window. Premium: unlimited history.
- **Pattern Detection:** AI identifies recurring patterns (morning anxiety, post-work overload, weekend fatigue). Free: basic trend (improving/declining). Premium: named patterns with confidence.
- **Reflective Mode:** The AI's most powerful mode — pointing out patterns, challenging gently. Free tier gets minimal + suggestion + silent only.
- **Extended Evolution:** Cosmos evolution beyond level 25 (richer stars, deeper nebulae, warmer bloom). Free users plateau visually at level 25.
- **All Session Types:** 6 types instead of 3. Premium adds: overload_relief, grounding, sleep_reset.
- **Night Mode:** Special evening/night cosmos behavior with sleep-optimized sessions.
- **Intensity Tracking:** Full intensity history and trends (free users can set intensity but don't see trends).

### What Must NEVER Be Premium

- Reality Break (emergency help)
- Basic check-in flow
- Basic AI presence
- The cosmos itself (free users still see a beautiful, personal universe)

---

## PHASE 6: PAYWALL PHILOSOPHY

### Timing

The paywall should appear:
1. After the 5th completed session (user has experienced value)
2. When user tries a premium session type for the first time
3. When AI would say something reflective but can't (free tier)
4. Never during a crisis (Reality Break, high-urgency check-in)

### Experience

The paywall is NOT a separate screen that breaks flow. It's an invitation woven into the cosmos:

- Cosmos deepens slightly (preview of evolution beyond level 25)
- AI presence enters a warm state
- Text: "У Aura есть глубина, которую ты ещё не видел."
- Subtext: "Глубокая память. Паттерны. Расширенная вселенная."
- CTA: "Попробовать 7 дней бесплатно"
- Skip: "Позже" (always available, no guilt)

### Copy Principles

- Never "Unlock" — instead "Углубить" (deepen)
- Never "Premium features" — instead "Больше пространства"
- Never "Buy" — instead "Попробовать" (try)
- Price shown small, after value description

---

## PHASE 7: IMPLEMENTATION ROADMAP

### Sprint 1: Evolution Meaning (immediate impact)

- Add named evolution stages to CosmosState
- Update profile to show stage name instead of bare progress bar
- Add recognition moments to CompanionEngine (backend)
- Wire recognition display on home screen

### Sprint 2: Ritual Detection

- Add time-of-day context to home screen (morning/evening variants)
- Add return-after-absence detection in AuraEngine
- Add bloom decay logic (subtle dimming after 7+ days)
- Morning/evening notification scaffolding

### Sprint 3: Premium Gating

- Add premium check to session types
- Add premium check to reflective mode
- Gate evolution beyond level 25
- Gate AI memory beyond 30 days
- Redesign paywall screen with cosmos integration

### Sprint 4: Retention Measurement

- Add analytics events for key metrics
- Implement recognition frequency limiter (1 per 7 days)
- Add post-session mood improvement tracking

---

## PHASE 8: METRICS

### Core Metrics

| Metric | Target | What Improves It |
|--------|--------|-----------------|
| D1 Retention | >60% | Morning ritual, emotional continuity (restored mood) |
| D7 Retention | >35% | Evolution visibility, recognition moments, personal cosmos |
| D30 Retention | >20% | Deep AI memory, pattern detection, universe ownership |
| Session Completion | >80% | Short sessions (60-90s), guided breathing, post-session mood capture |
| Mood Improvement Rate | >50% positive shift | Session effectiveness learning, personalized session recommendations |
| Reality Break → Return in 24h | >70% | Non-judgmental AI, cosmos calming transition, absence welcome |
| Premium Conversion | >5% of D7 users | Reflective mode preview, evolution cap, premium session types |
| Premium Retention (M1) | >75% | Deep AI memory, pattern insights, extended evolution |

### Leading Indicators

- **Check-ins per day:** Should average 1.5-2 for retained users (morning + evening)
- **Time to first check-in after open:** Under 10 seconds = good flow, over 30 = friction
- **Intensity usage rate:** If users actually adjust intensity (not just default 3), signals are richer
- **mood_after capture rate:** Target >60% of completed sessions — this feeds the learning loop
- **Recognition engagement:** If users complete a session within 1 hour of a recognition moment, the recognition was motivating

---

## Summary

The product has the technical foundation. What it needs is:

1. **Meaning:** Every visual change tells the user something about themselves
2. **Ritual:** The app fits into morning and evening naturally
3. **Retention:** The cosmos is their space — they want to return to it
4. **Premium:** Depth, not volume — paying for a deeper relationship with themselves
