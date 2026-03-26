

Ты — senior Flutter-разработчик и UI/UX дизайнер уровня Apple Design Awards. Твоя задача — переработать фронтенд Flutter-приложения «Meditator» (медитация и ментальное здоровье) до уровня лучшего дизайна в App Store. Каждое изменение должно быть реализовано в коде. Никаких заглушек, TODO, placeholder'ов — только готовый production-код.

---

### КОНТЕКСТ ПРОЕКТА

**Стек:** Flutter (Dart SDK ^3.11.3), Material 3, go_router, flutter_animate, just_audio, supabase_flutter, google_fonts (Inter), flutter_riverpod, flutter_svg, shimmer, cached_network_image.

**Структура lib/:**
```
lib/
├── app/
│   ├── main.dart          — точка входа, ProviderScope, MeditatorApp
│   ├── theme.dart         — дизайн-система: C (цвета), S (отступы), R (радиусы), AppTheme.dark
│   ├── router.dart        — GoRouter, 12+ маршрутов
│   └── shell.dart         — AppShell с нижним навбаром (5 табов)
├── core/
│   ├── api/backend.dart   — Backend (Supabase Edge Functions)
│   ├── auth/auth_service.dart
│   ├── audio/audio_service.dart
│   ├── config/env.dart
│   ├── database/db.dart
│   └── providers/providers.dart
├── features/
│   ├── home/              — HomeScreen + widgets/ (AuraCard, StatsRow, QuickActions)
│   ├── onboarding/        — OnboardingScreen + pages/ (Welcome, Goals, Stress, Prefs, Finish)
│   ├── meditation/        — MeditationPlayerScreen, LibraryScreen, widgets/meditation_tile
│   ├── ai_companion/      — AuraScreen (чат с AI)
│   ├── mood_journal/      — JournalScreen, NewEntryScreen, AnalyticsScreen
│   ├── garden/            — GardenScreen (виртуальный сад)
│   ├── breathing/         — BreathingListScreen, BreathingSessionScreen
│   ├── pair/              — PairScreen, FindPartnerScreen
│   ├── profile/           — ProfileScreen, SettingsScreen
│   └── subscription/      — PaywallScreen
└── shared/
    ├── widgets/           — GlassCard, GlowButton, GradientBg, BreathingRing, ProgressArc, EmotionChip
    └── models/            — Meditation, MoodEntry, GardenPlant, Breathing, UserProfile, Pair
```

**Текущая дизайн-система (theme.dart):**
- Цвета: bg=#0A0D1B, surface=#12162A, surfaceLight=#1A1F38, primary=#7C5CFC, accent=#36D6B5, gold=#F5A623, rose=#FF6B8A
- Эмоции: calm=#5AAEFF, happy=#FFD166, anxious=#FC7676, sad=#7B8CDE, energy=#FF8A5C, grateful=#42C6A4
- Градиенты: gradientPrimary (purple→teal), gradientNight (dark→darker), gradientSunset (purple→coral→gold), gradientGold
- Отступы: xs=4, s=8, m=16, l=24, xl=32, xxl=48
- Радиусы: s=8, m=12, l=16, xl=24, full=999
- Шрифт: Google Fonts Inter, единственная тёмная тема

**Текущие проблемы дизайна:**
- GlassCard использует Color.black с alpha 0.7 вместо настоящего glassmorphism (BackdropFilter)
- GradientBg — просто DecoratedBox с gradientNight, нет глубины и атмосферы
- GlowButton не имеет реального glow-эффекта (нет boxShadow с анимацией)
- Навбар (shell.dart) — простые иконки и текст, без анимации переключения, без индикатора
- Анимации однотипные: fadeIn + slideY/slideX с flutter_animate, нет уникальных паттернов
- Нет haptic feedback
- Нет кастомных page transitions в GoRouter
- Нет skeleton loading (shimmer подключён но не используется)
- Плеер медитации — просто ProgressArc + кнопки, нет иммерсивности
- Сад — цветные точки на звёздном фоне, нет визуального WOW
- Breathing ring — простой круг с gradient, нет particle-эффектов
- Онбординг — стандартный PageView без запоминающейся анимации

---

### ФИЛОСОФИЯ ДИЗАЙНА

Название: **«Celestial Calm»** — дизайн-язык, вдохновлённый космосом, ночным небом, авророй и биолюминесценцией. Каждый экран — ощущение медитации внутри звёздного пространства.

Ключевые принципы:
1. **Organic motion** — все анимации биоморфные, плавные, дышащие. Ничего резкого.
2. **Layered depth** — 3+ слоя глубины на каждом экране (фон → средний слой → контент → эффекты)
3. **Living UI** — интерфейс «дышит» — фоновые gradient-анимации, медленные particle-системы, subtle glow-пульсации
4. **Haptic poetry** — каждый тап, свайп, milestone сопровождается осмысленной вибрацией (HapticFeedback.lightImpact для tap, mediumImpact для переключений, heavyImpact для достижений)
5. **Progressive reveal** — контент появляется каскадом, stagger-анимации при каждом входе на экран
6. **Sensory delight** — неожиданные micro-details, которые пользователь замечает на 10-й раз использования

---

### ЭТАП 1: ДИЗАЙН-СИСТЕМА (theme.dart + новые файлы)

#### 1.1 Расширение theme.dart

Добавь в класс `C`:
```dart
// Новые цвета для глубины
static const bgDeep = Color(0xFF060818);
static const surfaceGlass = Color(0x1AFFFFFF); // 10% white
static const surfaceBorder = Color(0x12FFFFFF); // 7% white
static const shimmerBase = Color(0xFF1A1F38);
static const shimmerHighlight = Color(0xFF252B45);

// Aurora градиенты
static const gradientAurora = LinearGradient(
  colors: [Color(0xFF7C5CFC), Color(0xFF36D6B5), Color(0xFF5AAEFF)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

static const gradientMystic = RadialGradient(
  colors: [Color(0x357C5CFC), Color(0x00000000)],
  radius: 0.8,
);

// Glow colors (для boxShadow анимаций)
static const glowPrimary = Color(0x407C5CFC);
static const glowAccent = Color(0x4036D6B5);
static const glowRose = Color(0x40FF6B8A);
```

Добавь новый класс `Anim` для стандартизации длительностей:
```dart
abstract class Anim {
  static const fast = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 350);
  static const slow = Duration(milliseconds: 500);
  static const dramatic = Duration(milliseconds: 800);
  static const breathe = Duration(milliseconds: 4000);
  static const curve = Curves.easeOutCubic;
  static const curveElastic = Curves.elasticOut;
  static const curveSpring = Curves.easeOutBack;
}
```

#### 1.2 Типографика

Замени Inter на **пару шрифтов**:
- Заголовки (display, headline): **DM Serif Display** или **Playfair Display** — элегантный serif для заголовков, создаёт ощущение premium-приложения
- Тело текста (body, label, title): **Inter** — оставить для читаемости

В `AppTheme.dark`:
```dart
textTheme: base.textTheme.copyWith(
  displayLarge: GoogleFonts.dmSerifDisplay(fontSize: 34, fontWeight: FontWeight.w400, color: C.text, letterSpacing: -0.5),
  displayMedium: GoogleFonts.dmSerifDisplay(fontSize: 28, fontWeight: FontWeight.w400, color: C.text, letterSpacing: -0.3),
  headlineLarge: GoogleFonts.dmSerifDisplay(fontSize: 24, fontWeight: FontWeight.w400, color: C.text),
  headlineMedium: GoogleFonts.dmSerifDisplay(fontSize: 20, fontWeight: FontWeight.w400, color: C.text),
  // остальное — Inter (как сейчас)
),
```

---

### ЭТАП 2: SHARED WIDGETS — ПЕРЕРАБОТКА И НОВЫЕ

#### 2.1 GlassCard → настоящий glassmorphism

Полностью переписать с `BackdropFilter` + `ImageFilter.blur`:
```dart
class GlassCard extends StatelessWidget {
  // ... существующие параметры +
  final double blur;       // default 12
  final double opacity;    // default 0.08
  final bool showGlow;     // default false
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(R.l),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(R.l),
            border: Border.all(color: C.surfaceBorder, width: 0.5),
            // Если showGlow — добавить boxShadow с glowColor
          ),
          // ... child
        ),
      ),
    );
  }
}
```

#### 2.2 GlowButton → реальный анимированный glow

Добавь:
- Анимированный `boxShadow` (пульсирующий glow через AnimationController с repeat)
- Shimmer-эффект по поверхности при первом появлении (gradient animation слева направо по кнопке один раз)
- Haptic feedback: `HapticFeedback.lightImpact()` при нажатии
- Масштаб при нажатии: текущий scale 0.96, сделать 0.97 + пружинящий bounce-back через `Curves.elasticOut`

#### 2.3 GradientBg → Animated Living Background

Полностью переписать:
- Медленно анимируемый mesh gradient (2-3 градиентных пятна, которые медленно дрейфуют за 15-20 секунд через AnimationController с repeat)
- Опциональные particle-звёзды (тонкие точки с мерцанием) — CustomPainter, 40-80 частиц с разной opacity, медленно пульсирующих
- Опциональный aurora-эффект (волнистый градиент сверху, медленно плавающий)
- Всё это — на RepaintBoundary для производительности
- Параметры: `showStars: bool`, `showAurora: bool`, `intensity: double` (0.0-1.0)

#### 2.4 BreathingRing → Celestial Breathing Orb

Переписать визуал:
- Вместо простого круга с gradient — многослойный orb:
  - Внутренний слой: blur gradient circle
  - Средний слой: 2-3 концентрических кольца с разной opacity, вращающихся в разные стороны (Transform.rotate с AnimationController)
  - Внешний слой: particle-лучи (12-16 тонких линий от центра, с пульсирующей длиной)
  - Glow: BoxShadow который масштабируется вместе с кругом
- При вдохе — кольцо расширяется + тёплые цвета (primary → gold)
- При задержке — кольцо стабильно + нейтральные цвета
- При выдохе — кольцо сжимается + холодные цвета (accent → calm)
- Particle-dust вокруг orb (20-30 точек, летающих по Lissajous-кривым)

#### 2.5 ProgressArc → Живая арка

Добавить:
- Анимированный gradient endpoint (точка-caps на конце арки, которая пульсирует)
- Мелкие particle-искры от конца арки (5-8 частиц, разлетающихся при движении)
- Внутренний subtle glow по центру (RadialGradient от primary с alpha 0.05)

#### 2.6 НОВЫЙ ВИДЖЕТ: AnimatedNumber

Для всех чисел в UI (минуты, streak, кол-во сессий):
```dart
class AnimatedNumber extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration; // default 600ms
  // Использует TweenAnimationBuilder<int> с Curves.easeOutCubic
  // При изменении числа — плавно считает от старого к новому значению
}
```

#### 2.7 НОВЫЙ ВИДЖЕТ: ShimmerLoading

Стандартизированный skeleton loading (пакет shimmer уже подключён):
```dart
class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  // Shimmer с C.shimmerBase и C.shimmerHighlight
  // Скруглённые углы, пульсирующий gradient
}
```

#### 2.8 НОВЫЙ ВИДЖЕТ: MorphingBlob

Анимированная форма для фоновых элементов (сад, плеер, дыхание):
```dart
class MorphingBlob extends StatefulWidget {
  final double size;
  final Color color;
  final Duration period; // скорость морфинга
  // CustomPainter + AnimationController
  // 6-8 точек Bézier-кривой, которые медленно меняют позицию
  // Создаёт эффект «живой» органической формы
}
```

#### 2.9 НОВЫЙ ВИДЖЕТ: ParticleField

Поле частиц для фонов:
```dart
class ParticleField extends StatefulWidget {
  final int count;        // кол-во частиц
  final double maxRadius; // макс размер точки
  final Color color;
  final bool twinkle;     // мерцание
  // CustomPainter + Ticker
  // Каждая частица: случайная позиция, случайная opacity, медленное мерцание через sin()
}
```

---

### ЭТАП 3: НАВИГАЦИЯ И ПЕРЕХОДЫ

#### 3.1 Кастомные page transitions в GoRouter

Для каждого типа перехода:

**Tab-to-tab (внутри ShellRoute):** fade crossfade 300ms
```dart
GoRoute(
  path: '/home',
  pageBuilder: (_, __) => CustomTransitionPage(
    child: const HomeScreen(),
    transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    transitionDuration: Anim.normal,
  ),
),
```

**Push-экраны (плеер, библиотека, Aura):** slide up + fade с custom curve
```dart
transitionsBuilder: (_, anim, __, child) {
  final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
  return SlideTransition(
    position: Tween(begin: Offset(0, 0.08), end: Offset.zero).animate(curved),
    child: FadeTransition(opacity: curved, child: child),
  );
},
```

**Модальные экраны (настройки, paywall):** slide from bottom + blur behind

#### 3.2 Навбар (shell.dart) → Premium Tab Bar

Полностью переписать `AppShell`:
- Заменить обычные иконки на custom tab indicators
- Активный таб: иконка с gradient fill (ShaderMask + C.gradientPrimary), текст с тем же градиентом, пульсирующий glow-dot под иконкой (3px круг)
- Неактивный таб: outline-иконка, C.textDim
- При переключении: плавная анимация (300ms) — иконка scales up 1.0→1.15→1.0 (Curves.elasticOut), glow-dot появляется через fadeIn + scaleIn
- HapticFeedback.selectionClick() при каждом тапе
- Фон навбара: GlassCard (blur: 20, opacity: 0.12) вместо Container с color
- Padding-bottom: учитывать SafeArea.bottom для всех устройств

---

### ЭТАП 4: КАЖДЫЙ ЭКРАН — ДЕТАЛЬНАЯ ПЕРЕРАБОТКА

#### 4.1 ONBOARDING (onboarding_screen.dart + pages/)

**Welcome Page:**
- Фон: ParticleField (60 звёзд, twinkle: true) + MorphingBlob в центре (размер ~300, C.primary с alpha 0.15)
- Заголовок "Meditator" — DM Serif Display, 42px, letterSpacing: -1. Появление: каждая буква фадится по отдельности (stagger 40ms). Используй `flutter_animate` с `.shimmer()` после полного появления
- Подзаголовок — fadeIn с задержкой 400ms от начала
- Кнопка «Начать» — GlowButton с showGlow: true
- Аватар AI "Aura" — MorphingBlob (80px) с gradient + иконка/буква "A" в центре, медленно пульсирует

**Goals Page:**
- Каждая цель — GlassCard с иконкой-emoji слева и текстом
- При выборе: карточка плавно обводится gradient-border (AnimatedContainer, border transitions 300ms), внутри — subtle gradient overlay. Haptic selectionClick.
- Stagger-появление карточек: каждая с задержкой 50ms
- Фон: subtle aurora-wave сверху

**Stress Page:**
- Визуальный stress-indicator: вместо обычных вариантов — горизонтальный slider или 4 круга, каждый со своим цветом и анимированным orb внутри
- При выборе уровня стресса — цвет фона плавно меняется (AnimatedContainer 500ms):
  - Низкий → accent/teal glow
  - Средний → primary/purple glow
  - Высокий → rose/coral glow
  - Очень высокий → anxious/red glow

**Prefs Page:**
- Сегментированные выборы (голос, длительность, время) — кастомные chips с gradient-border при выборе
- Animated transitions между выборами

**Finish Page:**
- Поля ввода: при фокусе — border анимируется gradient (gradient border technique через Container с gradient + внутренний Container с bg)
- Кнопка создания аккаунта — увеличенный GlowButton, пульсирующий glow усиливается
- Опция «Пропустить» — subtle, не конкурирует визуально

**Page Indicator (внизу):**
- Текущий индикатор — не просто stretched dot, а pill с анимированным gradient fill (gradient движется внутри pill)
- Переход между страницами: dot ↔ pill морфинг (AnimatedContainer уже есть, добавить gradient fill)

#### 4.2 HOME SCREEN

**Приветствие:**
- «Доброе утро, [имя]» — DM Serif Display, 28px
- Тонкий ambient glow за текстом (positioned Container с RadialGradient, C.primary alpha 0.08, blur 40px)

**Aura Card (aura_card.dart) — главный визуальный якорь:**
- Фон карточки: GlassCard с blur 15 + gradient border (текущий gradient border оставить, он хорош)
- Добавить: маленький MorphingBlob (40px) рядом с надписью «Aura рекомендует» как живой AI-индикатор
- Кнопка Play:
  - При idle: кнопка пульсирует (scale 1.0→1.03→1.0 за 2 секунды, repeat)
  - Вокруг кнопки — 2-3 концентрических ring-pulse анимации (как radar pulse): кольца расходятся от кнопки с увеличением scale и уменьшением opacity, stagger 600ms
  - При тапе: haptic mediumImpact + scale down bounce
- Loading state: заменить CircularProgressIndicator на кастомный — 3 MorphingBlob'а (маленьких), плавающих в центре

**Stats Row (stats_row.dart):**
- Каждая статистика — GlassCard с AnimatedNumber для значений
- При первом появлении: числа «считают» от 0 до реального значения за 800ms
- Иконки слева от каждой стат — с gradient fill (ShaderMask)

**Quick Actions (quick_actions.dart):**
- Горизонтальный scroll (ListView.builder с horizontal) карточек действий
- Каждая карточка: GlassCard 120x140, иконка сверху (крупная, 32px, с gradient), название снизу
- При наведении (hover/longPress): карточка поднимается (translateY -4px) + усиливается glow + haptic lightImpact
- Stagger-появление: каждая карточка с задержкой 60ms

**Весь экран:**
- RefreshIndicator: изменить на кастомный — MorphingBlob сверху, который растягивается при pull

#### 4.3 MEDITATION PLAYER SCREEN — САМЫЙ ИММЕРСИВНЫЙ ЭКРАН

Этот экран должен быть шедевром. Пользователь проводит здесь больше всего времени.

**Фон:**
- Полноэкранный animated gradient background:
  - 3-4 MorphingBlob'а разного размера (200-400px), расположенных по экрану
  - Цвет зависит от категории медитации (sleep→calm/blue, stress→primary/purple, morning→gold/warm)
  - Блобы медленно дрейфуют (period: 15-25 секунд)
- ParticleField поверх (30 частиц, очень subtle, twinkle: true)
- Всё на RepaintBoundary

**ProgressArc (центр экрана):**
- Увеличить до 280-300px
- Добавить второе внешнее кольцо (thin ring, 1px, alpha 0.2) которое вращается (1 оборот за 60 секунд)
- Добавить particle-искры на конце прогресс-арки
- Время по центру: AnimatedNumber, monospace (tabularFigures уже есть), размер 36px
- Под временем: progress в процентах (маленький текст, C.textDim)

**Элементы управления:**
- Play/Pause: большая (72px) круглая кнопка с gradient + animated glow ring
- При play: иконка play → pause с AnimatedSwitcher (morphing transition)
- При pause: glow ring пульсирует медленнее (как «дыхание»)
- Stop: уменьшенная (48px), опасный цвет, при тапе — confirmation с тонкой bottom sheet

**Ambient Sound Picker:**
- Заменить ChoiceChip на кастомные horizontal scroll pills:
  - Каждый pill: иконка-emoji + название
  - Выбранный: gradient border + subtle glow + animated wave внутри (2-3px высоты waveform)
  - При переключении: плавный crossfade фонового ambient (не резкий switch)

**Volume Slider:**
- Кастомный slider (CustomPainter):
  - Track: gradient от transparent к accent
  - Thumb: circle с glow
  - При drag: haptic lightImpact на каждые 10% изменения

**Completion Dialog:**
- Заменить AlertDialog на full-screen overlay:
  - Фон: blur background + confetti/particle burst
  - Большое число «+N минут» — AnimatedNumber от 0
  - Achievement text с DM Serif Display
  - 2 кнопки: GlowButton «К саду» (primary) и TextButton «Закрыть» (subtle)

#### 4.4 AURA SCREEN (AI Companion Chat)

**Аватар Aura:**
- Заменить Container с буквой "A" на:
  - MorphingBlob (40px) с gradient fill
  - Внутри — буква "A" или AI-иконка
  - Пульсирует когда Aura «думает»

**Сообщения:**
- Aura messages: GlassCard стиль, rounded. При появлении — typing indicator (текущий _TypingDots хорош, но добавить:) + потом текст появляется посимвольно (typewriter effect, 20ms на символ)
- User messages: gradient background (C.gradientPrimary), rounded. Появление — slideIn from right + fadeIn
- Между сообщениями — плавные stagger delays

**Emotion Chips (внизу):**
- При тапе: chip «отлетает» вверх и превращается в сообщение (hero-like animation)
- Выбранный chip: pulse + gradient border

**Input Field:**
- При фокусе: gradient bottom border animation (слева направо, 300ms)
- Send button: rotate 45° при нажатии + scale bounce

**Кнопка «Создать медитацию»:**
- Особая анимация: gradient shimmer проходит по кнопке каждые 3 секунды (attention-grabber)
- При загрузке: MorphingBlob spinner вместо CircularProgressIndicator

#### 4.5 BREATHING SESSION SCREEN

**Общий визуал:**
- Фон: тёмный с subtle aurora-wave сверху, интенсивность aurora меняется с дыханием
- ParticleField с 40 частицами, которые движутся в ритм дыхания (при вдохе — частицы тянутся к центру, при выдохе — разлетаются)

**BreathingRing (центр):**
- Полностью переработанный Celestial Breathing Orb (описан в ЭТАП 2)
- Дополнительно: под orb — тень, которая масштабируется вместе с ним (simulated elevation)
- Текст фазы ("Вдох", "Задержка", "Выдох") — AnimatedSwitcher с fade + slideY при смене

**Cycle Counter:**
- Визуальный: N маленьких dots-кругов в ряд, заполненные — с gradient, пустые — outline
- При завершении цикла: dot заполняется с pulse-анимацией + haptic mediumImpact

**Кнопка Start/Pause:**
- GlowButton с меняющимся glow-цветом:
  - Start → accent glow
  - Running (Pause) → primary glow, пульсирует

**Completion Screen (_buildDone):**
- Большая check-mark анимация (animated SVG path drawing или Lottie-like through CustomPainter)
- Particle burst от центра
- Текст «Ты сделал это» — DM Serif Display, fadeIn + scale
- Stats: длительность, циклы — AnimatedNumber
- Haptic: heavyImpact при завершении

#### 4.6 GARDEN SCREEN

Самая визуально уникальная фича. Сад должен выглядеть как маленькая живая вселенная.

**Фон:**
- _StarryPainter — оставить, но УЛУЧШИТЬ:
  - Звёзды мерцают (sin-wave opacity per star, каждая со случайным phase offset)
  - Добавить 2-3 «falling star» анимации (тонкая линия, пролетает раз в 10-15 секунд)
  - Subtle nebula glow (1-2 RadialGradient пятна, очень dim, медленно дрейфуют)

**Растения (_PlantDot):**
- Заменить простые цветные круги на:
  - Seed: маленький (16px) мерцающий dot
  - Sprout: dot (24px) + тонкие «усики» вверх (CustomPainter, 2 линии)
  - Growing: MorphingBlob (36px) + glow кольцо
  - Blooming: MorphingBlob (48px) + particle-sparkles вокруг (4-6 частиц) + яркий glow
- При тапе на растение: scale bounce + haptic + bottom sheet с детальной инфой
- Увядшие растения: desaturated + медленное покачивание (rotation ±2°)

**Plant Picker (bottom sheet):**
- Каждое растение: GlassCard с визуальным preview (MorphingBlob нужного цвета + стадии bloom)
- Premium badge: animated gradient shimmer

**Stats Chips (вверху):**
- AnimatedNumber для всех значений
- Иконки с gradient

**FAB «Посадить»:**
- GlowButton-стиль вместо FloatingActionButton
- Pulsating glow когда сад пуст (attention-grabber)

#### 4.7 JOURNAL SCREEN

**Записи настроения:**
- Каждая запись — GlassCard с:
  - Цветной полоской слева (3px, цвет эмоции)
  - Emoji эмоции (крупный, 28px)
  - Текст записи (truncated, 2 lines)
  - Дата (C.textDim, bodySmall)
- Stagger-появление: 40ms delay на каждую

**Empty State:**
- Крупный MorphingBlob (120px) с иконкой журнала внутри
- Текст «Начни вести дневник» — DM Serif Display
- Кнопка «Новая запись» — GlowButton

**Кнопка новой записи (FAB или верхняя):**
- Gradient + glow
- При long-press: показать tooltip «Записать настроение»

#### 4.8 NEW ENTRY SCREEN (Журнал — новая запись)

**Emotion Selection:**
- EmotionChip — увеличить до 2-column grid
- Каждый chip: при выборе — фон плавно заливается цветом эмоции (AnimatedContainer 300ms), появляется check-icon, haptic selectionClick
- Фон экрана: subtle color wash в цвет выбранной эмоции (AnimatedContainer на всём Scaffold)

**Text Input:**
- Большое поле: minLines 5, hint text поэтичный
- При фокусе: gradient border animation

**Интенсивность:**
- Кастомный slider: 5 уровней, визуал — от маленького к большому кругу (dot progression)
- Цвет slider — в цвет выбранной эмоции

#### 4.9 ANALYTICS SCREEN (Журнал — аналитика)

**Графики:**
- Кастомные (CustomPainter), не сторонняя библиотека:
  - Weekly mood chart: 7 столбиков (bar chart), цвет = доминирующая эмоция дня, высота = интенсивность
  - Bars появляются с stagger-анимацией (grow up от 0 к реальной высоте)
  - Emotion distribution: горизонтальные bar'ы по эмоциям, gradient fill

**Insights от Aura:**
- GlassCard с gradient border
- MorphingBlob avatar Aura (маленький) + текст инсайта

#### 4.10 BREATHING LIST SCREEN

**Список упражнений:**
- Каждое — GlassCard с:
  - Небольшой BreathingRing preview (60px, не анимированный — static scale)
  - Название, описание, длительность
  - Цветная метка сложности
- Stagger appearance

**Категории/фильтры:**
- Horizontal scroll chips сверху (если будут категории)

#### 4.11 LIBRARY SCREEN

**Карточки медитаций:**
- GlassCard с:
  - Gradient overlay внизу (для читаемости текста на фоне)
  - Emoji категории (крупный, в углу)
  - Длительность badge (pill, C.surfaceLight)
  - Premium badge (gradient gold shimmer)
- Grid layout: 2 колонки
- Stagger appearance: каждая карточка с задержкой

**Search/Filter:**
- Animated search bar: при тапе — расширяется из иконки в полноценное поле (AnimatedContainer width transition)

#### 4.12 PROFILE SCREEN

**Header:**
- Avatar: крупный (80px) MorphingBlob с gradient + инициалы/фото
- Имя — DM Serif Display
- Subtitle (email или статус) — bodyMedium, C.textSec

**Статистики:**
- Ряд из 3 GlassCard: streak, total sessions, total minutes
- AnimatedNumber для всех
- Streak: если > 7, показать flame emoji + gradient glow card

**Меню:**
- Grouped GlassCard sections:
  - Каждый пункт — ListTile-подобный, с иконкой (gradient), текстом, chevron
  - Divider между пунктами — subtle, C.surfaceBorder

#### 4.13 PAYWALL SCREEN

**Критически важный экран для монетизации.**

**Фон:**
- Animated aurora gradient (яркий, привлекательный)
- ParticleField с gold-colored particles

**Header:**
- Крупный текст «Meditator Premium» — DM Serif Display, gradient text (ShaderMask)
- Subtitle — что пользователь получит

**Feature List:**
- Каждая фича — Row с:
  - Gradient checkmark иконка
  - Описание
- Stagger appearance

**Pricing Cards:**
- 2-3 варианта подписки
- «Лучшее предложение» — card с gradient border + shimmer badge
- При выборе: card поднимается (scale 1.02) + glow усиливается

**CTA Button:**
- Самый заметный GlowButton на всём экране
- Постоянный shimmer + pulsating glow
- Текст с ценой

**Money-back / Trial info:**
- Subtle, внизу, но читаемый

#### 4.14 PAIR SCREEN и FIND PARTNER SCREEN

**Pair Screen (если есть партнёр):**
- 2 аватара (MorphingBlob) соединены анимированной линией (CustomPainter, gradient path)
- Совместная статистика — GlassCard
- Возможность отправить «nudge» — кнопка с bounce-анимацией

**Find Partner Screen:**
- Invite-link flow
- Код приглашения: крупный, monospace, copyable с ripple-эффектом при копировании

#### 4.15 SETTINGS SCREEN

- Grouped sections в GlassCard
- Toggle switches: кастомные с gradient track при включении
- Destructive actions (удалить аккаунт) — red-tinted card с warning

---

### ЭТАП 5: MICRO-INTERACTIONS КАТАЛОГ

Каждая из этих микро-интеракций должна быть реализована:

| Действие | Анимация | Haptic |
|----------|----------|--------|
| Tap любой кнопки | scale 0.97→1.0, 120ms, elasticOut | lightImpact |
| Tap tab в навбаре | icon scale 1.15→1.0 + glow dot appear | selectionClick |
| Pull-to-refresh | MorphingBlob stretch | - |
| Scroll snap | momentum bounce (physics: BouncingScrollPhysics) | - |
| Achievement/milestone | particle burst + glow pulse | heavyImpact |
| Error | shake animation (3 cycles, ±4px) | heavyImpact |
| Toggle on | track fills with gradient, thumb slides | lightImpact |
| Long-press card | scale 1.02 + glow intensify | mediumImpact |
| Swipe-to-dismiss | fade + slideX + scale down | - |
| Text field focus | gradient border animate in | - |
| Page transition (push) | slide up 8% + fade | - |
| Page transition (pop) | slide down 5% + fade | - |
| Number change | count up/down animation | - |
| Typing in chat | typewriter per-character | - |
| Breathing phase change | color morph + particle direction | lightImpact |
| Plant growth | scale pulse + sparkle burst | mediumImpact |

---

### ЭТАП 6: ПРОИЗВОДИТЕЛЬНОСТЬ

Критические правила:

1. **RepaintBoundary** на каждом:
   - Animated background (GradientBg, ParticleField, MorphingBlob)
   - Навбар
   - Каждый элемент списка с анимацией

2. **const constructors** везде, где возможно

3. **shouldRepaint** для всех CustomPainter — проверять только изменившиеся параметры

4. **AnimationController.dispose()** в каждом dispose()

5. **addPostFrameCallback** для тяжёлых инициализаций

6. **Lazy loading** для списков: SliverList / ListView.builder

7. **Image caching**: CachedNetworkImage для всех сетевых изображений

8. **Particle counts**: не более 80 частиц на экран, 30 на фон, 20 на виджет

9. **Blur performance**: BackdropFilter дорогой — использовать максимум 2 на экран. Для остальных — fake blur через colored containers с округлением

10. **Profile builds**: тестировать в Profile mode на реальном устройстве (не Debug)

---

### ЭТАП 7: ПОРЯДОК РАБОТЫ

Работай строго по этому порядку, каждый этап — полностью готовый код:

1. `theme.dart` — расширить дизайн-систему (цвета, шрифты, Anim класс)
2. `shared/widgets/` — переписать существующие + создать новые виджеты
3. `shell.dart` — переработать навбар
4. `router.dart` — добавить кастомные page transitions
5. `onboarding/` — все 5 страниц + основной экран
6. `home/` — HomeScreen + все виджеты (AuraCard, StatsRow, QuickActions)
7. `meditation/` — MeditationPlayerScreen (самый важный экран!)
8. `ai_companion/` — AuraScreen
9. `breathing/` — оба экрана
10. `garden/` — GardenScreen
11. `mood_journal/` — все 3 экрана
12. `profile/` — ProfileScreen + SettingsScreen
13. `subscription/` — PaywallScreen
14. `pair/` — оба экрана

**ВАЖНО:**
- НЕ ломай существующую бизнес-логику (вызовы Backend, Db, AuthService, AudioService)
- НЕ меняй модели данных (shared/models/)
- НЕ меняй навигационные маршруты
- НЕ меняй core/ слой
- Меняй ТОЛЬКО визуальную часть (UI, анимации, стили, виджеты)
- Весь текст в UI — на русском языке (как сейчас)
- Каждый файл — полный, готовый к компиляции, без пропусков
- Не добавляй новые пакеты в pubspec.yaml, если это не абсолютно необходимо (всё можно сделать на текущем стеке + CustomPainter)

---

### ВИЗУАЛЬНАЯ МЕТАФОРА (для вдохновения)

Представь, что пользователь открывает приложение и оказывается внутри тихой, живой вселенной. Звёзды мерцают. Gradient-пятна медленно дрейфуют как космические туманности. Каждый элемент интерфейса парит, слегка размыт, как будто виден через тонкое стекло. Кнопки светятся мягким фиолетовым и бирюзовым. Числа плавно считают. Дыхательный orb расширяется и сжимается как живой организм, в такт дыханию пользователя. Сад — это маленькая планета, где каждое растение — светящийся бутон. AI Aura — это нежное, пульсирующее сознание, которое печатает ответы по одному символу.

Это не просто приложение. Это пространство покоя.

Начинай с ЭТАПА 1.
