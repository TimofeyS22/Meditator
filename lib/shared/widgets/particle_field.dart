import 'dart:math';
import 'package:flutter/material.dart';

/// Animated particle layer with state-specific behavior.
///
/// Use [speed] to control movement multiplier (1.0 = normal, 1.6 = overload fast).
/// Set [chaotic] to true for random jitter (anxiety/overload visual mode).
class ParticleField extends StatefulWidget {
  final int count;
  final double maxRadius;
  final double minRadius;
  final Color color;
  final double speed;
  final double alpha;
  final bool chaotic;

  const ParticleField({
    super.key,
    this.count = 40,
    this.maxRadius = 1.5,
    this.minRadius = 0.3,
    this.color = Colors.white,
    this.speed = 1.0,
    this.alpha = 1.0,
    this.chaotic = false,
  });

  @override
  State<ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<ParticleField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _regenerate();
  }

  @override
  void didUpdateWidget(ParticleField old) {
    super.didUpdateWidget(old);
    if (widget.count != old.count) _regenerate();
  }

  void _regenerate() {
    final rng = Random(99);
    _particles = List.generate(widget.count, (_) => _Particle.random(rng));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _ParticlePainter(
            progress: _ctrl.value,
            particles: _particles,
            maxRadius: widget.maxRadius,
            minRadius: widget.minRadius,
            color: widget.color,
            speed: widget.speed,
            alpha: widget.alpha,
            chaotic: widget.chaotic,
          ),
        ),
      ),
    );
  }
}

class _Particle {
  final double x, y, radius, baseAlpha, driftX, driftY, phase, speed;

  const _Particle({
    required this.x, required this.y,
    required this.radius, required this.baseAlpha,
    required this.driftX, required this.driftY,
    required this.phase, required this.speed,
  });

  factory _Particle.random(Random rng) => _Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 0.3 + rng.nextDouble() * 0.7,
        baseAlpha: 0.15 + rng.nextDouble() * 0.5,
        driftX: (rng.nextDouble() - 0.5) * 0.03,
        driftY: (rng.nextDouble() - 0.5) * 0.02,
        phase: rng.nextDouble() * 2 * pi,
        speed: 0.3 + rng.nextDouble() * 0.7,
      );
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;
  final double maxRadius;
  final double minRadius;
  final Color color;
  final double speed;
  final double alpha;
  final bool chaotic;

  _ParticlePainter({
    required this.progress,
    required this.particles,
    required this.maxRadius,
    required this.minRadius,
    required this.color,
    required this.speed,
    required this.alpha,
    required this.chaotic,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * pi;
    final paint = Paint();

    for (final p in particles) {
      final twinkle = (sin(t * p.speed * speed + p.phase) + 1.0) * 0.5;

      double px = (p.x + p.driftX * sin(t * 0.3 * speed + p.phase)) % 1.0;
      double py = (p.y + p.driftY * cos(t * 0.2 * speed + p.phase)) % 1.0;

      if (chaotic) {
        final jx = 0.012 * sin(t * 2.7 * p.speed + p.phase * 3.14);
        final jy = 0.010 * cos(t * 3.1 * p.speed + p.phase * 2.71);
        px = (px + jx) % 1.0;
        py = (py + jy) % 1.0;
      }

      final a = (p.baseAlpha * (0.3 + 0.7 * twinkle) * alpha).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: a);

      final r = minRadius + p.radius * (maxRadius - minRadius);
      canvas.drawCircle(Offset(px * size.width, py * size.height), r, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.progress != progress || old.speed != speed || old.chaotic != chaotic ||
      old.color != color || old.alpha != alpha ||
      old.maxRadius != maxRadius || old.minRadius != minRadius;
}
