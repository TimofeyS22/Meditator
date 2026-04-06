import 'dart:math';
import 'package:flutter/material.dart';
import 'package:meditator/shared/theme/cosmic.dart';

class AuraOrb extends StatefulWidget {
  final double size;
  final Color color;
  final Color glowColor;
  final Duration breathDuration;

  const AuraOrb({
    super.key,
    this.size = 180,
    this.color = Cosmic.primary,
    this.glowColor = Cosmic.glowPrimary,
    this.breathDuration = Anim.breath,
  });

  @override
  State<AuraOrb> createState() => _AuraOrbState();
}

class _AuraOrbState extends State<AuraOrb> with TickerProviderStateMixin {
  late final AnimationController _breathCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _colorCtrl;

  Color _fromColor = Cosmic.primary;
  Color _toColor = Cosmic.primary;
  Color _fromGlow = Cosmic.glowPrimary;
  Color _toGlow = Cosmic.glowPrimary;

  @override
  void initState() {
    super.initState();
    _fromColor = widget.color;
    _toColor = widget.color;
    _fromGlow = widget.glowColor;
    _toGlow = widget.glowColor;

    _breathCtrl = AnimationController(vsync: this, duration: widget.breathDuration)
      ..repeat(reverse: true);
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _colorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: 1.0,
    );
  }

  @override
  void didUpdateWidget(AuraOrb old) {
    super.didUpdateWidget(old);
    if (old.color != widget.color || old.glowColor != widget.glowColor) {
      _fromColor = Color.lerp(_fromColor, _toColor, _colorCtrl.value) ?? _toColor;
      _fromGlow = Color.lerp(_fromGlow, _toGlow, _colorCtrl.value) ?? _toGlow;
      _toColor = widget.color;
      _toGlow = widget.glowColor;
      _colorCtrl.forward(from: 0);
    }
    if (old.breathDuration != widget.breathDuration) {
      _breathCtrl.duration = widget.breathDuration;
    }
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _shimmerCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_breathCtrl, _shimmerCtrl, _colorCtrl]),
      builder: (_, __) {
        final breathVal = Curves.easeInOut.transform(_breathCtrl.value);
        final scale = 0.92 + 0.08 * breathVal;
        final glowRadius = 40.0 + 20.0 * breathVal;
        final glowAlpha = 0.3 + 0.2 * breathVal;
        final shimmerAngle = _shimmerCtrl.value * 2 * pi;

        final ct = CurvedAnimation(parent: _colorCtrl, curve: Anim.curve).value;
        final color = Color.lerp(_fromColor, _toColor, ct)!;
        final glow = Color.lerp(_fromGlow, _toGlow, ct)!;

        return SizedBox(
          width: widget.size * 1.4,
          height: widget.size * 1.4,
          child: Center(
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: glow.withValues(alpha: glowAlpha),
                      blurRadius: glowRadius,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: Cosmic.accent.withValues(alpha: glowAlpha * 0.3),
                      blurRadius: glowRadius * 1.5,
                      spreadRadius: 0,
                    ),
                  ],
                  gradient: SweepGradient(
                    startAngle: shimmerAngle,
                    endAngle: shimmerAngle + 2 * pi,
                    colors: [
                      color,
                      color.withValues(alpha: 0.7),
                      Cosmic.accent.withValues(alpha: 0.4),
                      color.withValues(alpha: 0.7),
                      color,
                    ],
                    stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withValues(alpha: 0.6),
                        color.withValues(alpha: 0.3),
                        color.withValues(alpha: 0.1),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
