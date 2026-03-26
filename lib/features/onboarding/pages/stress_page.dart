import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/models/user_profile.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/morphing_blob.dart';
import 'package:meditator/shared/widgets/onboarding_illustration.dart';

Color _stressColor(StressLevel level) => switch (level) {
      StressLevel.low => C.accent,
      StressLevel.moderate => C.primary,
      StressLevel.high => C.rose,
      StressLevel.veryHigh => C.anxious,
    };

class StressPage extends StatelessWidget {
  const StressPage({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final StressLevel selected;
  final ValueChanged<StressLevel> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final selectedColor = _stressColor(selected);

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedContainer(
            duration: Anim.slow,
            curve: Anim.curve,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, 0.4),
                radius: 0.9,
                colors: [
                  selectedColor.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(S.l, S.xl, S.l, S.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: OnboardingIllustration(
                  scene: OnboardingScene.stress,
                  size: 180,
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1, 1),
                      duration: 500.ms,
                      curve: Curves.easeOutCubic,
                    ),
              ),
              const SizedBox(height: S.m),
              Text(
                'Уровень стресса',
                style: t.displayMedium,
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: S.s),
              Text(
                'Честный ответ поможет подобрать практики мягче.',
                style: t.bodyMedium?.copyWith(color: C.textDim),
              ).animate().fadeIn(delay: 70.ms, duration: 400.ms),
              const SizedBox(height: S.l),
              ...StressLevel.values.asMap().entries.map((e) {
                final level = e.value;
                final i = e.key;
                final isOn = selected == level;
                final color = _stressColor(level);

                return Padding(
                  padding: const EdgeInsets.only(bottom: S.m),
                  child: AnimatedContainer(
                    duration: Anim.fast,
                    decoration: BoxDecoration(
                      gradient: isOn ? C.gradientPrimary : null,
                      borderRadius: BorderRadius.circular(R.l + 1.5),
                      boxShadow: isOn
                          ? [
                              BoxShadow(
                                  color: color.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: -4)
                            ]
                          : null,
                    ),
                    padding: const EdgeInsets.all(1.5),
                    child: GlassCard(
                      onTap: () => onSelect(level),
                      semanticLabel:
                          'Уровень стресса ${level.label}${isOn ? ', выбран' : ''}',
                      padding: const EdgeInsets.symmetric(
                          horizontal: S.m, vertical: S.m),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 48,
                            height: 48,
                            child:
                                Center(child: MorphingBlob(size: 40, color: color)),
                          ),
                          const SizedBox(width: S.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  level.label,
                                  style: t.titleMedium?.copyWith(
                                    color: C.text,
                                    fontWeight: isOn
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _hint(level),
                                  style:
                                      t.bodySmall?.copyWith(color: C.textDim),
                                ),
                              ],
                            ),
                          ),
                          AnimatedOpacity(
                            duration: Anim.fast,
                            opacity: isOn ? 1.0 : 0.0,
                            child: Icon(Icons.check_circle_rounded,
                                color: color, size: 24),
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(
                          delay: (80 * i).ms, duration: 380.ms)
                      .slideX(
                          begin: 0.04,
                          delay: (80 * i).ms,
                          duration: 380.ms,
                          curve: Curves.easeOutCubic),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  static String _hint(StressLevel l) => switch (l) {
        StressLevel.low => 'Редко, в целом спокойно',
        StressLevel.moderate => 'Бывает, но справляюсь',
        StressLevel.high => 'Часто на фоне',
        StressLevel.veryHigh => 'Почти всегда рядом',
      };
}
