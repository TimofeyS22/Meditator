# Aura — Growth & Conversion Strategy

## Current State

The landing page creates emotional resonance and has interactive elements (breathing orb, scroll-calming cosmos, particles). But it has zero conversion infrastructure — every CTA points to `#pricing` which has a dead button (`href="#"`).

## The Funnel

```
Landing page → Try breathing (web) → Feel relief → Create account → Download app → Premium
```

The key insight: the product's value is FELT, not explained. So the conversion funnel must deliver the feeling BEFORE asking for anything.

---

## Phase 1: Web Breathing Experience (try.html)

A standalone page at `mymeditator.ru/try` that delivers one full guided breathing session in the browser. No download. No signup. Just relief.

Flow:
1. User clicks any CTA on landing page → `/try`
2. Page shows: "Что ты сейчас чувствуешь?" with 3 options (Тревога / Перегрузка / Усталость)
3. Selection triggers a 60-second guided breathing session with the orb
4. After session: "Стало легче?" → mood capture
5. If improved: "Хочешь, чтобы это было всегда с тобой?" → app download / web signup
6. If not improved: "Попробуй ещё раз" or "Скачай приложение для полного опыта"

This is the highest-leverage conversion asset: the user experiences real relief before being asked for anything.

## Phase 2: Trust Signals

Add to landing page:
- "2,847 дыханий сегодня" — aggregated usage counter below hero (updates slowly)
- "78% чувствуют себя лучше после первой сессии" — result stat in problem section
- App Store / Google Play badges in pricing section

## Phase 3: Payment Architecture (Web-First)

For Russian market, web payments bypass App Store 30% cut:
1. User signs up on web (email + password via `/api/auth/register`)
2. Payment via YooKassa / CloudPayments / Tinkoff Pay (direct integration)
3. Premium flag set on User model
4. User downloads app, logs in — premium already active

Pricing page CTA flow:
- "7 дней бесплатно" → signup modal (email/password) → payment form (card after trial)
- No card required for trial (set up billing after 7 days via email reminder)

## Phase 4: Conversion Metrics to Track

| Event | Metric |
|---|---|
| Landing page → /try | Click-through rate |
| /try → mood selection | Engagement rate |
| Mood selection → session start | Activation rate |
| Session complete | Completion rate |
| Post-session → signup | Conversion rate |
| Signup → premium trial | Trial start rate |
| Trial → paid | Payment conversion |

## Phase 5: Entry Points

1. **Organic search:** "как быстро успокоиться" / "снять тревогу за минуту" → landing page
2. **Social:** Short-form video showing orb breathing → /try link
3. **Referral:** "Отправь другу минуту спокойствия" → /try?ref=USER_ID
4. **Crisis search:** "паническая атака что делать" → /try?mood=anxiety (skips selection, goes straight to breathing)

## Implementation Priority

1. **`/try` page** — web breathing experience (highest conversion impact)
2. **Trust signals** on landing page (usage counter, result stat)
3. **Signup flow** (email modal, no separate page)
4. **YooKassa integration** for web payments
5. **App deep links** for post-signup app download
