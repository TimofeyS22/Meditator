import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/models/breathing.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';

class BreathingListScreen extends StatelessWidget {
  const BreathingListScreen({super.key});

  static int _minutesApprox(BreathingExercise e) {
    final phaseSec = e.phases.fold<int>(0, (a, p) => a + p.seconds);
    final total = phaseSec * e.cycles;
    return (total / 60).ceil().clamp(1, 999);
  }

  @override
  Widget build(BuildContext context) {
    final presets = BreathingExercise.presets;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: GradientBg(
        showStars: true,
        intensity: 0.3,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(S.l, S.xl, S.l, S.xs),
                child: Text('Дыхание', style: tt.displayMedium)
                    .animate()
                    .fadeIn(duration: Anim.slow)
                    .slideY(begin: -0.08, end: 0, curve: Anim.curve),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(S.l, 0, S.l, S.l),
                child: Text(
                  'Самый быстрый способ изменить состояние',
                  style: tt.bodyLarge?.copyWith(color: C.textSec),
                ).animate().fadeIn(delay: 80.ms, duration: Anim.slow),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(S.m, 0, S.m, S.xxl),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final e = presets[i];
                    final min = _minutesApprox(e);
                    return _ExerciseCard(exercise: e, minutes: min)
                        .animate(delay: (100 + 50 * i).ms)
                        .fadeIn(duration: Anim.normal, curve: Anim.curve)
                        .slideX(begin: 0.04, end: 0, curve: Anim.curve);
                  },
                  childCount: presets.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise, required this.minutes});

  final BreathingExercise exercise;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final e = exercise;

    return Padding(
      padding: const EdgeInsets.only(bottom: S.m),
      child: GlassCard(
        showBorder: true,
        onTap: () => context.push('/breathe?id=${Uri.encodeComponent(e.id)}'),
        padding: const EdgeInsets.all(S.m),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(R.full),
                  color: e.color,
                ),
              ),
              const SizedBox(width: S.m),
              Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [e.color, e.color.withValues(alpha: 0.5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: e.color.withValues(alpha: 0.35),
                        blurRadius: 14,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: S.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(e.name, style: tt.titleMedium),
                        ),
                        Text(
                          '~$minutes мин',
                          style: tt.bodySmall?.copyWith(color: e.color),
                        ),
                      ],
                    ),
                    const SizedBox(height: S.xs),
                    Text(
                      e.description,
                      style: tt.bodyMedium?.copyWith(
                        color: C.textSec,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: S.s),
                    Text(
                      e.benefit,
                      style: tt.bodySmall?.copyWith(
                        color: C.textDim,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: S.s),
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: C.textDim,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
