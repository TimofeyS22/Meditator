import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';

enum OnboardingScene {
  welcome,
  goals,
  stress,
  preferences,
  finish,
}

class OnboardingIllustration extends StatefulWidget {
  const OnboardingIllustration({
    super.key,
    required this.scene,
    this.size = 240,
  });

  final OnboardingScene scene;
  final double size;

  @override
  State<OnboardingIllustration> createState() => _OnboardingIllustrationState();
}

class _OnboardingIllustrationState extends State<OnboardingIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = AccessibilityUtils.reduceMotion(context);
    if (reduce) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _progress {
    if (AccessibilityUtils.reduceMotion(context)) {
      return 0.5;
    }
    return _controller.value;
  }

  CustomPainter _painterFor(double p) {
    switch (widget.scene) {
      case OnboardingScene.welcome:
        return _WelcomePainter(progress: p);
      case OnboardingScene.goals:
        return _GoalsPainter(progress: p);
      case OnboardingScene.stress:
        return _StressPainter(progress: p);
      case OnboardingScene.preferences:
        return _PreferencesPainter(progress: p);
      case OnboardingScene.finish:
        return _FinishPainter(progress: p);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ExcludeSemantics(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _painterFor(_progress),
                size: Size(widget.size, widget.size),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WelcomePainter extends CustomPainter {
  _WelcomePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.58;
    final scale = size.shortestSide / 240;
    final breathe = 1.0 + 0.12 * math.sin(progress * math.pi * 2);

    final ringPaint = Paint()
      ..color = C.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * scale;

    for (var i = 0; i < 3; i++) {
      final baseR = (42 + i * 28) * scale * breathe;
      ringPaint.color = C.accent.withValues(alpha: 0.35 - i * 0.08);
      canvas.drawCircle(Offset(cx, cy), baseR, ringPaint);
    }

    final figure = Path();
    final headR = 10 * scale;
    figure.addOval(Rect.fromCircle(center: Offset(cx, cy - 52 * scale), radius: headR));
    figure.moveTo(cx - 22 * scale, cy - 38 * scale);
    figure.quadraticBezierTo(cx, cy - 28 * scale, cx + 22 * scale, cy - 38 * scale);
    figure.moveTo(cx, cy - 32 * scale);
    figure.lineTo(cx, cy + 8 * scale);
    figure.moveTo(cx - 18 * scale, cy - 8 * scale);
    figure.quadraticBezierTo(cx - 28 * scale, cy + 12 * scale, cx - 8 * scale, cy + 38 * scale);
    figure.moveTo(cx + 18 * scale, cy - 8 * scale);
    figure.quadraticBezierTo(cx + 28 * scale, cy + 12 * scale, cx + 8 * scale, cy + 38 * scale);
    figure.moveTo(cx - 32 * scale, cy + 42 * scale);
    figure.quadraticBezierTo(cx - 18 * scale, cy + 58 * scale, cx, cy + 48 * scale);
    figure.quadraticBezierTo(cx + 18 * scale, cy + 58 * scale, cx + 32 * scale, cy + 42 * scale);

    canvas.drawPath(
      figure,
      Paint()
        ..color = C.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final starPaint = Paint()..color = Colors.white;
    final phases = [0.0, 0.35, 0.62, 0.18, 0.8, 0.5, 0.12];
    final positions = <Offset>[
      Offset(cx - 68 * scale, cy - 92 * scale),
      Offset(cx + 12 * scale, cy - 108 * scale),
      Offset(cx + 72 * scale, cy - 78 * scale),
      Offset(cx - 48 * scale, cy - 118 * scale),
      Offset(cx + 52 * scale, cy - 112 * scale),
      Offset(cx - 8 * scale, cy - 128 * scale),
      Offset(cx + 88 * scale, cy - 98 * scale),
    ];
    for (var i = 0; i < positions.length; i++) {
      final tw = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(progress * math.pi * 2 * 2.2 + phases[i] * math.pi * 2));
      final rr = 2.2 * scale * (0.85 + 0.2 * tw);
      starPaint.color = Colors.white.withValues(alpha: tw);
      canvas.drawCircle(positions[i], rr, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WelcomePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _GoalsPainter extends CustomPainter {
  _GoalsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.52;
    final scale = size.shortestSide / 240;
    final r = 38 * scale;

    final thin = Paint()
      ..color = C.gold.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * scale;

    canvas.drawCircle(Offset(cx, cy), r, thin);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final x1 = cx + (r - 4 * scale) * math.cos(a);
      final y1 = cy + (r - 4 * scale) * math.sin(a);
      final x2 = cx + (r + 10 * scale) * math.cos(a);
      final y2 = cy + (r + 10 * scale) * math.sin(a);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), thin);
    }

    final needleAngle = math.sin(progress * math.pi * 2) * 0.38;
    final nLen = r * 0.72;
    final needle = Path()
      ..moveTo(cx, cy)
      ..lineTo(
        cx + nLen * math.cos(-math.pi / 2 + needleAngle),
        cy + nLen * math.sin(-math.pi / 2 + needleAngle),
      );
    canvas.drawPath(
      needle,
      Paint()
        ..color = C.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * scale
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(cx, cy), 3 * scale, Paint()..color = C.gold);

    final pathDefs = <Path>[];
    for (var i = 0; i < 4; i++) {
      final a = -math.pi * 0.35 + i * math.pi * 0.22;
      final p = Path();
      p.moveTo(cx + r * 0.85 * math.cos(a), cy + r * 0.85 * math.sin(a));
      p.lineTo(
        cx + size.width * 0.48 * math.cos(a),
        cy + size.width * 0.48 * math.sin(a),
      );
      pathDefs.add(p);
    }

    final dashPaint = Paint()
      ..color = C.primary.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * scale
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < pathDefs.length; i++) {
      final pm = pathDefs[i].computeMetrics().first;
      final t = ((progress + i * 0.22) % 1.0);
      final len = pm.length * t;
      final segment = pm.extractPath(0, len);
      _dashAlong(canvas, segment, 5 * scale, 4 * scale, dashPaint);
    }

    for (var i = 0; i < pathDefs.length; i++) {
      final pm = pathDefs[i].computeMetrics().first;
      final end = pm.getTangentForOffset(pm.length)?.position ?? Offset(cx, cy);
      final spark = 0.5 + 0.5 * math.sin(progress * math.pi * 2 * 3 + i * 1.7);
      canvas.drawCircle(
        end,
        3.2 * scale * spark,
        Paint()..color = C.accent.withValues(alpha: 0.4 + 0.5 * spark),
      );
    }
  }

  void _dashAlong(Canvas canvas, Path path, double dash, double gap, Paint base) {
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        final extract = m.extractPath(d, math.min(d + dash, m.length));
        canvas.drawPath(extract, base);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GoalsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _StressPainter extends CustomPainter {
  _StressPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 240;
    final calm = (math.cos(progress * math.pi * 2) + 1) * 0.5;
    final ampHigh = 14.0 * scale;
    final ampLow = 3.5 * scale;
    final freqHigh = 0.09;
    final freqLow = 0.035;
    final speedHigh = 14.0;
    final speedLow = 4.0;

    final moonY = 36 * scale;
    final moonCx = size.width * 0.72;
    final moonR = 18 * scale;
    canvas.drawCircle(
      Offset(moonCx, moonY),
      moonR * 1.8,
      Paint()
        ..color = C.primary.withAlpha(77)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(
      Offset(moonCx, moonY),
      moonR,
      Paint()
        ..color = C.calm.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(moonCx, moonY),
      moonR,
      Paint()
        ..color = C.calm.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * scale,
    );

    final wavePaint = Paint()
      ..color = C.calm.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round;

    final midY = size.height * 0.48;
    for (var w = 0; w < 3; w++) {
      final y0 = midY + w * 22 * scale;
      final amp = ui.lerpDouble(ampHigh, ampLow, calm)!;
      final freq = ui.lerpDouble(freqHigh, freqLow, calm)!;
      final spd = ui.lerpDouble(speedHigh, speedLow, calm)!;
      final path = Path()..moveTo(0, y0);
      for (var x = 0.0; x <= size.width; x += 2) {
        final y = y0 +
            amp *
                math.sin(x * freq * math.pi + progress * math.pi * 2 * spd / 8 + w * 0.8);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, wavePaint);

      final reflectY = y0 + 36 * scale;
      canvas.save();
      canvas.translate(0, 2 * reflectY);
      canvas.scale(1, -1);
      canvas.drawPath(
        path,
        Paint()
          ..color = C.calm.withValues(alpha: 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * scale
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _StressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _PreferencesPainter extends CustomPainter {
  _PreferencesPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.42;
    final scale = size.shortestSide / 240;

    final fork = Path();
    final stemW = 3.5 * scale;
    final tineH = 52 * scale;
    final gap = 14 * scale;
    fork.moveTo(cx - stemW, cy + tineH * 0.35);
    fork.lineTo(cx + stemW, cy + tineH * 0.35);
    fork.lineTo(cx + stemW, cy - tineH);
    fork.lineTo(cx + gap * 0.5, cy - tineH);
    fork.moveTo(cx - stemW, cy + tineH * 0.35);
    fork.lineTo(cx - stemW, cy - tineH);
    fork.lineTo(cx - gap * 0.5, cy - tineH);
    fork.moveTo(cx, cy + tineH * 0.35);
    fork.lineTo(cx, cy + tineH * 0.95);

    canvas.drawPath(
      fork,
      Paint()
        ..color = C.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final arcPaint = Paint()
      ..color = C.primary.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale;

    for (var i = 1; i <= 4; i++) {
      final sweep = 0.55 + 0.08 * math.sin(progress * math.pi * 2 + i);
      final rect = Rect.fromCenter(
        center: Offset(cx, cy - tineH * 0.85),
        width: 28 * scale * i,
        height: 28 * scale * i,
      );
      canvas.drawArc(rect, -math.pi * 0.85, sweep, false, arcPaint);
    }

    final notes = <(Offset, double)>[
      (Offset(cx - 62 * scale, cy - 18 * scale), 0.0),
      (Offset(cx + 58 * scale, cy + 8 * scale), 0.4),
      (Offset(cx - 48 * scale, cy + 52 * scale), 0.8),
      (Offset(cx + 52 * scale, cy - 42 * scale), 0.2),
    ];
    for (final (o, ph) in notes) {
      final bob = 6 * scale * math.sin(progress * math.pi * 2 * 1.3 + ph * math.pi * 2);
      _drawEighthNote(canvas, o + Offset(0, bob), scale);
    }

    final barY = size.height * 0.82;
    final barW = 5 * scale;
    final gapB = 8 * scale;
    final startX = cx - (5 * barW + 4 * gapB) * 0.5;
    for (var i = 0; i < 5; i++) {
      final h = (18 + 22 * (0.5 + 0.5 * math.sin(progress * math.pi * 2 * 2 + i * 0.9))) * scale;
      final x = startX + i * (barW + gapB);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, barY - h, barW, h),
        Radius.circular(2 * scale),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..color = C.accent.withValues(alpha: 0.45 + 0.35 * (h / (40 * scale)))
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawEighthNote(Canvas canvas, Offset o, double scale) {
    final head = Rect.fromCenter(center: o + Offset(-2 * scale, 6 * scale), width: 9 * scale, height: 7 * scale);
    canvas.drawOval(
      head,
      Paint()
        ..color = C.gold.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill,
    );
    canvas.drawLine(
      o + Offset(2 * scale, 2 * scale),
      o + Offset(2 * scale, -22 * scale),
      Paint()
        ..color = C.gold
        ..strokeWidth = 1.8 * scale
        ..strokeCap = StrokeCap.round,
    );
    final flag = Path()
      ..moveTo(o.dx + 2 * scale, o.dy - 22 * scale)
      ..quadraticBezierTo(
        o.dx + 18 * scale,
        o.dy - 18 * scale,
        o.dx + 14 * scale,
        o.dy - 6 * scale,
      );
    canvas.drawPath(
      flag,
      Paint()
        ..color = C.gold.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * scale,
    );
  }

  @override
  bool shouldRepaint(covariant _PreferencesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _FinishPainter extends CustomPainter {
  _FinishPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 240;
    final skyRect = Offset.zero & size;
    final skyPaint = Paint()..shader = C.gradientAurora.createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    final horizonY = size.height * (0.62 + 0.02 * math.sin(progress * math.pi * 2));
    canvas.drawLine(
      Offset(0, horizonY),
      Offset(size.width, horizonY),
      Paint()
        ..color = C.accent.withValues(alpha: 0.65)
        ..strokeWidth = 2 * scale,
    );

    final sunBaseY = horizonY + 28 * scale;
    final sunY = sunBaseY - (22 + 18 * math.sin(progress * math.pi * 2)) * scale;
    final sunX = size.width * 0.38;
    final sunR = 22 * scale;

    for (var i = 0; i < 12; i++) {
      final a = i * math.pi * 2 / 12 + progress * math.pi * 0.15;
      final len = (18 + 8 * math.sin(progress * math.pi * 2 + i)) * scale;
      final x1 = sunX + sunR * 1.05 * math.cos(a);
      final y1 = sunY + sunR * 1.05 * math.sin(a);
      final x2 = sunX + (sunR + len) * math.cos(a);
      final y2 = sunY + (sunR + len) * math.sin(a);
      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..color = C.warm.withValues(alpha: 0.35 + 0.25 * (0.5 + 0.5 * math.sin(progress * math.pi * 2 + i)))
          ..strokeWidth = 2 * scale
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawCircle(
      Offset(sunX, sunY),
      sunR,
      Paint()..color = C.gold.withValues(alpha: 0.95),
    );
    canvas.drawCircle(
      Offset(sunX, sunY),
      sunR * 1.15,
      Paint()
        ..color = C.gold.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * scale,
    );

    final birdPaint = Paint()
      ..color = C.primary.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round;

    for (var b = 0; b < 3; b++) {
      final bx = (progress + b * 0.31) % 1.0 * size.width * 1.15 - size.width * 0.08;
      final by = horizonY - (35 + b * 14) * scale + 6 * scale * math.sin(progress * math.pi * 2 + b);
      final bird = Path()
        ..moveTo(bx, by)
        ..lineTo(bx + 10 * scale, by - 5 * scale)
        ..lineTo(bx + 20 * scale, by);
      canvas.drawPath(bird, birdPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FinishPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
