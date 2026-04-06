# Aura — Visual System Audit

## PHASE 1: Visual System Reconstruction

### 1. Color System

| Token | Value | Role | Works? |
|-------|-------|------|--------|
| `bg` | #020108 | Near-black cosmic base | Yes — deep, premium |
| `surface` | #0A0A1A | Card/container fills | Yes — subtle lift |
| `surfaceLight` | #14142A | Elevated surfaces | Yes |
| `surfaceBorder` | #18FFFFFF (white 9%) | Subtle edge definition | Yes — barely visible, intentional |
| `primary` | #8B7FFF | Main accent — violet | Yes — distinctive, emotional |
| `primaryMuted` | #6E63E0 | Deeper violet | Underused |
| `accent` | #5CE1E6 | Cyan complement | Yes — creates violet-cyan identity |
| `warm` | #FFB156 | Amber — completion, reward | Yes |
| `rose` | #FF6B8A | Stress/emergency | Yes — emotional clarity |
| `green` | #56E09A | Calm/improvement | Yes |
| `text` | #F0ECF9 | Primary text — warm white | Yes — soft, not harsh |
| `textMuted` | #8A84A8 | Secondary text | Yes — ~7:1 contrast on bg |
| `textDim` | #6E6890 | Tertiary/labels | Borderline — ~5.5:1 after fix |
| `glowPrimary` | #508B7FFF (31% alpha) | Orb/button glow base | Works for shadows |
| `glowAccent` | #505CE1E6 | Accent glow | Works |
| `glowWarm` | #50FFB156 | Completion glow | Works |

**Assessment:** Strong palette. Violet-cyan-amber triad is distinctive and emotionally mapped. No color feels generic. The three text tiers (text/muted/dim) create clear hierarchy. Weakness: `primaryMuted` is defined but almost never used — missed opportunity for depth.

### 2. Gradient System

| Gradient | Colors | Usage | Premium? |
|---------|--------|-------|----------|
| `gradientPrimary` | #8B7FFF → #5CE1E6 (TL→BR) | CTA buttons, premium indicators | Yes — signature look |
| `gradientWarm` | #FFB156 → #FF6B8A (TL→BR) | Completion buttons, afterglow | Yes — warm reward feel |
| Cosmos radial (calm) | #1A374D → #406882 | CosmicBackground calm state | Yes — deep space |
| Cosmos radial (anxiety) | #0D1B2A → #1F2833 | CosmicBackground anxiety | Yes — cold tension |
| Orb SweepGradient | color → 0.7 → accent 0.4 → 0.7 → color | AuraPresence shimmer | Yes — alive, organic |
| Orb RadialGradient | color 0.55 → 0.25 → 0.08 | AuraPresence inner fill | Yes — soft depth |
| Bloom radial | bloomColor at low alpha → transparent | CosmicBackground center glow | Yes when subtle |

**Assessment:** Gradients are the app's strongest visual asset. The violet-cyan primary gradient is instantly recognizable. The cosmos gradient presets per mood are well-differentiated. No muddy or flat gradients.

### 3. Glow / Bloom / Light System

| Element | Blur | Alpha | Spread | Mood |
|---------|------|-------|--------|------|
| AuraPresence glow | 36-55px | 0.15-0.40 | 4-6px | Varies per PresenceState |
| AuraPresence outer halo | 80px | 0.08-0.12 | 20px | calming/silent only |
| CTA button glow | 30px | 0.25 | 0 | Constant subtle |
| CTA hover glow | 50px | 0.45 | 0 | Feedback |
| Cosmos bloom | screenWidth*0.7 | 0.01-0.2 | 0 | Mood-dependent |
| Cosmos vignette | screenSize*0.8 | 0.2-0.8 | 0 | Mood-dependent |
| Input focus glow | 28px | 0.15 | 0 | Accent color |
| Reality break orb glow | 50px | variable | 8px | Phase-dependent |

**Assessment:** Layered glow system is the second strongest visual asset. The combination of cosmos bloom + particle field + orb glow creates genuine depth. silentMode boost (+30% bloom, -40% vignette) is a clever touch. Weakness: some screens (session) have transparent centers on key elements (breath circle) that let background noise through.

### 4. Transparency / Blur / Glassmorphism

| Element | Blur σ | Fill alpha | Has BackdropFilter? |
|---------|--------|------------|---------------------|
| GlassCard | 24 | white 8% | Yes |
| Auth mode pill | 16 | white 5% | Yes |
| Auth buttons | 24 | white 8% | Yes |
| Auth inputs | — | white 4-7% | **No** |
| Mood chips (home) | — | white 5-6% | **No** |
| Mood chips (onboarding) | — | white 5% | **No** |
| Breath circle | — | — | No (border-only) |
| Top nav buttons | — | surface 50% | No |

**Inconsistency found:** GlassCard and auth buttons use BackdropFilter (true glassmorphism), but auth INPUTS do not. This creates a visual tier mismatch on the same screen — buttons look premium with depth, inputs look flat. Mood chips are also flat (no blur). This is the single biggest "cheap" signal in the app.

### 5. Typography System

| Role | Size | Weight | Color | Usage |
|------|------|--------|-------|-------|
| displayLarge | 40 | w300 | text | Splash title, huge headlines |
| displayMedium | 32 | w300 | text | Screen titles, emotional headings |
| headlineLarge | 24 | w600 | text | Section headers (unused?) |
| headlineMedium | 22 | w600 | text | Stat numbers |
| titleLarge | 18 | w600 | text | Card titles, nav titles |
| titleMedium | 16 | w500 | text | Sub-titles, settings labels |
| bodyLarge | 16 | w400 | text | Body text, presence text |
| bodyMedium | 14 | w400 | textMuted | Secondary descriptions |
| labelLarge | 16 | w600 | text | Button text |
| labelMedium | 14 | w500 | text | Chip labels |
| bodySmall | 12 | w400 | textDim | Captions, micro-copy |

**Assessment:** Clean hierarchy. The w300 for display sizes creates the "light premium" feel. Letter-spacing is intentional (-1.5 for display, -0.4 for headline). The weakness: bodySmall at 12px/w400 in textDim can be hard to read over animated backgrounds — especially breath count, cosmos labels, and "Пропустить" links.

### 6. Shape System

| Element | Radius | Notes |
|---------|--------|-------|
| Cards (GlassCard) | 16px (Radii.md) | Consistent |
| Primary buttons | 24px (Radii.lg) | Pill-shaped |
| Auth inputs | 20px | Slightly different from buttons (24) |
| Mood chips | 9999px (Radii.full) | Full pill |
| Auth mode tabs | 22px (inside 24px pill) | Inner pills |
| Top nav circles | circle | 40px diameter |
| Breath circle | circle | Border-only |
| Orb | circle | Gradient-filled |

**Assessment:** Consistent pill/circle language. The 16/24/full radius scale works. One inconsistency: auth inputs use r20 while buttons use r24 — subtle but creates slight visual misalignment when stacked.

### 7. Motion System

| Animation | Duration | Curve | Loop? |
|-----------|----------|-------|-------|
| Route: splash/onboarding | 1200ms | cubic(0.4,0,0.2,1) | No |
| Route: home | 1200ms | cubic(0.4,0,0.2,1) | No |
| Route: session | 500ms | cubic(0.16,1,0.3,1) scaleUp | No |
| Route: others | 400ms | cubic(0.16,1,0.3,1) slideUp | No |
| AuraPresence breath | 2000-6000ms | easeInOut | Yes |
| AuraPresence state transition | 800ms | easeOutCubic | No |
| AuraPresence pulse | 350ms | custom compress-release | No |
| Cosmos base | 20s | linear | Yes |
| Cosmos breath | mood-dependent | easeInOut | Yes |
| Cosmos mood transition | 700ms | lerp | No |
| Section reveal | 700ms | cubic(0.4,0,0.2,1) | No |
| CTA press | 120ms | ease | No |
| Onboarding scene switch | 500-700ms | easeOutCubic + slide | No |
| Afterglow phases | 2000+3000+2500ms | sequenced | No |
| Post-session glow | 30min decay | linear time function | No |

**Assessment:** Comprehensive motion vocabulary. The breathing animations at different speeds per PresenceState create emotional differentiation. Route transitions at 1200ms feel intentionally slow (immersive). Weakness: the 700ms cosmos mood transition doesn't sync with AuraPresence's 800ms state transition — 100ms gap could cause slight desynchronization between background and orb state changes.

### 8. Spacing System

4px grid: xs(4), sm(8), md(16), lg(24), xl(32), xxl(48), xxxl(64).

**Assessment:** Clean, consistent. Home screen uses proper spacing between sections. Profile card padding is consistent (md). The one area that feels cramped: afterglow phases — text, mood chips, contrast line, breath count, and button are close together on shorter screens.

---

## PHASE 2: Screen-by-Screen Visual Description

### Splash
Dark void → single violet light point blooms (6→24px) → particles expand from center → gradient emerges. Feels cinematic, premium. Duration: 2.6s for returning users, 8s for new. **Strongest screen visually.** No weakness.

### Onboarding / Auth
Emotion selection → AI response → auth options → email form. Background: reactive cosmos with typed particles. **Weakness:** Auth inputs are flat (no blur) on the same screen where auth buttons HAVE blur. The visual disparity makes inputs look cheaper. The 52px input height and r20 are fine, but the `white 4%` fill is barely visible against the dark cosmos — inputs can feel "lost."

### Home
Cosmos background + particle field + mood selector OR orb + presence text + action button. **Strong:** The cosmos reacts to mood selection. The AuraPresence orb creates genuine visual interest. **Weak:** The intensity dots (now 40px) are plain circles without visual weight — they feel like a prototype wireframe element. The "Готово" outline button is lighter than the main CosmicButton below the orb.

### Session / Breathing
Cosmos + breathing circle + phase label + guidance text + progress bar. **Strong:** The circle expanding/contracting with breath phases is the core experience. **Weak:** The circle has no fill — it's a border + shadow. Through the transparent center, particles and cosmos show, creating visual noise behind the "Вдох"/"Выдох" label. The progress bar at the bottom is 2px — borderline invisible.

### Afterglow
8-phase somatic experience. Orb + text phases + mood capture + contrast + breath count + return button. **Strong:** The phased reveal creates emotional pacing. Ghost layer dissolution on improvement. **Weak:** Dense stacking of information elements in phases 5-7.

### Profile
Back button + avatar circle + stats row + universe evolution + sync card + settings tiles. **Strong:** Evolution stage with named label ("Стабильность") is meaningful. **Weak:** The stats row (sessions/streak/minutes) uses small GlassCards that can feel cramped on narrow devices.

### Timeline
Summary stats + mood history list. **Strong:** Clean. **Weak:** No charts, no trends — just a chronological list of mood taps. Feels like a placeholder for a richer feature.

### Reality Break
45s cosmos transition: overload → calm. AuraPresence transitions through responding → supporting → calming. Phase text rotates. **Strong:** This is the most emotionally effective screen — the user watches the cosmos physically calm down. **Weak:** None significant.

### Paywall
Warm gradient cosmos + premium badge + feature list + CTA + restore link. **Strong:** Gradient warm button. **Weak:** The feature list is plain text with icons — standard paywall layout. No experiential element (the cosmos could be used to show what premium FEELS like, not just what it lists).

---

## PHASE 3: Visual Consistency Audit

### A. What is Working
- Violet-cyan-amber color triad is distinctive and emotionally mapped
- Cosmos background creates genuine depth and immersion
- Glow/bloom system with mood-reactive behavior
- Typography hierarchy (light weights for displays, medium for body)
- Route transitions at 1200ms create intentional pace
- Post-session glow decay over 30 minutes is invisible but felt
- Evolution stages give visual meaning to progress

### B. What is Inconsistent
- **Glassmorphism breaks at inputs:** Auth buttons have BackdropFilter, inputs do not. Same screen, different visual tiers.
- **Input radius (r20) vs button radius (r24):** Subtle but noticeable when stacked.
- **scaffoldBackgroundColor: Colors.black vs Cosmic.bg (#020108):** Most screens override it, but any that don't will show pure black instead of cosmic navy. A 1-pixel color difference that matters for edge cases.
- **Cosmos mood transition (700ms) vs AuraPresence state transition (800ms):** Background and orb change at slightly different speeds.
- **Session progress bar (2px) vs all other visual elements:** Disproportionately thin.

### C. What Feels Cheap
1. **Auth inputs** — flat translucent bars without blur. On a screen where everything else has depth (cosmos, particles, glass buttons), these look like they belong to a different app.
2. **Breath circle center** — transparent. Particles show through behind the phase label, creating visual noise.
3. **Intensity dots** — plain colored circles. No glow, no depth, no haptic visual cue.
4. **"Готово" button** — outline pill with primary 15% fill. Looks like a secondary action when it IS the action at that moment.
5. **Progress bar in session** — 2px thin. Invisible to most users.
6. **Timeline** — list of mood entries with no visualization. The "path" metaphor ("Путь") promises more than a list delivers.

---

## PHASE 4: Top 20 Visual Fixes

### 1. Add BackdropFilter to auth inputs
**Problem:** Inputs look flat while auth buttons are glass. **Why it hurts:** Breaks premium consistency on the most conversion-critical screen. **Fix:** Add `BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16))` wrapper in `_CosmicInput`. **File:** `onboarding_flow.dart` lines 910-953. **Priority:** HIGH

### 2. Add subtle fill to breath circle center
**Problem:** Transparent center shows particle noise behind phase label. **Why:** Label readability suffers during active breathing. **Fix:** Add a `Container` with `RadialGradient` fill inside the circle: session color at 8% alpha → transparent. **File:** `session_screen.dart` `_BreathCircle` widget. **Priority:** HIGH

### 3. Sync cosmos and orb transition durations
**Problem:** 700ms cosmos vs 800ms orb state change. **Why:** Background arrives before the orb settles — subtle desync. **Fix:** Change cosmos `_transCtrl` in `cosmic_background.dart` to 800ms. **File:** `cosmic_background.dart` line 64. **Priority:** MEDIUM

### 4. Increase session progress bar height
**Problem:** 2px is invisible. **Why:** Users don't know how much time is left. **Fix:** Increase to 4px, add subtle glow matching session color. **File:** `session_screen.dart` line 452. **Priority:** MEDIUM

### 5. Upgrade intensity dots with glow
**Problem:** Plain circles look wireframe-quality. **Fix:** Add `BoxShadow` with primary color at 15% alpha, blurRadius 8 when active. **File:** `home_screen.dart` lines 264-276. **Priority:** MEDIUM

### 6. Make "Готово" button use CosmicButton style
**Problem:** Outline pill looks secondary. **Fix:** Replace with a smaller `CosmicButton` or at minimum add gradient fill instead of outline. **File:** `home_screen.dart` lines 279-289. **Priority:** MEDIUM

### 7. Unify scaffoldBackgroundColor to Cosmic.bg
**Problem:** Pure black (#000000) vs cosmic navy (#020108). **Fix:** Change `app_theme.dart` line 7 to `Cosmic.bg`. **File:** `app_theme.dart`. **Priority:** LOW

### 8. Unify input radius to match buttons (r20 → r24)
**Problem:** Stacked inputs at r20 next to buttons at r24. **Fix:** Change `_CosmicInput` borderRadius from 20 to 24. **File:** `onboarding_flow.dart`. **Priority:** POLISH

### 9. Make auth error text use warm color instead of white
**Problem:** White text at 65% blends into background. **Fix:** Use `Cosmic.warm` at 80% alpha — warm errors feel caring, not clinical. **File:** `onboarding_flow.dart` line 673. **Priority:** POLISH

### 10. Add a subtle breathing animation to the splash text
**Problem:** "Aura" text is static while the orb breathes. **Fix:** Apply 2px vertical float synced with breath controller. Already exists in the spec but may not be wired. **File:** `splash_screen.dart`. **Priority:** POLISH

### 11-20: Additional Polish
11. Timeline needs at minimum a simple trend indicator (last 7 entries as colored dots)
12. Paywall could show a "preview" of the cosmos at a higher evolution level
13. Afterglow breath count could have a subtle glow ripple (already partially implemented)
14. Onboarding AI response orb (16px) is very small — could be 20px
15. Profile avatar gradient circle could pulse subtly
16. Mood chips could have a subtle glow on the home screen (like onboarding chips do)
17. Session guidance text AnimatedSwitcher could use a slight blur→sharp transition
18. The "Изменилось состояние?" link is in textDim — could be textMuted for discoverability
19. Reality break "Лучше." screen could match the green of the improvement afterglow
20. Post-session return button could have the closure compression animation from afterglow

---

## PHASE 5: Priority Redesign Notes

### Auth
- **Keep:** Cosmos background, glass auth buttons, mode pill switcher, emotional copy
- **Remove:** Nothing
- **Restyle:** Add BackdropFilter to inputs. Unify radius to r24. Error text in warm color.
- **Simplify:** Nothing needed — 3 options + email form is clean
- **Strengthen:** Input focus state could be more dramatic (glow blur 28→40)

### Home
- **Keep:** Cosmos + particles + AuraPresence + mood selector + action button
- **Remove:** Nothing
- **Restyle:** Intensity dots need glow. "Готово" needs gradient fill. Mood chips could match onboarding style (with border glow on breath).
- **Simplify:** Auto-confirm timer (2.5s) could confuse — consider removing or extending to 4s
- **Strengthen:** The transition from mood selector to orb view needs a coordinated animation moment (currently just a state swap)

### Session
- **Keep:** Breath circle + phase labels + guidance rotation + progress
- **Remove:** Nothing
- **Restyle:** Circle needs subtle center fill. Progress bar needs to be 4px with glow. Label weight already fixed to w300.
- **Simplify:** Nothing — the breathing system is clean
- **Strengthen:** The 800ms static "Приготовься" at session start could show a subtle countdown or breathing cue

---

## PHASE 6: Final Verdict

**Current visual quality: 7.5/10**

**What makes the app already strong:**
- The cosmos visual system is genuinely distinctive — no other meditation app looks like this
- The violet-cyan-amber palette has strong emotional mapping
- The glow/bloom system creates real depth
- Post-session glow decay is invisible genius — users feel it without knowing why
- Evolution stages with named meanings are premium product thinking

**What prevents it from feeling world-class:**
1. Auth inputs without blur (cheap on the conversion screen)
2. Breath circle transparent center (noise behind the most important element)
3. Intensity dots look wireframed
4. Some text (bodySmall/textDim) is at the edge of readability over animated backgrounds
5. Timeline is a placeholder, not a feature

**Current tier: Polished indie app, approaching premium product.**
Not yet category leader. The concept IS category-leader level. The execution is 70% there.

**5 fixes that create the biggest quality jump:**
1. Blur on auth inputs (kills the #1 "cheap" signal)
2. Breath circle center fill (fixes the core experience visual)
3. Intensity dots with glow (removes wireframe feeling from home)
4. Session progress bar thicker + glowing (makes session feel tracked)
5. Cosmos/orb transition sync (800ms both — eliminates the subtle desync)

These 5 changes would move the score from 7.5 to 8.5-9.0.
