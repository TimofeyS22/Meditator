import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/models/user_profile.dart';
import 'package:meditator/shared/widgets/onboarding_illustration.dart';

enum OnboardingTimeSlot { morning, day, evening, night }

extension OnboardingTimeSlotX on OnboardingTimeSlot {
  String get label => switch (this) {
        OnboardingTimeSlot.morning => 'Утро',
        OnboardingTimeSlot.day => 'День',
        OnboardingTimeSlot.evening => 'Вечер',
        OnboardingTimeSlot.night => 'Ночь',
      };

  int get suggestedHour => switch (this) {
        OnboardingTimeSlot.morning => 8,
        OnboardingTimeSlot.day => 14,
        OnboardingTimeSlot.evening => 21,
        OnboardingTimeSlot.night => 23,
      };
}

class PrefsPage extends StatelessWidget {
  const PrefsPage({
    super.key,
    required this.voice,
    required this.duration,
    required this.timeSlot,
    required this.onVoice,
    required this.onDuration,
    required this.onTimeSlot,
  });

  final PreferredVoice voice;
  final PreferredDuration duration;
  final OnboardingTimeSlot timeSlot;
  final ValueChanged<PreferredVoice> onVoice;
  final ValueChanged<PreferredDuration> onDuration;
  final ValueChanged<OnboardingTimeSlot> onTimeSlot;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(S.l, S.xl, S.l, S.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: OnboardingIllustration(
              scene: OnboardingScene.preferences,
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
            'Настройки практики',
            style: t.displayMedium,
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: S.s),
          Text(
            'Настроим под тебя — изменить можно в любой момент.',
            style: t.bodyMedium?.copyWith(color: C.textDim),
          ).animate().fadeIn(delay: 70.ms, duration: 400.ms),

          const SizedBox(height: S.l),
          Text('Голос', style: t.titleSmall?.copyWith(color: C.textSec))
              .animate()
              .fadeIn(delay: 100.ms, duration: 350.ms),
          const SizedBox(height: S.s),
          Wrap(
            spacing: S.s,
            runSpacing: S.s,
            children: [
              for (var i = 0; i < PreferredVoice.values.length; i++)
                _GradientChip(
                  label: _voiceLabel(PreferredVoice.values[i]),
                  selected: voice == PreferredVoice.values[i],
                  onTap: () => onVoice(PreferredVoice.values[i]),
                )
                    .animate()
                    .fadeIn(delay: (120 + 50 * i).ms, duration: 320.ms)
                    .scale(
                      begin: const Offset(0.92, 0.92),
                      delay: (120 + 50 * i).ms,
                      duration: 320.ms,
                      curve: Curves.easeOutBack,
                    ),
            ],
          ),

          const SizedBox(height: S.l),
          Text('Длительность', style: t.titleSmall?.copyWith(color: C.textSec))
              .animate()
              .fadeIn(delay: 200.ms, duration: 350.ms),
          const SizedBox(height: S.s),
          Wrap(
            spacing: S.s,
            runSpacing: S.s,
            children: [
              for (var i = 0; i < PreferredDuration.values.length; i++)
                _GradientChip(
                  label: PreferredDuration.values[i].label,
                  selected: duration == PreferredDuration.values[i],
                  onTap: () => onDuration(PreferredDuration.values[i]),
                )
                    .animate()
                    .fadeIn(delay: (220 + 50 * i).ms, duration: 320.ms)
                    .scale(
                      begin: const Offset(0.92, 0.92),
                      delay: (220 + 50 * i).ms,
                      duration: 320.ms,
                      curve: Curves.easeOutBack,
                    ),
            ],
          ),

          const SizedBox(height: S.l),
          Text('Время', style: t.titleSmall?.copyWith(color: C.textSec))
              .animate()
              .fadeIn(delay: 300.ms, duration: 350.ms),
          const SizedBox(height: S.s),
          Row(
            children: [
              for (var i = 0;
                  i < OnboardingTimeSlot.values.length;
                  i++) ...[
                if (i > 0) const SizedBox(width: S.s),
                Expanded(
                  child: _GradientChip(
                    label: OnboardingTimeSlot.values[i].label,
                    selected: timeSlot == OnboardingTimeSlot.values[i],
                    onTap: () => onTimeSlot(OnboardingTimeSlot.values[i]),
                    expand: true,
                  )
                      .animate()
                      .fadeIn(delay: (320 + 60 * i).ms, duration: 350.ms)
                      .slideY(begin: 0.06, delay: (320 + 60 * i).ms),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _voiceLabel(PreferredVoice v) => switch (v) {
        PreferredVoice.male => 'Мужской',
        PreferredVoice.female => 'Женский',
        PreferredVoice.any => 'Любой',
      };
}

class _GradientChip extends StatelessWidget {
  const _GradientChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label${selected ? ', выбран' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Anim.fast,
          curve: Anim.curve,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            gradient: selected ? C.gradientPrimary : null,
            borderRadius: BorderRadius.circular(R.xl),
          ),
          child: AnimatedContainer(
            duration: Anim.fast,
            curve: Anim.curve,
            padding: expand
                ? const EdgeInsets.symmetric(vertical: S.m)
                : const EdgeInsets.symmetric(
                    horizontal: S.m, vertical: S.s + 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(R.xl - 1.5),
              color: selected
                  ? C.primary.withValues(alpha: 0.15)
                  : C.surfaceLight,
              border: Border.all(
                color: selected ? Colors.transparent : C.surfaceBorder,
                width: 0.5,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? C.text : C.textSec,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
