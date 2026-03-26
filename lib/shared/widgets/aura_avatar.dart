import 'dart:math';

import 'package:flutter/material.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';

class AuraAvatar extends StatefulWidget {
  const AuraAvatar({super.key, this.size = 80, this.isThinking = false});

  final double size;
  final bool isThinking;

  @override
  State<AuraAvatar> createState() => _AuraAvatarState();
}

class _AuraAvatarState extends State<AuraAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      if (_ctrl.isAnimating) _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _AuraFacePainter(
            progress: _reduceMotion ? 0.0 : _ctrl.value,
            isThinking: widget.isThinking,
          ),
        ),
      ),
    );
  }
}

class _AuraFacePainter extends CustomPainter {
  _AuraFacePainter({required this.progress, required this.isThinking});

  final double progress;
  final bool isThinking;

  static const double _blinkPeriodFactor = 6 / 4.5;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final s = size.shortestSide;
    final radius = s / 2;

    _drawBackground(canvas, c, radius);

    final speed = isThinking ? 2.0 : 1.0;
    final rot1 = progress * 2 * pi * speed;
    final rot2 = progress * 2 * pi * -1.35 * speed;
    final rot3 = progress * 2 * pi * 0.72 * speed;

    _drawOrbitRing(canvas, c, radius * 0.34, rot1, 0.14);
    _drawOrbitRing(canvas, c, radius * 0.48, rot2, 0.18);
    _drawOrbitRing(canvas, c, radius * 0.62, rot3, 0.12);

    if (isThinking) {
      _drawThinkingDots(canvas, c, radius, rot1, rot2, rot3);
    }

    _drawEyes(canvas, c, s);
    _drawSmile(canvas, c, s);
  }

  void _drawBackground(Canvas canvas, Offset c, double radius) {
    final rect = Rect.fromCircle(center: c, radius: radius * 1.02);
    final shader = RadialGradient(
      colors: [
        C.primary.withValues(alpha: 0.5),
        C.primary.withValues(alpha: 0.22),
        C.primary.withValues(alpha: 0.06),
        C.primary.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.45, 0.78, 1.0],
    ).createShader(rect);
    canvas.drawCircle(c, radius * 0.98, Paint()..shader = shader);
  }

  void _drawOrbitRing(
    Canvas canvas,
    Offset c,
    double ringRadius,
    double rotation,
    double baseOpacity,
  ) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: baseOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: c, radius: ringRadius);
    const segments = 3;
    final step = 2 * pi / segments;
    for (var i = 0; i < segments; i++) {
      final sweep = step * 0.38;
      final start = rotation + i * step + (step - sweep) / 2;
      canvas.drawArc(rect, start, sweep, false, paint);
    }
  }

  void _drawThinkingDots(
    Canvas canvas,
    Offset c,
    double radius,
    double r1,
    double r2,
    double r3,
  ) {
    final pulse = 0.35 + 0.45 * sin(progress * 2 * pi * 3.2);
    final dotPaint = Paint()..color = C.accent.withValues(alpha: pulse * 0.85);
    final radii = [radius * 0.34, radius * 0.48, radius * 0.62];
    final rots = [r1, r2, r3];
    for (var ring = 0; ring < 3; ring++) {
      final rr = radii[ring];
      final rot = rots[ring];
      for (var k = 0; k < 3; k++) {
        final a = rot + k * (2 * pi / 3) + pi / 3;
        final p = Offset(c.dx + rr * cos(a), c.dy + rr * sin(a));
        canvas.drawCircle(p, 1.2 + 0.35 * sin(progress * 2 * pi * 4 + k + ring), dotPaint);
      }
    }
  }

  void _drawEyes(Canvas canvas, Offset c, double s) {
    final eyeY = c.dy - s * 0.175;
    final eyeSep = s * 0.11;
    final eyeW = s * 0.072;
    final phase = progress * 2 * pi * _blinkPeriodFactor;
    final blinkSpike = pow((1 - sin(phase)) / 2, 11).toDouble();
    final eyeH = eyeW * 0.52 * (1 - blinkSpike * 0.94);

    final glow = Paint()
      ..color = Colors.white.withValues(alpha: 0.72)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.8);

    for (final sign in [-1.0, 1.0]) {
      final ox = c.dx + sign * eyeSep;
      final r = Rect.fromCenter(
        center: Offset(ox, eyeY),
        width: eyeW,
        height: max(eyeH, eyeW * 0.04),
      );
      canvas.drawOval(r, glow);
    }

    final core = Paint()..color = Colors.white.withValues(alpha: 0.35);
    for (final sign in [-1.0, 1.0]) {
      final ox = c.dx + sign * eyeSep;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(ox, eyeY),
          width: eyeW * 0.45,
          height: max(eyeH * 0.55, eyeW * 0.02),
        ),
        core,
      );
    }
  }

  void _drawSmile(Canvas canvas, Offset c, double s) {
    final smileRect = Rect.fromCenter(
      center: Offset(c.dx, c.dy + s * 0.065),
      width: s * 0.24,
      height: s * 0.11,
    );
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(smileRect, pi * 0.22, pi * 2 / 3, false, paint);
  }

  @override
  bool shouldRepaint(covariant _AuraFacePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isThinking != isThinking;
}
