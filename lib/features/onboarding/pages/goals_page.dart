import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/models/user_profile.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/onboarding_illustration.dart';

class GoalsPage extends StatelessWidget {
  const GoalsPage({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  final Set<MeditationGoal> selected;
  final void Function(MeditationGoal g) onToggle;

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
              scene: OnboardingScene.goals,
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
            'Что для тебя важно?',
            style: t.displayMedium,
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.03),
          const SizedBox(height: S.s),
          Text(
            'Выбери цели — мы подберём практики под тебя.',
            style: t.bodyMedium?.copyWith(color: C.textDim),
          ).animate().fadeIn(delay: 80.ms, duration: 400.ms),
          const SizedBox(height: S.l),
          for (var i = 0; i < MeditationGoal.values.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: S.s),
              child: _GoalItem(
                goal: MeditationGoal.values[i],
                isSelected: selected.contains(MeditationGoal.values[i]),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onToggle(MeditationGoal.values[i]);
                },
              )
                  .animate()
                  .fadeIn(
                      delay: (50 * i).ms,
                      duration: 350.ms)
                  .slideY(
                      begin: 0.06,
                      delay: (50 * i).ms,
                      duration: 350.ms,
                      curve: Curves.easeOutCubic),
            ),
        ],
      ),
    );
  }
}

class _GoalItem extends StatelessWidget {
  const _GoalItem({
    required this.goal,
    required this.isSelected,
    required this.onTap,
  });

  final MeditationGoal goal;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: Anim.fast,
      decoration: BoxDecoration(
        gradient: isSelected ? C.gradientPrimary : null,
        borderRadius: BorderRadius.circular(R.l + 1.5),
      ),
      padding: const EdgeInsets.all(1.5),
      child: GlassCard(
        onTap: onTap,
        semanticLabel:
            '${goal.label}, ${isSelected ? 'выбрано' : 'не выбрано'}',
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            if (isSelected)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        C.primary.withValues(alpha: 0.08),
                        C.accent.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(R.l),
                  ),
                ),
              ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: S.m, vertical: S.m),
              child: Row(
                children: [
                  Text(goal.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: S.m),
                  Expanded(
                    child: Text(
                      goal.label,
                      style: t.titleMedium?.copyWith(
                        color: C.text,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    duration: Anim.fast,
                    opacity: isSelected ? 1.0 : 0.0,
                    child: const Icon(Icons.check_circle_rounded,
                        color: C.accent, size: 22),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
