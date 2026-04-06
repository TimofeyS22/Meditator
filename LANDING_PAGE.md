# Aura — Landing Page (Optimized v2)

## Conversion Audit — What Changed

### 1. Hero: question → promise
**Before:** "Стало плохо? Стань спокойнее за 60 секунд."
**After:** "Спокойствие за 60 секунд"
**Why:** Questions create defensiveness. Promises create desire. The user should feel pulled, not confronted.

### 2. Subheadline: explanation → sensation
**Before:** "Aura чувствует твоё состояние и помогает прийти в себя."
**After:** "Одно нажатие. Одна минута дыхания. И внутри — тише."
**Why:** The original explained the product. The new version describes what the user FEELS. Sensation converts better than explanation.

### 3. Removed technique jargon
**Before:** "4-7-8 при тревоге. Бокс-дыхание при перегрузке."
**After:** "Aura подбирает ритм дыхания под твоё состояние."
**Why:** Nobody searches for "4-7-8 breathing" in a panic. The user cares that it works, not what it's called.

### 4. Added urgency injections (2 placements)
**After problem section:** "Прямо сейчас кто-то открыл Aura. Через 60 секунд ему станет легче."
**After testimonials:** "Ты сейчас чувствуешь что-то. Aura может помочь за 60 секунд."
**Why:** These create "I need this NOW" spikes that interrupt passive scrolling and drive CTA clicks.

### 5. Before/After: table → visual grid
**Before:** Markdown table
**After:** Color-coded grid: left cells rose-tinted (pain), right cells green-tinted (relief)
**Why:** Color = emotion. Tables = spreadsheets. The grid makes transformation feel visual, not logical.

### 6. Before/After headers: "До/После" → "Сейчас/Через 60 секунд"
**Why:** "До и после" is abstract. "Сейчас → через 60 секунд" is urgent and specific.

### 7. Pricing: feature list → emotional anchor
**Before:** "Расширенная вселенная... ИИ-компаньон... 6 типов сессий..."
**After:** "299₽/мес. Меньше, чем один кофе. Больше, чем минута спокойствия."
**Why:** The old version sold features to rational brain. The new version sells value relative to something the user already spends on (coffee).

### 8. Social proof title → result-driven
**Before:** "Они уже чувствуют разницу"
**After:** "60 секунд. Реальный результат."
**Why:** "Они чувствуют разницу" is about them. "Реальный результат" is about what you'll get.

---

## Implementation

The complete HTML landing page is at `landing/index.html`. Single file, no dependencies beyond Google Fonts (Inter). Dark cosmos palette from the app. Responsive. Mobile-first.

Key design decisions:
- Breathing orb in hero (CSS animation, no JS)
- Problem section as a list, not paragraphs (scannable)
- Two urgency sections break the page into emotional peaks
- No phone mockups, no screenshots — just the cosmos aesthetic
- Sticky CTAs on mobile via scroll-to-pricing anchors
- Before/After as a color-coded grid, not a table
- Price card with coffee comparison as emotional anchor
- Final section mirrors hero (orb returns, slightly larger) — closure
