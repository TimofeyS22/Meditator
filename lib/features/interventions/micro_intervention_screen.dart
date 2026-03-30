import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';

/// Quick 30–60s practices opened from local notifications or in-app.
class MicroInterventionScreen extends StatefulWidget {
  const MicroInterventionScreen({super.key, required this.type});

  final String type;

  @override
  State<MicroInterventionScreen> createState() => _MicroInterventionScreenState();
}

class _MicroInterventionScreenState extends State<MicroInterventionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathCtrl;
  int _groundingStep = 0;

  static const _groundingPrompts = [
    ('5', 'Назови пять вещей, которые видишь вокруг.'),
    ('4', 'Четыре — что можешь потрогать или почувствовать телом.'),
    ('3', 'Три — какие звуки слышишь.'),
    ('2', 'Два — запаха или вкуса.'),
    ('1', 'Одно — что приятно или успокаивает прямо сейчас.'),
  ];

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: Anim.breathe,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    super.dispose();
  }

  String get _kind {
    switch (widget.type.toLowerCase().trim()) {
      case 'body_scan':
      case 'bodyscan':
        return 'body_scan';
      case 'gratitude':
        return 'gratitude';
      case 'grounding':
      case '54321':
        return 'grounding';
      default:
        return 'breathing';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_kind) {
      'body_scan' => 'Микро-сканирование',
      'gratitude' => 'Благодарность',
      'grounding' => 'Заземление 5-4-3-2-1',
      _ => 'Дыхание',
    };

    return PopScope(
      canPop: true,
      child: GradientBg(
        showAurora: true,
        intensity: 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(S.s, S.s, S.m, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.close_rounded, color: context.cTextSec),
                    tooltip: 'Закрыть',
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    )
                        .animate()
                        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                        .slideY(begin: -0.06, end: 0, duration: 400.ms, curve: Curves.easeOut),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: S.m, vertical: S.m),
                child: switch (_kind) {
                  'body_scan' => _BodyScanPanel(),
                  'gratitude' => _GratitudePanel(),
                  'grounding' => _GroundingPanel(
                      step: _groundingStep,
                      prompts: _groundingPrompts,
                      onStepChanged: (i) => setState(() => _groundingStep = i),
                    ),
                  _ => _BreathingPanel(controller: _breathCtrl),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(S.m, 0, S.m, S.l),
              child: GlowButton(
                onPressed: () => context.pop(),
                showGlow: true,
                glowColor: C.glowAccent,
                semanticLabel: 'Завершить практику',
                child: const Text('Готово'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreathingPanel extends StatelessWidget {
  const _BreathingPanel({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Следуй кругу: вдох — расслабление — выдох.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: context.cTextDim, height: 1.45),
        )
            .animate()
            .fadeIn(delay: 100.ms, duration: 500.ms)
            .slideY(begin: 0.08, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
        const SizedBox(height: S.xl),
        AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final t = CurvedAnimation(parent: controller, curve: Curves.easeInOut).value;
            final scale = 0.74 + 0.26 * t;
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: C.accent.withValues(alpha: 0.12),
              border: Border.all(color: C.accent.withValues(alpha: 0.65), width: 2),
              boxShadow: [
                BoxShadow(
                  color: C.glowAccent.withValues(alpha: 0.35),
                  blurRadius: 28,
                  spreadRadius: -4,
                ),
              ],
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(duration: 2500.ms, color: C.accent.withValues(alpha: 0.08)),
        const SizedBox(height: S.l),
        Text(
          'Медленно, без напряжения.',
          style: Theme.of(context).textTheme.bodyMedium,
        ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
      ],
    );
  }
}

class _BodyScanPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const steps = [
      'Стопы и лодыжки — тепло или контакт с опорой.',
      'Икры и колени — мягкое внимание, без оценки.',
      'Живот и грудь — как движется дыхание.',
      'Руки и плечи — отпусти лишнее напряжение.',
      'Шея и лицо — челюсть чуть мягче, взгляд спокойнее.',
    ];
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: steps.length,
      separatorBuilder: (_, _) => const SizedBox(height: S.m),
      itemBuilder: (context, i) {
        return GlassCard(
          showBorder: true,
          padding: const EdgeInsets.all(S.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${i + 1}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: C.accent,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: S.m),
              Expanded(
                child: Text(
                  steps[i],
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: context.cText, height: 1.5),
                ),
              ),
            ],
          ),
        )
            .animate(delay: (80 * i).ms)
            .fadeIn(duration: 450.ms, curve: Curves.easeOutCubic)
            .slideX(begin: 0.04, end: 0, duration: 450.ms, curve: Curves.easeOutCubic);
      },
    );
  }
}

class _GratitudePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.auto_awesome_rounded, size: 48, color: C.accent.withValues(alpha: 0.9))
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(0.92, 0.92),
              end: const Offset(1.06, 1.06),
              duration: 2200.ms,
              curve: Curves.easeInOut,
            ),
        const SizedBox(height: S.l),
        GlassCard(
          showGlow: true,
          glowColor: C.glowAccent,
          showBorder: true,
          padding: const EdgeInsets.all(S.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Одна благодарность',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: S.s),
              Text(
                'Вспомни что-то маленькое, что уже есть: человек, момент, ощущение, свет в окне. '
                'Побудь с этим 20–40 секунд.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: context.cTextDim, height: 1.55),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.06, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
      ],
    );
  }
}

class _GroundingPanel extends StatelessWidget {
  const _GroundingPanel({
    required this.step,
    required this.prompts,
    required this.onStepChanged,
  });

  final int step;
  final List<(String, String)> prompts;
  final ValueChanged<int> onStepChanged;

  @override
  Widget build(BuildContext context) {
    final safeStep = step.clamp(0, prompts.length - 1);
    final item = prompts[safeStep];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(prompts.length, (i) {
            final active = i == safeStep;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: S.xs),
              child: AnimatedContainer(
                duration: Anim.fast,
                width: active ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(R.m),
                  color: active ? C.accent : context.cTextDim.withValues(alpha: 0.35),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: S.l),
        Expanded(
          child: GlassCard(
            showBorder: true,
            useBlur: true,
            blur: 14,
            padding: const EdgeInsets.all(S.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$1,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: C.accent,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                )
                    .animate(key: ValueKey(safeStep))
                    .fadeIn(duration: 350.ms)
                    .scale(begin: const Offset(0.92, 0.92), duration: 350.ms, curve: Anim.curveGentle),
                const SizedBox(height: S.m),
                Text(
                  item.$2,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: context.cText, height: 1.55),
                )
                    .animate(key: ValueKey('${safeStep}_t'))
                    .fadeIn(delay: 80.ms, duration: 400.ms)
                    .slideX(begin: 0.03, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
              ],
            ),
          ),
        ),
        const SizedBox(height: S.m),
        Row(
          children: [
            Expanded(
              child: GlowButton(
                onPressed: safeStep > 0 ? () => onStepChanged(safeStep - 1) : null,
                showGlow: false,
                child: const Text('Назад'),
              ),
            ),
            const SizedBox(width: S.m),
            Expanded(
              child: GlowButton(
                onPressed: safeStep < prompts.length - 1
                    ? () => onStepChanged(safeStep + 1)
                    : null,
                showGlow: true,
                glowColor: C.glowAccent,
                child: Text(safeStep < prompts.length - 1 ? 'Дальше' : 'Шаг завершён'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
