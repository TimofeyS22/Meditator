import 'package:flutter/material.dart';
import 'package:meditator/shared/theme/cosmic.dart';

class BreathRing extends StatefulWidget {
  final double size;
  final Color color;
  final Duration cycleDuration;

  const BreathRing({
    super.key,
    this.size = 200,
    this.color = Cosmic.accent,
    this.cycleDuration = Anim.breath,
  });

  @override
  State<BreathRing> createState() => _BreathRingState();
}

class _BreathRingState extends State<BreathRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.cycleDuration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        final ringSize = widget.size * (0.6 + 0.4 * t);

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Center(
            child: Container(
              width: ringSize,
              height: ringSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.3 + 0.5 * t),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.15 * t),
                    blurRadius: 20 * t,
                    spreadRadius: 4 * t,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
