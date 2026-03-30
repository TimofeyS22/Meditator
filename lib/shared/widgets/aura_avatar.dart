import 'dart:math';

import 'package:flutter/material.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';

class AuraAvatar extends StatefulWidget {
  const AuraAvatar({
    super.key,
    this.size = 80,
    this.isThinking = false,
    this.mood,
  });

  final double size;
  final bool isThinking;
  final String? mood;

  @override
  State<AuraAvatar> createState() => _AuraAvatarState();
}

class _AuraAvatarState extends State<AuraAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _orbitCtrl;
  late final AnimationController _breatheCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _glowCtrl;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4700),
    )..repeat();
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 13),
    )..repeat();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7300),
    )..repeat();
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    _breatheCtrl.dispose();
    _particleCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rm = AccessibilityUtils.reduceMotion(context);
    if (_reduceMotion == rm) return;
    _reduceMotion = rm;
    for (final c in [_orbitCtrl, _breatheCtrl, _particleCtrl, _glowCtrl]) {
      if (_reduceMotion) {
        if (c.isAnimating) c.stop();
      } else {
        if (!c.isAnimating) c.repeat();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _orbitCtrl,
            _breatheCtrl,
            _particleCtrl,
            _glowCtrl,
          ]),
          builder: (context, _) {
            final rm = _reduceMotion;
            return CustomPaint(
              size: Size.square(widget.size),
              painter: _AuraFacePainter(
                orbitT: rm ? 0.0 : _orbitCtrl.value,
                breatheT: rm ? 0.0 : _breatheCtrl.value,
                particleT: rm ? 0.0 : _particleCtrl.value,
                glowT: rm ? 0.0 : _glowCtrl.value,
                isThinking: widget.isThinking,
                mood: widget.mood,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter – multi-layer organic face with orbital rings, halo particles,
// almond eyes with iris gradient, organic mouth, and reactive glow.
// ─────────────────────────────────────────────────────────────────────────────

class _AuraFacePainter extends CustomPainter {
  _AuraFacePainter({
    required this.orbitT,
    required this.breatheT,
    required this.particleT,
    required this.glowT,
    required this.isThinking,
    required this.mood,
  });

  final double orbitT;
  final double breatheT;
  final double particleT;
  final double glowT;
  final bool isThinking;
  final String? mood;

  static const _tau = 2 * pi;

  Color get _col1 => switch (mood) {
        'calm' => C.calm,
        'anxious' => C.warm,
        'happy' => C.gold,
        _ => C.primary,
      };

  Color get _col2 => switch (mood) {
        'calm' => C.primary,
        'anxious' => C.rose,
        'happy' => C.accent,
        _ => C.accent,
      };

  Color get _col3 => switch (mood) {
        'calm' => C.accent,
        'anxious' => C.gold,
        'happy' => C.rose,
        _ => C.calm,
      };

  // ── Main entry ──────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final s = size.shortestSide;
    final r = s / 2;

    _drawGlowRings(canvas, c, r);
    _drawBackground(canvas, c, r);
    _drawOrbitalRings(canvas, c, r);
    _drawHaloParticles(canvas, c, r);
    if (isThinking) _drawThinkingDots(canvas, c, r);
    _drawEyes(canvas, c, s);
    _drawMouth(canvas, c, s);
  }

  // ── Reactive glow rings ─────────────────────────────────────────────────

  void _drawGlowRings(Canvas canvas, Offset c, double r) {
    final p1 = 0.5 + 0.5 * sin(glowT * _tau);
    final p2 = 0.5 + 0.5 * sin(glowT * _tau * 1.31 + 1.2);
    final p3 = 0.5 + 0.5 * sin(breatheT * _tau + 2.5);

    canvas.drawCircle(
      c,
      r * 1.15,
      Paint()
        ..color = _col1.withValues(alpha: 0.04 + 0.06 * p1)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.18),
    );
    canvas.drawCircle(
      c,
      r * 1.06,
      Paint()
        ..color = _col2.withValues(alpha: 0.03 + 0.05 * p2)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.13),
    );
    canvas.drawCircle(
      c,
      r * 0.96,
      Paint()
        ..color = _col3.withValues(alpha: 0.025 + 0.04 * p3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.09),
    );
  }

  // ── Background sphere ───────────────────────────────────────────────────

  void _drawBackground(Canvas canvas, Offset c, double r) {
    final breathe = sin(breatheT * _tau);
    final rr = r * (0.96 + 0.018 * breathe);
    final shift = Offset(
      r * 0.008 * sin(breatheT * _tau * 0.7),
      r * 0.01 * breathe,
    );
    final center = c + shift;
    final rect = Rect.fromCircle(center: center, radius: rr * 1.02);
    canvas.drawCircle(
      center,
      rr,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _col1.withValues(alpha: 0.52),
            _col1.withValues(alpha: 0.24),
            _col2.withValues(alpha: 0.08),
            _col1.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.42, 0.76, 1.0],
        ).createShader(rect),
    );
  }

  // ── 5-layer orbital ring system ─────────────────────────────────────────

  void _drawOrbitalRings(Canvas canvas, Offset c, double r) {
    final speed = isThinking ? 1.8 : 1.0;
    final t = orbitT * _tau * speed;
    final sw = max(0.8, r * 0.028);

    const radii = [0.24, 0.35, 0.46, 0.58, 0.72];
    const speeds = [1.0, -1.37, 0.73, -0.53, 0.41];
    const segs = [3, 4, 3, 5, 4];
    const sweepFracs = [0.40, 0.30, 0.38, 0.26, 0.32];
    const alphas = [0.13, 0.16, 0.14, 0.11, 0.09];
    final colors = [_col2, Colors.white, _col1, _col3, _col2];

    for (var i = 0; i < 5; i++) {
      final paint = Paint()
        ..color = colors[i].withValues(alpha: alphas[i])
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round;
      final rect = Rect.fromCircle(center: c, radius: r * radii[i]);
      final step = _tau / segs[i];
      for (var j = 0; j < segs[i]; j++) {
        final sweep = step * sweepFracs[i];
        final start = t * speeds[i] + j * step + (step - sweep) / 2;
        canvas.drawArc(rect, start, sweep, false, paint);
      }
    }
  }

  // ── Halo particle system (3D-projected orbits) ──────────────────────────

  void _drawHaloParticles(Canvas canvas, Offset c, double r) {
    const count = 16;
    final colors = [_col1, _col2, _col3];

    for (var i = 0; i < count; i++) {
      final orbitR = r * (0.48 + 0.42 * ((i * 7 % 13) / 12));
      final speed = 0.25 + 0.65 * ((i * 11 % 13) / 12);
      final phase = i * 2.399; // golden-angle spacing
      final tilt = 0.3 + 0.5 * ((i * 5 % 11) / 10);
      final baseSize = r * (0.018 + 0.022 * ((i * 3 % 7) / 6));

      final angle = particleT * _tau * speed + phase;
      final px = c.dx + orbitR * cos(angle);
      final yFlat = orbitR * sin(angle);
      final py = c.dy + yFlat * cos(tilt);
      final z = yFlat * sin(tilt);

      final depth = (z / orbitR + 1) / 2; // 0 = far, 1 = near
      final twinkle = 0.6 + 0.4 * sin(particleT * _tau * 2.1 + i * 1.73);
      final alpha = (0.12 + 0.5 * depth) * twinkle;
      final sz = baseSize * (0.5 + 0.5 * depth);

      canvas.drawCircle(
        Offset(px, py),
        sz,
        Paint()
          ..color = colors[i % 3].withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sz * 0.6),
      );
    }
  }

  // ── Thinking dots ───────────────────────────────────────────────────────

  void _drawThinkingDots(Canvas canvas, Offset c, double r) {
    final pulse = 0.35 + 0.5 * sin(breatheT * _tau * 2.8);
    final paint = Paint()..color = _col2.withValues(alpha: pulse * 0.85);
    final t = orbitT * _tau * 1.8;
    const ringRadii = [0.35, 0.46, 0.58, 0.72];
    const ringSpd = [1.0, -1.37, 0.73, -0.53];

    for (var ring = 0; ring < 4; ring++) {
      final rr = r * ringRadii[ring];
      final rot = t * ringSpd[ring];
      final dots = 3 + ring % 2;
      for (var k = 0; k < dots; k++) {
        final a = rot + k * (_tau / dots) + pi / 3;
        final sz = max(0.8, r * 0.03) +
            max(0.4, r * 0.01) * sin(breatheT * _tau * 3.5 + k + ring);
        canvas.drawCircle(
          Offset(c.dx + rr * cos(a), c.dy + rr * sin(a)),
          sz,
          paint,
        );
      }
    }
  }

  // ── Eye system ──────────────────────────────────────────────────────────

  void _drawEyes(Canvas canvas, Offset c, double s) {
    final eyeY = c.dy - s * 0.065;
    final eyeSep = s * 0.115;
    final eyeW = s * 0.095;
    final eyeH = eyeW * 0.55;

    // Variable blink from two incommensurate-period sources (LCM ≈ 130 s)
    final p1 = breatheT * _tau * 0.85;
    final p2 = orbitT * _tau * 0.7 + 1.9;
    final spike1 = pow((1.0 - sin(p1)) / 2.0, 22.0).toDouble();
    final spike2 = pow((1.0 - sin(p2)) / 2.0, 28.0).toDouble();
    final openness = 1.0 - max(spike1, spike2) * 0.95;

    final pupilScale = isThinking ? 1.35 : 1.0;

    for (final sign in [-1.0, 1.0]) {
      _drawAlmondEye(
        canvas,
        Offset(c.dx + sign * eyeSep, eyeY),
        eyeW,
        eyeH * openness,
        pupilScale,
      );
    }
  }

  void _drawAlmondEye(
    Canvas canvas,
    Offset center,
    double w,
    double h,
    double pupilScale,
  ) {
    final lineSw = max(0.6, w * 0.1);

    if (h < w * 0.05) {
      canvas.drawLine(
        Offset(center.dx - w * 0.45, center.dy),
        Offset(center.dx + w * 0.45, center.dy),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..strokeWidth = lineSw
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    final hh = max(h, w * 0.06);

    // Almond path via opposing cubic béziers
    final path = Path()
      ..moveTo(center.dx - w / 2, center.dy)
      ..cubicTo(
        center.dx - w * 0.22,
        center.dy - hh * 1.05,
        center.dx + w * 0.22,
        center.dy - hh * 1.05,
        center.dx + w / 2,
        center.dy,
      )
      ..cubicTo(
        center.dx + w * 0.22,
        center.dy + hh * 0.72,
        center.dx - w * 0.22,
        center.dy + hh * 0.72,
        center.dx - w / 2,
        center.dy,
      )
      ..close();

    // Outer luminous glow
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.08),
    );

    // Translucent sclera fill
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );

    // Clip to eye shape for iris / pupil / specular
    canvas.save();
    canvas.clipPath(path);

    // Iris with mood-tinted radial gradient
    final irisR = min(w * 0.24, hh * 0.68) * pupilScale;
    final irisRect = Rect.fromCircle(center: center, radius: irisR);
    canvas.drawCircle(
      center,
      irisR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _col1.withValues(alpha: 0.9),
            _col2.withValues(alpha: 0.6),
            Colors.white.withValues(alpha: 0.22),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(irisRect),
    );

    // Pupil (dilates when thinking)
    canvas.drawCircle(
      center,
      irisR * 0.4 * pupilScale,
      Paint()..color = const Color(0xFF0C0C24).withValues(alpha: 0.85),
    );

    // Specular highlight
    final specOff = irisR * 0.24;
    canvas.drawCircle(
      Offset(center.dx - specOff, center.dy - specOff),
      irisR * 0.15,
      Paint()..color = Colors.white.withValues(alpha: 0.88),
    );

    canvas.restore();
  }

  // ── Mouth ───────────────────────────────────────────────────────────────

  void _drawMouth(Canvas canvas, Offset c, double s) {
    final breathe = sin(breatheT * _tau);
    final mouthY = c.dy + s * 0.10 + s * 0.003 * breathe;
    final mouthW = s * 0.15;
    final curve = s * 0.055 + s * 0.008 * breathe;

    final path = Path()
      ..moveTo(c.dx - mouthW / 2, mouthY)
      ..cubicTo(
        c.dx - mouthW * 0.25,
        mouthY + curve,
        c.dx + mouthW * 0.25,
        mouthY + curve,
        c.dx + mouthW / 2,
        mouthY,
      );

    // Soft glow layer
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(3.0, s * 0.04)
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.015),
    );

    // Crisp stroke
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18 + 0.05 * breathe)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, s * 0.016)
        ..strokeCap = StrokeCap.round,
    );
  }

  // ── Repaint ─────────────────────────────────────────────────────────────

  @override
  bool shouldRepaint(covariant _AuraFacePainter old) =>
      old.orbitT != orbitT ||
      old.breatheT != breatheT ||
      old.particleT != particleT ||
      old.glowT != glowT ||
      old.isThinking != isThinking ||
      old.mood != mood;
}
