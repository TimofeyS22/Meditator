# Aura — Emotional Impact Analysis

## The Brutal Truth

The app has sophisticated AI, a living cosmos, named evolution stages, recognition moments, and a beautiful visual system. None of that matters if the user does not FEEL BETTER after using it.

After tracing the actual user experience line by line, here are the problems that make the product fail at its core purpose.

---

## CRITICAL PROBLEM 1: Sessions Are Empty

A 60-second "anxiety_relief" session consists of:
- A breathing circle that pulses at 5s/5s (generic, not evidence-based)
- One static line of text: "Каждый выдох уносит напряжение"
- A thin progress bar
- Audio files that DO NOT EXIST in the repository

The user watches a circle for 60 seconds with no guidance, no phase changes, no feedback, likely in silence. This does not reduce anxiety. It is a timer with a decoration.

**What actually reduces anxiety:** 4-7-8 breathing (4s inhale, 7s hold, 8s exhale). Box breathing (4-4-4-4). Guided progressive muscle relaxation. Body scan cues. These are researched, proven techniques. The app uses none of them.

## CRITICAL PROBLEM 2: Time to Relief Is Too Long

An anxious user opens the app:
- 7 seconds of splash animation (light dot, particles)
- Route transition (1.2s)
- Mood selector appears
- Tap mood → 2.5 second auto-wait for intensity
- Tap session button
- 0.8 second delay before session starts

**Minimum 12+ seconds before anything helpful begins.** For someone in a panic, this is an eternity. The splash animation is beautiful but actively harmful — it delays help.

## CRITICAL PROBLEM 3: Nothing Changes During the Session

The session has no phases. The breathing label alternates "Вдох" / "Выдох" at a fixed rate for the entire duration. There is no:
- Warm-up phase (slower breathing at start)
- Deepening phase (extending exhale)
- Guided cues that evolve ("Now relax your shoulders", "Let your jaw soften")
- Countdown or phase progress
- Any variation over 60 seconds

The user has no sense of progression WITHIN the session. It feels the same at second 5 and second 55.

## PROBLEM 4: Post-Session Has No Proof

After the session, the user sees "Ты это сделал" and a mood selector. There is no evidence that anything worked:
- No comparison of breathing rate before/after
- No "You completed 12 breath cycles"
- No reflection prompt
- Just a congratulation and a button

---

## The 3 Experiences That Actually Matter

Everything else — the cosmos evolution, the AI memory, the evolution stages, the recognition moments — is secondary. If these 3 moments fail, the product fails:

### 1. The First 30 Seconds After Check-In (immediate relief)

This is why the user opened the app. They feel bad. They need something to change in their body within 30 seconds. Not 12 seconds of splash + mood picker + waiting. Not a beautiful orb. A physical change in their breathing pattern that reduces heart rate.

### 2. The Session Itself (sustained relief over 60-90 seconds)

The session must guide the user through a structured breathing technique that physically reduces anxiety. Phase-based. Evolving. With clear cues. The user should feel their body calm down.

### 3. The Moment They Return Tomorrow (habit proof)

The AI must say ONE thing that proves it remembers. Not a recognition badge. A single sentence that references yesterday. "Вчера было легче к вечеру." This creates the feeling of continuity that makes them return.

---

## What to Fix (Priority Order)

1. **Implement evidence-based breathing** — 4-7-8 for anxiety, box breathing for overload, extended exhale for fatigue. Multi-phase with clear visual labels for inhale/hold/exhale.

2. **Add session phases** — Intro (5s, "Закрой глаза"), main breathing (structured cycles with phase labels), wind-down (5s, slower), completion. The session must feel like a journey, not a timer.

3. **Remove intensity auto-wait for high urgency** — If user selects anxiety or overload, skip intensity and go straight to session offer. Speed over precision when someone needs help.

4. **Shorten splash for returning users** — 3 seconds max, not 7.

---

## Simulated Users

### Anxious Student (Day 1-3)

**Day 1:** Opens app at 11 PM before an exam. Watches light dot for 7 seconds. Selects "Тревога". Waits 2.5 seconds. Sees orb and "Давай замедлимся." Taps session. Watches breathing circle in silence for 60 seconds. Circle pulses at 5s/5s. Student doesn't know if they're breathing correctly. Session ends. "Ты это сделал." Student feels: "That didn't really do anything." Closes app.

**Day 2:** Does not return. The 60-second session with no guidance didn't produce noticeable relief. The cosmos was pretty but irrelevant to their anxiety.

**Day 3:** Has another panic moment. Remembers the app exists. Opens it reluctantly. Same flow. If the session actually guided them through 4-7-8 breathing with clear timing, they would have felt their heart rate drop. They would return.

**Fix:** Structured breathing with audible/visual phases. The student must FEEL their heart rate change within 30 seconds of the first breath cycle.

### Burned-Out Developer (Day 1-3)

**Day 1:** Downloads app. Goes through 16-second onboarding. Arrives at home. "Как ты сейчас?" — selects "Усталость". Intensity picker appears. Developer thinks: "I'm too tired for this." Waits 2.5 seconds. Sees "Перезагрузка" button. Taps it. 90-second session. Circle pulses. One line: "Мягко возвращай внимание к телу." No audio. Developer zones out. Session ends. Closes app.

**Day 2:** Forgets about the app. Nothing about yesterday's experience created a reason to return.

**Fix:** The "energy_reset" session needs body scan cues: "Расслабь плечи", "Отпусти напряжение в челюсти", "Почувствуй стопы". Progressive, changing every 15 seconds. Something to follow.

### Overworked Employee (Day 1-3)

**Day 1:** Has a meltdown at work. Opens app. 7 seconds of splash while heart is racing. Selects "Перегрузка". Waits. Gets intensity picker. Too overwhelmed to care about dots. Auto-confirms. Sees "Стоп. Тишина." and a button. Taps "Стоп. Тишина." Session: 60 seconds of a circle. Breathing at 5s/5s. For someone in overload, 5-second inhales are TOO LONG. They can't hold focus for 5 seconds.

**Fix:** Overload sessions should start with FAST short breaths (2s/2s) and gradually slow down (2/2 → 3/3 → 4/4 → 5/5). Meet the user where they are, then guide them down.

---

## What Must Change in Code

1. Session breathing patterns must be phase-based and mood-specific
2. Session must show phase labels (Вдох / Задержка / Выдох) with proper 4-7-8 or box timing
3. Guidance text must change every 15 seconds during the session
4. High-urgency check-ins should fast-track to session
5. Returning user splash should be 3 seconds max
