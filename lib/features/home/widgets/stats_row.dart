import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/widgets/animated_number.dart';

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
    final items = <(String, int, String)>[
      ('Сегодня', minutesToday, 'мин'),
      ('Серия', streak, 'дн.'),
      ('Всего', totalSessions, 'сессий'),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: S.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedNumber(
                  value: items[i].$2,
                  style: t.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${items[i].$1} · ${items[i].$3}',
                  style: t.bodySmall?.copyWith(color: context.cTextSec),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
                .animate()
                .fadeIn(delay: (100 * i).ms, duration: 400.ms)
                .slideY(begin: 0.06, delay: (100 * i).ms, duration: 400.ms),
          ),
        ],
      ],
    );
  }
}
