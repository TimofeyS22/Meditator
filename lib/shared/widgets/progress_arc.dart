import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';

class ProgressArc extends StatefulWidget {
  const ProgressArc({
    super.key,
    required this.progress,
    required this.size,
    required this.strokeWidth,
    this.child,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  State<ProgressArc> createState() => _ProgressArcState();
}

class _ProgressArcState extends State<ProgressArc>
    with TickerProviderStateMixin {
  late final AnimationController _rotation;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      if (_rotation.isAnimating) _rotation.stop();
    } else if (!_rotation.isAnimating) {
      _rotation.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress.clamp(0.0, 1.0);
    final reduceMotion = _reduceMotion;
    return Semantics(
      label: 'Прогресс ${(widget.progress * 100).toInt()}%',
      child: TweenAnimationBuilder<double>(
        duration: AccessibilityUtils.adjustedDuration(context, Anim.slow),
        curve: Anim.curve,
        tween: Tween<double>(end: p),
        builder: (context, animatedProgress, tweenChild) => AnimatedBuilder(
          animation: _rotation,
          child: tweenChild,
          builder: (context, innerChild) => SizedBox(
            width: widget.size,
            height: widget.size,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _ProgressArcPainter(
                  progress: animatedProgress.clamp(0.0, 1.0),
                  strokeWidth: widget.strokeWidth,
                  rotation: reduceMotion
                      ? 0.0
                      : _rotation.value * math.pi * 2,
                ),
                child: innerChild != null ? Center(child: innerChild) : null,
              ),
            ),
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

class _ProgressArcPainter extends CustomPainter {
  _ProgressArcPainter({
    required this.progress,
    required this.strokeWidth,
    required this.rotation,
  });

  final double progress;
  final double strokeWidth;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Inner subtle glow at center
    final innerGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          C.primary.withValues(alpha: 0.04),
          C.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.85));
    canvas.drawCircle(center, radius * 0.85, innerGlowPaint);

    // Thin outer ring (1px) rotating slowly
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);
    final outerRingPaint = Paint()
      ..color = C.surfaceLight.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius + strokeWidth / 2 + 4, outerRingPaint);
    canvas.restore();

    // Track ring
    final trackPaint = Paint()
      ..color = C.surfaceLight.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, trackPaint);

    if (progress <= 0) return;

    // Progress arc with sweep gradient
    final sweep = math.pi * 2 * progress;
    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + sweep,
      colors: const [Color(0xFF6366F1), Color(0xFF2DD4BF)],
      stops: const [0, 1],
    );

    final arcPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arcPaint);

    // Endpoint position via cos/sin
    final endAngle = -math.pi / 2 + sweep;
    final endX = center.dx + radius * math.cos(endAngle);
    final endY = center.dy + radius * math.sin(endAngle);
    final endpoint = Offset(endX, endY);

    // Glowing endpoint dot
    canvas.drawCircle(
      endpoint,
      7,
      Paint()
        ..color = C.accent.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(endpoint, 4, Paint()..color = C.accent);

    // Particle sparks emanating from the endpoint
    for (int i = 0; i < 7; i++) {
      final t = i / 7.0;
      final sparkAngle = t * math.pi * 2.5 + rotation * 0.5 + progress * math.pi;
      final distFactor = (math.sin(t * math.pi * 4 + rotation * 2) + 1) / 2;
      final dist = 4.0 + 10.0 * distFactor;
      final px = endX + dist * math.cos(sparkAngle);
      final py = endY + dist * math.sin(sparkAngle);
      final alpha = (0.55 - t * 0.45).clamp(0.05, 0.55);
      final sparkRadius = (1.8 - t * 0.8).clamp(0.6, 2.0);

      canvas.drawCircle(
        Offset(px, py),
        sparkRadius,
        Paint()
          ..color = C.accent.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.rotation != rotation;
  }
}
