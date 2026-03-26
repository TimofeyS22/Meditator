import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meditator/app/theme.dart';

class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({
    super.key,
    this.particleCount = 80,
    this.duration = const Duration(milliseconds: 2500),
    this.onComplete,
  });

  final int particleCount;
  final Duration duration;
  final VoidCallback? onComplete;

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_ConfettiParticle> _particles;

  static const _colors = [
    C.primary,
    C.accent,
    C.gold,
    C.rose,
    C.warm,
    C.accentLight,
  ];

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();

    final rng = Random();
    _particles = List.generate(widget.particleCount, (_) {
      return _ConfettiParticle(
        x: 0.3 + rng.nextDouble() * 0.4,
        y: 0.5 + rng.nextDouble() * 0.1,
        vx: (rng.nextDouble() - 0.5) * 1.8,
        vy: -(1.5 + rng.nextDouble() * 2.5),
        rotation: rng.nextDouble() * 2 * pi,
        rotationSpeed: (rng.nextDouble() - 0.5) * 8,
        width: 4.0 + rng.nextDouble() * 6,
        height: 2.0 + rng.nextDouble() * 4,
        color: _colors[rng.nextInt(_colors.length)],
        delay: rng.nextDouble() * 0.15,
      );
    });

    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..forward()
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onComplete?.call();
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(
              particles: _particles,
              progress: _ctrl.value,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfettiParticle {
  final double x, y, vx, vy;
  final double rotation, rotationSpeed;
  final double width, height;
  final Color color;
  final double delay;

  const _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.width,
    required this.height,
    required this.color,
    required this.delay,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  static const double _gravity = 4.0;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (final p in particles) {
      final t = ((progress - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final x = (p.x + p.vx * t) * size.width;
      final y = (p.y + p.vy * t + 0.5 * _gravity * t * t) * size.height;
      final rot = p.rotation + p.rotationSpeed * t;
      final alpha = (1.0 - t * t).clamp(0.0, 1.0);

      paint.color = p.color.withValues(alpha: alpha * 0.85);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.width, height: p.height),
          const Radius.circular(1.0),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
