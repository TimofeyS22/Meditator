import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/core/auth/auth_service.dart';

// ─── Spec constants ──────────────────────────────────────────────────────────

const _violet = Color(0xFFA78BFA);
const _cosmosCenter = Color(0xFF1E1B4B);
const _cosmosEdge = Color(0xFF020617);

const _easeOutCubic = Curves.easeOutCubic;
const _easeInOutSine = Cubic(0.37, 0.0, 0.63, 1.0);
const _materialEase = Cubic(0.4, 0.0, 0.2, 1.0);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Scene 2: light appear
  late final AnimationController _lightCtrl;
  // Scene 2+: breathing loop
  late final AnimationController _breathCtrl;
  // Scene 3: gradient reveal
  late final AnimationController _gradCtrl;
  // Scene 3: particle stagger
  late final AnimationController _particleCtrl;
  // Scene 3+: cosmos drift (infinite)
  late final AnimationController _cosmosCtrl;

  late final List<_Particle> _particles;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    _particles = List.generate(35, (i) => _Particle.random(rng, i, 35));

    _lightCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    );
    _breathCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400),
    );
    _gradCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000),
    );
    _particleCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2500),
    );
    _cosmosCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 20),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    final auth = ref.read(authProvider);
    final isReturning = auth.status == AuthStatus.authenticated && auth.isOnboarded;

    // Returning users: shortened 3s splash. New users: full 8s experience.
    if (isReturning) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      _lightCtrl.forward();
      _breathCtrl.repeat(reverse: true);
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      _gradCtrl.forward();
      _particleCtrl.forward();
      _cosmosCtrl.repeat();
      await Future.delayed(const Duration(milliseconds: 1500));
    } else {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      _lightCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      _breathCtrl.repeat(reverse: true);
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      _gradCtrl.forward();
      _particleCtrl.forward();
      _cosmosCtrl.repeat();
      await Future.delayed(const Duration(milliseconds: 4200));
    }

    if (!mounted || _navigated) return;
    _navigated = true;

    if (isReturning) {
      context.go('/home');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _lightCtrl.dispose();
    _breathCtrl.dispose();
    _gradCtrl.dispose();
    _particleCtrl.dispose();
    _cosmosCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _lightCtrl, _breathCtrl, _gradCtrl, _particleCtrl, _cosmosCtrl,
        ]),
        builder: (context, _) {
          final lightT = _easeOutCubic.transform(_lightCtrl.value);
          final breath = _easeInOutSine.transform(_breathCtrl.value);
          final gradT = _materialEase.transform(_gradCtrl.value);
          final stagger = _particleCtrl.value;
          final cosmos = _cosmosCtrl.value;

          final lightScale = (0.25 + 0.75 * lightT) * (1.0 + 0.08 * breath);
          final glowBlur = 12.0 + 20.0 * lightT + 8.0 * breath;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Cosmos layer (gradient + particles)
              if (gradT > 0)
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _CosmosPainter(
                      gradientAlpha: gradT,
                      stagger: stagger,
                      time: cosmos,
                      particles: _particles,
                      breath: breath,
                    ),
                  ),
                ),

              // Central light
              Center(
                child: Opacity(
                  opacity: lightT,
                  child: Transform.scale(
                    scale: lightScale,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.9),
                            _violet,
                            _violet.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _violet.withValues(alpha: 0.6 * lightT),
                            blurRadius: glowBlur,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: _violet.withValues(alpha: 0.2 * lightT),
                            blurRadius: glowBlur * 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Particle data ───────────────────────────────────────────────────────────

class _Particle {
  final double x, y;
  final double size;
  final double baseAlpha;
  final double driftAmpX, driftAmpY;
  final double driftFreqX, driftFreqY;
  final double phase;
  final int layer;
  final double staggerThreshold;

  const _Particle({
    required this.x, required this.y,
    required this.size, required this.baseAlpha,
    required this.driftAmpX, required this.driftAmpY,
    required this.driftFreqX, required this.driftFreqY,
    required this.phase, required this.layer,
    required this.staggerThreshold,
  });

  factory _Particle.random(Random rng, int index, int total) {
    return _Particle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      size: 1.0 + rng.nextDouble() * 2.0,
      baseAlpha: 0.2 + rng.nextDouble() * 0.4,
      driftAmpX: 0.01 + rng.nextDouble() * 0.04,
      driftAmpY: 0.01 + rng.nextDouble() * 0.03,
      driftFreqX: 0.5 + rng.nextDouble() * 1.5,
      driftFreqY: 0.5 + rng.nextDouble() * 1.5,
      phase: rng.nextDouble() * 2 * pi,
      layer: rng.nextInt(3),
      staggerThreshold: index / total * 0.75,
    );
  }

  static const layerSpeeds = [0.5, 1.0, 1.5];
}

// ─── Cosmos painter ──────────────────────────────────────────────────────────

class _CosmosPainter extends CustomPainter {
  final double gradientAlpha;
  final double stagger;
  final double time;
  final List<_Particle> particles;
  final double breath;

  _CosmosPainter({
    required this.gradientAlpha,
    required this.stagger,
    required this.time,
    required this.particles,
    required this.breath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Radial gradient: center #1E1B4B → outer #020617
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            _cosmosCenter.withValues(alpha: gradientAlpha),
            _cosmosEdge.withValues(alpha: gradientAlpha),
          ],
        ).createShader(rect),
    );

    // Particles
    final t = time * 2 * pi;
    final paint = Paint();

    for (final p in particles) {
      final particleFade = ((stagger - p.staggerThreshold) / 0.25).clamp(0.0, 1.0);
      if (particleFade <= 0) continue;

      final speedMul = _Particle.layerSpeeds[p.layer];
      final px = (p.x + sin(t * p.driftFreqX * speedMul + p.phase) * p.driftAmpX) % 1.0;
      final py = (p.y + cos(t * p.driftFreqY * speedMul + p.phase) * p.driftAmpY) % 1.0;

      final twinkle = (sin(t * 1.5 * speedMul + p.phase) + 1.0) * 0.5;
      final alpha = (p.baseAlpha * (0.4 + 0.6 * twinkle) * particleFade * gradientAlpha)
          .clamp(0.0, 1.0);

      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(px * size.width, py * size.height),
        p.size * (0.8 + 0.2 * breath),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CosmosPainter old) =>
      old.gradientAlpha != gradientAlpha ||
      old.stagger != stagger ||
      old.time != time ||
      old.breath != breath;
}
