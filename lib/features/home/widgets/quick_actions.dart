import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/widgets/glass_card.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = <_ActionDef>[
      _ActionDef('Библиотека', Icons.library_music_rounded, C.primary, () => context.push('/library')),
      _ActionDef('Дыхание', Icons.air_rounded, C.accent, () => context.push('/breathing')),
      _ActionDef('Таймер', Icons.timer_rounded, C.calm, () => context.push('/timer')),
      _ActionDef('AI-практика', Icons.auto_awesome_rounded, C.gold, () => context.push('/ai-play?duration=10')),
      _ActionDef('Звуковая лаб', Icons.graphic_eq_rounded, C.rose, () => context.push('/sound-lab')),
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.zero,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: S.s),
        itemBuilder: (context, i) {
          final a = actions[i];
          return _ActionCard(def: a, index: i);
        },
      ),
    );
  }
}

class _ActionDef {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionDef(this.label, this.icon, this.color, this.onTap);
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.def, required this.index});
  final _ActionDef def;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return SizedBox(
      width: 100,
      child: GlassCard(
        variant: GlassCardVariant.surface,
        onTap: () {
          HapticFeedback.lightImpact();
          def.onTap();
        },
        padding: const EdgeInsets.all(S.m),
        semanticLabel: def.label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: def.color.withValues(alpha: 0.12),
              ),
              child: Icon(def.icon, size: 18, color: def.color),
            ),
            Text(
              def.label,
              style: t.labelSmall?.copyWith(
                color: context.cText,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (100 * index).ms, duration: Anim.normal)
        .slideX(begin: 0.08, delay: (100 * index).ms, duration: Anim.normal, curve: Anim.curve);
  }
}
