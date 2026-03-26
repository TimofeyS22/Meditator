import 'dart:math';

import 'package:flutter/material.dart';
import 'package:meditator/shared/utils/accessibility.dart';

class ParticleField extends StatefulWidget {
  final int count;
  final double maxRadius;
  final Color color;
  final bool twinkle;
  final bool drift;

  const ParticleField({
    super.key,
    this.count = 50,
    this.maxRadius = 1.5,
    this.color = Colors.white,
    this.twinkle = true,
    this.drift = true,
  });

  @override
  State<ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<ParticleField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    _particles = List.generate(widget.count, (_) {
      return _Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: rng.nextDouble() * widget.maxRadius + 0.3,
        phase: rng.nextDouble() * 2 * pi,
        baseOpacity: 0.3 + rng.nextDouble() * 0.5,
        driftSpeed: 0.005 + rng.nextDouble() * (0.02 - 0.005),
        driftAngle: rng.nextDouble() * 2 * pi,
      );
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final twinkle = widget.twinkle && !_reduceMotion;
    final drift = widget.drift && !_reduceMotion;
    final progress = _reduceMotion ? 0.0 : _controller.value;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              size: Size.infinite,
              painter: _ParticlePainter(
                particles: _particles,
                progress: progress,
                color: widget.color,
                twinkle: twinkle,
                drift: drift,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final double radius;
  final double phase;
  final double baseOpacity;
  final double driftSpeed;
  final double driftAngle;

  const _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
    required this.baseOpacity,
    required this.driftSpeed,
    required this.driftAngle,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Color color;
  final bool twinkle;
  final bool drift;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.color,
    required this.twinkle,
    required this.drift,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final animAngle = progress * 2 * pi;
    final paint = Paint();

    for (final p in particles) {
      final opacity = twinkle
          ? (p.baseOpacity + 0.3 * sin(animAngle + p.phase)).clamp(0.0, 1.0)
          : p.baseOpacity;

      paint.color = color.withValues(alpha: opacity);

      final Offset center;
      if (drift) {
        final dx = p.driftSpeed * cos(p.driftAngle);
        final dy = p.driftSpeed * sin(p.driftAngle);
        final px = ((p.x + dx * progress * 3) % 1.0) * size.width;
        final py = ((p.y + dy * progress * 3) % 1.0) * size.height;
        center = Offset(px, py);
      } else {
        center = Offset(p.x * size.width, p.y * size.height);
      }

      canvas.drawCircle(
        center,
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => twinkle || drift;
}
