import 'dart:math';

import 'package:flutter/material.dart';
import 'package:meditator/shared/utils/accessibility.dart';

const _kGravity = 0.008;
const _kWindStrength = 0.005;
const _kDamping = 0.97;
const _kStarChance = 0.003;
const _kMaxParticles = 150;
const _kTrailDots = 6;

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
  late final AnimationController _ctrl;
  final List<_Particle> _particles = [];
  final _rng = Random();
  final _sw = Stopwatch();
  var _elapsed = 0.0;
  var _reduceMotion = false;
  int _adaptiveCount = 0;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.count; i++) {
      _particles.add(_spawn(randomAge: true));
    }
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )
      ..addListener(_tick)
      ..repeat();
    _sw.start();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final screenSize = MediaQuery.of(context).size;
    final screenArea = screenSize.width * screenSize.height;
    final scaleFactor = (screenArea / 400000.0 * dpr / 2.0).clamp(0.3, 1.0);
    _adaptiveCount =
        (widget.count * scaleFactor).round().clamp(10, _kMaxParticles);
    final reduce = AccessibilityUtils.reduceMotion(context);
    if (_reduceMotion == reduce) return;
    _reduceMotion = reduce;
    if (reduce) {
      _ctrl.stop();
      _sw.stop();
    } else {
      _sw
        ..reset()
        ..start();
      _ctrl.repeat();
    }
  }

  void _tick() {
    if (_reduceMotion) return;
    final us = _sw.elapsedMicroseconds;
    _sw
      ..reset()
      ..start();
    final dt = (us / 1e6).clamp(0.0, 0.05);
    _elapsed += dt;
    _step(dt);
  }

  void _step(double dt) {
    final damping = pow(_kDamping, dt * 60).toDouble();
    final windX = sin(_elapsed * 0.27) * _kWindStrength;
    final windY = cos(_elapsed * 0.19) * _kWindStrength * 0.3;

    for (final p in _particles) {
      if (!widget.drift) continue;
      p.age += dt;
      if (p.isDead) continue;

      final df = p.depthFactor;

      // Gravity + wind
      p.vy += _kGravity * df * dt;
      p.vx += windX * df * dt;
      p.vy += windY * df * dt;

      // Sine-wave perturbation for organic floatiness
      p.vx += sin(_elapsed * p.sineFreq + p.phase) * p.sineAmp * dt;
      p.vy +=
          cos(_elapsed * p.sineFreq * 0.7 + p.phase) * p.sineAmp * 0.5 * dt;

      // Frame-rate-independent damping (shooting stars skip)
      if (!p.isStar) {
        p.vx *= damping;
        p.vy *= damping;
      }

      p.x += p.vx * dt;
      p.y += p.vy * dt;

      // Shooting stars die off-screen; normal particles wrap
      if (p.isStar) {
        if (p.x < -0.2 || p.x > 1.2 || p.y < -0.2 || p.y > 1.2) {
          p.age = p.maxAge;
        }
      } else {
        p.x = ((p.x % 1.0) + 1.0) % 1.0;
        p.y = ((p.y % 1.0) + 1.0) % 1.0;
      }
    }

    if (widget.drift) {
      _particles.removeWhere((p) => p.isDead);
      while (_particles.length < _adaptiveCount) {
        _particles.add(_spawn());
      }
      if (_rng.nextDouble() < _kStarChance &&
          _particles.length < _kMaxParticles) {
        _particles.add(_spawn(shooting: true));
      }
    }
  }

  _Particle _spawn({bool randomAge = false, bool shooting = false}) {
    if (shooting) {
      final a = pi * 0.08 + _rng.nextDouble() * pi * 0.25;
      final s = 0.4 + _rng.nextDouble() * 0.4;
      final right = _rng.nextBool();
      return _Particle(
        x: right ? _rng.nextDouble() * 0.1 : 0.9 + _rng.nextDouble() * 0.1,
        y: _rng.nextDouble() * 0.3,
        vx: cos(a) * s * (right ? 1.0 : -1.0),
        vy: sin(a) * s,
        radius: widget.maxRadius * (1.5 + _rng.nextDouble()),
        depth: 0.9 + _rng.nextDouble() * 0.1,
        phase: _rng.nextDouble() * 2 * pi,
        sineFreq: 0,
        sineAmp: 0,
        baseOpacity: 0.85 + _rng.nextDouble() * 0.15,
        maxAge: 0.8 + _rng.nextDouble() * 1.2,
        isStar: true,
      );
    }

    final depth = _rng.nextDouble();
    final df = 0.3 + depth * 0.7;
    final a = _rng.nextDouble() * 2 * pi;
    final s = (0.008 + _rng.nextDouble() * 0.018) * df;
    final maxAge = 6.0 + _rng.nextDouble() * 14.0;

    return _Particle(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      vx: cos(a) * s,
      vy: sin(a) * s,
      radius: (0.3 + _rng.nextDouble() * widget.maxRadius) * df,
      depth: depth,
      phase: _rng.nextDouble() * 2 * pi,
      sineFreq: 0.5 + _rng.nextDouble() * 2.0,
      sineAmp: 0.002 + _rng.nextDouble() * 0.008,
      baseOpacity: (0.15 + _rng.nextDouble() * 0.55) * df,
      maxAge: maxAge,
      age: randomAge ? _rng.nextDouble() * maxAge * 0.7 : 0.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            size: Size.infinite,
            painter: _ParticlePainter(
              particles: _particles,
              color: widget.color,
              elapsed: _elapsed,
              twinkle: widget.twinkle && !_reduceMotion,
              animating: !_reduceMotion,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

class _Particle {
  double x, y, vx, vy;
  double radius, depth, phase;
  double sineFreq, sineAmp;
  double baseOpacity;
  double age, maxAge;
  bool isStar;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.depth,
    required this.phase,
    required this.sineFreq,
    required this.sineAmp,
    required this.baseOpacity,
    required this.maxAge,
    this.age = 0,
    this.isStar = false,
  });

  /// 0.3 (far) .. 1.0 (close) — scales forces, size, brightness
  double get depthFactor => 0.3 + depth * 0.7;

  double get life => (1.0 - age / maxAge).clamp(0.0, 1.0);
  bool get isDead => age >= maxAge;
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.particles,
    required this.color,
    required this.elapsed,
    required this.twinkle,
    required this.animating,
  });

  final List<_Particle> particles;
  final Color color;
  final double elapsed;
  final bool twinkle;
  final bool animating;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final fill = Paint();
    final glow = Paint();

    for (final p in particles) {
      final life = p.life;
      if (life <= 0) continue;

      var alpha = p.baseOpacity;
      if (twinkle) alpha += 0.25 * sin(elapsed * 2.5 + p.phase);

      // Smooth fade-in (first 10% of lifespan) / fade-out (last 30%)
      final ageNorm = p.age / p.maxAge;
      alpha *= (ageNorm * 10.0).clamp(0.0, 1.0);
      alpha *= life < 0.3 ? life / 0.3 : 1.0;
      alpha = alpha.clamp(0.0, 1.0);
      if (alpha < 0.01) continue;

      final px = p.x * size.width;
      final py = p.y * size.height;
      final r = p.radius;

      if (p.isStar) _drawTrail(canvas, fill, px, py, p, alpha, size);

      // Bloom halo — brighter particles get a soft glow ring
      if (alpha > 0.3) {
        glow
          ..color = color.withValues(alpha: alpha * 0.25)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 3.5);
        canvas.drawCircle(Offset(px, py), r * 2.5, glow);
      }

      fill
        ..color = color.withValues(alpha: alpha)
        ..maskFilter = null;
      canvas.drawCircle(Offset(px, py), r, fill);
    }
  }

  void _drawTrail(
    Canvas canvas,
    Paint paint,
    double px,
    double py,
    _Particle p,
    double alpha,
    Size size,
  ) {
    final vxPx = p.vx * size.width;
    final vyPx = p.vy * size.height;
    final speed = sqrt(vxPx * vxPx + vyPx * vyPx);
    if (speed < 1.0) return;

    final inv = 1.0 / speed;
    final len = min(speed * 0.2, size.shortestSide * 0.15);
    final ndx = -vxPx * inv;
    final ndy = -vyPx * inv;

    for (var i = 1; i <= _kTrailDots; i++) {
      final t = i / _kTrailDots;
      final a = (alpha * (1.0 - t) * 0.5).clamp(0.0, 1.0);
      if (a < 0.01) continue;
      paint
        ..color = color.withValues(alpha: a)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.radius * (1.0 + t));
      canvas.drawCircle(
        Offset(px + ndx * len * t, py + ndy * len * t),
        p.radius * (1.0 - t * 0.7),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => animating || old.animating;
}
