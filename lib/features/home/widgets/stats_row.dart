import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/widgets/animated_number.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/glass_card.dart';

class StatsRow extends StatelessWidget {
  const StatsRow({
    super.key,
    required this.minutesToday,
    required this.streak,
    required this.totalSessions,
  });

  final int minutesToday;
  final int streak;
  final int totalSessions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final items = <(String, int, String, Widget)>[
      ('Сегодня', minutesToday, 'мин',
          const MIcon(MIconType.timer, size: 20, color: Colors.white)),
      ('Стрик', streak, 'дн.',
          const MIcon(MIconType.bolt, size: 20, color: Colors.white)),
      ('Сессий', totalSessions, 'всего',
          const MIcon(MIconType.meditation, size: 20, color: Colors.white)),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: S.s),
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: S.m, horizontal: S.s),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        C.gradientPrimary.createShader(bounds),
                    child: items[i].$4,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          items[i].$1,
                          style: t.bodySmall?.copyWith(color: C.textDim),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            AnimatedNumber(
                              value: items[i].$2,
                              style: t.titleLarge?.copyWith(
                                color: C.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                items[i].$3,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySmall?.copyWith(color: C.textSec),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: (80 * i).ms, duration: 400.ms)
                .slideY(
                  begin: 0.05,
                  delay: (80 * i).ms,
                  duration: 400.ms,
                ),
          ),
        ],
      ],
    );
  }
}
