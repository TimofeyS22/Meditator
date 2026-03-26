import 'dart:math';

import 'package:flutter/material.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';

class MeditatorIllustration extends StatefulWidget {
  const MeditatorIllustration({super.key, this.size = 300});

  final double size;

  @override
  State<MeditatorIllustration> createState() => _MeditatorIllustrationState();
}

class _MeditatorIllustrationState extends State<MeditatorIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
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
          painter: _MeditatorPainter(progress: _reduceMotion ? 0.0 : _ctrl.value),
        ),
      ),
    );
  }
}

class _MeditatorPainter extends CustomPainter {
  _MeditatorPainter({required this.progress});

  final double progress;

  static const int _petalCount = 6;
  static const int _particleCount = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    _drawLotus(canvas, w, h, cx);
    _drawEnergyRings(canvas, size, cx, h);
    _drawSilhouette(canvas, w, h, cx);
    _drawParticles(canvas, w, h, cx);
  }

  void _drawLotus(Canvas canvas, double w, double h, double cx) {
    final baseY = h * 0.88;
    final base = Offset(cx, baseY);
    final petalLen = w * 0.22;

    final fill = Paint()
      ..color = C.primary.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = C.primary.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final fanStart = -pi * 0.78;
    final fanEnd = -pi * 0.22;
    final step = (fanEnd - fanStart) / (_petalCount - 1);

    for (var i = 0; i < _petalCount; i++) {
      final a = fanStart + i * step;
      final tip = Offset(
        base.dx + petalLen * cos(a),
        base.dy + petalLen * 0.55 * sin(a) - petalLen * 0.08,
      );
      final ctrl = Offset(
        base.dx + petalLen * 0.48 * cos(a + 0.06 * (i - 2.5)),
        base.dy + petalLen * 0.28 * sin(a) - petalLen * 0.02,
      );

      final path = Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(
          ctrl.dx + petalLen * 0.08 * sin(a),
          ctrl.dy + petalLen * 0.12,
          base.dx,
          base.dy,
        )
        ..close();

      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  void _drawEnergyRings(Canvas canvas, Size size, double cx, double h) {
    final cy = h * 0.46;
    final center = Offset(cx, cy);
    final baseR = min(size.width, size.height) * 0.18;

    final configs = <(Color, double)>[
      (C.primary, 0.14),
      (C.accent, 0.12),
      (C.gold, 0.1),
    ];

    for (var i = 0; i < 3; i++) {
      final pulse = 1 + 0.045 * sin(progress * 2 * pi + i * 0.9);
      final r = baseR * (1.15 + i * 0.38) * pulse;
      final paint = Paint()
        ..color = configs[i].$1.withValues(alpha: configs[i].$2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15;
      canvas.drawCircle(center, r, paint);
    }
  }

  void _drawSilhouette(Canvas canvas, double w, double h, double cx) {
    final headCy = h * 0.3;
    final headR = w * 0.045;
    final head = Offset(cx, headCy);

    final fill = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(head, headR, fill);
    canvas.drawCircle(head, headR, outline);

    final neckY = headCy + headR * 0.85;
    final hipY = h * 0.58;
    final shoulderW = w * 0.11;
    final hipW = w * 0.14;

    final body = Path()
      ..moveTo(cx - shoulderW * 0.55, neckY)
      ..lineTo(cx + shoulderW * 0.55, neckY)
      ..lineTo(cx + hipW * 0.5, hipY)
      ..lineTo(cx - hipW * 0.5, hipY)
      ..close();
    canvas.drawPath(body, fill);
    canvas.drawPath(body, outline);

    final seatY = h * 0.62;
    final kneeY = h * 0.72;
    final legPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round;

    final leftKnee = Offset(cx - w * 0.1, kneeY);
    final rightKnee = Offset(cx + w * 0.1, kneeY);
    final leftFoot = Offset(cx + w * 0.06, h * 0.8);
    final rightFoot = Offset(cx - w * 0.06, h * 0.8);

    final legL = Path()
      ..moveTo(cx - shoulderW * 0.35, hipY)
      ..quadraticBezierTo(cx - w * 0.16, seatY, leftKnee.dx, leftKnee.dy)
      ..quadraticBezierTo(cx - w * 0.02, h * 0.76, leftFoot.dx, leftFoot.dy);
    final legR = Path()
      ..moveTo(cx + shoulderW * 0.35, hipY)
      ..quadraticBezierTo(cx + w * 0.16, seatY, rightKnee.dx, rightKnee.dy)
      ..quadraticBezierTo(cx + w * 0.02, h * 0.76, rightFoot.dx, rightFoot.dy);

    canvas.drawPath(legL, legPaint);
    canvas.drawPath(legR, legPaint);
  }

  void _drawParticles(Canvas canvas, double w, double h, double cx) {
    final headCy = h * 0.3;
    final headR = w * 0.045;
    final headTop = headCy - headR;
    final topMargin = h * 0.06;
    final travel = max(headTop - topMargin, 1.0);

    for (var i = 0; i < _particleCount; i++) {
      final stagger = i / _particleCount;
      final u = (progress * 0.95 + stagger) % 1.0;
      final y = headTop - u * travel;
      final drift = sin(progress * 2 * pi * 1.8 + i * 1.1) * w * 0.018;
      final x = cx + drift + sin(i * 2.1) * w * 0.012;
      final opacity = (0.12 + 0.42 * (1 - u)) * (0.7 + 0.3 * sin(progress * 2 * pi * 2 + i));
      final paint = Paint()..color = C.accent.withValues(alpha: opacity.clamp(0.08, 0.55));
      canvas.drawCircle(Offset(x, y), 1.1 + 0.4 * (1 - u), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeditatorPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
