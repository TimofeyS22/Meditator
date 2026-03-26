import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/glass_card.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final actions = <(String, Widget, VoidCallback)>[
      (
        'SOS',
        const MIcon(MIconType.sos, size: 32, color: Colors.white),
        () => context.push('/library?category=emergency'),
      ),
      (
        'Дыхание',
        const MIcon(MIconType.air, size: 32, color: Colors.white),
        () => context.push('/breathe'),
      ),
      (
        'Журнал',
        const MIcon(MIconType.book, size: 32, color: Colors.white),
        () => context.go('/journal'),
      ),
      (
        'Партнёр',
        const MIcon(MIconType.heart, size: 32, color: Colors.white),
        () => context.push('/pair'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Быстрый доступ',
          style: t.titleMedium?.copyWith(color: C.text),
        ),
        const SizedBox(height: S.m),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: S.s),
                _ActionCard(
                  label: actions[i].$1,
                  icon: actions[i].$2,
                  onTap: actions[i].$3,
                )
                    .animate()
                    .fadeIn(delay: (60 * i).ms, duration: 380.ms)
                    .scale(
                      begin: const Offset(0.85, 0.85),
                      delay: (60 * i).ms,
                      duration: 380.ms,
                      curve: Curves.easeOutBack,
                    ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final reduceMotion = AccessibilityUtils.reduceMotion(context);

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed && !reduceMotion ? 1.02 : 1.0,
          duration: AccessibilityUtils.adjustedDuration(context, Anim.fast),
          curve: Anim.curve,
          child: SizedBox(
            width: 120,
            height: 140,
            child: GlassCard(
              showGlow: _pressed && !reduceMotion,
              glowColor: C.glowPrimary,
              semanticLabel: widget.label,
              padding: const EdgeInsets.symmetric(vertical: S.m, horizontal: S.s),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        C.gradientPrimary.createShader(bounds),
                    child: widget.icon,
                  ),
                  const SizedBox(height: S.s),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: C.textSec),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
