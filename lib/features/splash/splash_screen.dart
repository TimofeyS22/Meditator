import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _main;
  late final AnimationController _loop;
  bool _navigated = false;
  bool _sessionReady = false;
  String _targetRoute = '/onboarding';

  @override
  void initState() {
    super.initState();
    _main = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _resolveTarget();
    _main.forward();
    _main.addStatusListener((s) {
      if (s == AnimationStatus.completed) _tryNavigate();
    });
  }

  Future<void> _resolveTarget() async {
    try {
      await AuthService.instance.tryRestoreSession();
    } catch (_) {}
    if (AuthService.instance.currentUser != null) {
      _targetRoute = '/practice';
    } else {
      final prefs = await SharedPreferences.getInstance();
      final onboarded = prefs.getBool('onboarding_done') == true;
      _targetRoute = onboarded ? '/login' : '/onboarding';
    }
    _sessionReady = true;
    _tryNavigate();
  }

  void _tryNavigate() {
    if (_navigated || !_sessionReady || !_main.isCompleted || !mounted) return;
    _navigated = true;
    context.go(_targetRoute);
  }

  @override
  void dispose() {
    _main.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: AnimatedBuilder(
        animation: Listenable.merge([_main, _loop]),
        builder: (_, __) {
          final p = _main.value;
          final l = _loop.value;

          final orbFade =
              Curves.easeOut.transform((p * 4.0).clamp(0.0, 1.0));
          final orbScale = lerpDouble(0.5, 1.0, orbFade)!;
          final ringT =
              Curves.easeOutCubic.transform(((p - 0.08) * 2.2).clamp(0.0, 1.0));
          final titleFade =
              Curves.easeOut.transform(((p - 0.30) * 3.5).clamp(0.0, 1.0));
          final subFade =
              Curves.easeOut.transform(((p - 0.45) * 3.5).clamp(0.0, 1.0));
          final exitFade = p > 0.82
              ? 1.0 - ((p - 0.82) / 0.18).clamp(0.0, 1.0)
              : 1.0;
          final breathe = 0.5 + 0.5 * math.sin(l * math.pi * 2);

          return Opacity(
            opacity: exitFade,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _SkyPainter(t: l, breathe: breathe),
                  size: mq,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: orbScale,
                        child: Opacity(
                          opacity: orbFade,
                          child: SizedBox(
                            width: 120,
                            height: 120,
                            child: CustomPaint(
                              painter: _OrbPainter(
                                ring: ringT,
                                breathe: breathe,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Opacity(
                        opacity: titleFade,
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - titleFade)),
                          child: Text(
                            'Meditator',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              color: Colors.white,
                              letterSpacing: 3.0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: subFade,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - subFade)),
                          child: Text(
                            'пространство для разума',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.4),
                              letterSpacing: 4.0,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.ring, required this.breathe});
  final double ring;
  final double breathe;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final c = Offset(cx, cy);
    final r = size.shortestSide * 0.28;

    final outerGlowR = r * (2.0 + 0.25 * breathe);
    canvas.drawCircle(
      c,
      outerGlowR,
      Paint()
        ..shader = RadialGradient(colors: [
          C.primary.withValues(alpha: 0.15 + 0.05 * breathe),
          C.accent.withValues(alpha: 0.04),
          Colors.transparent,
        ], stops: const [
          0.0,
          0.4,
          1.0
        ]).createShader(Rect.fromCircle(center: c, radius: outerGlowR)),
    );

    final coreR = r * (1.0 + 0.06 * breathe);
    canvas.drawCircle(
      c,
      coreR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.25),
          focal: const Alignment(-0.1, -0.1),
          focalRadius: 0.02,
          colors: [
            Colors.white.withValues(alpha: 0.35),
            C.accent.withValues(alpha: 0.5),
            C.primary.withValues(alpha: 0.35),
            C.primary.withValues(alpha: 0.1),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: coreR)),
    );

    canvas.drawCircle(
      c,
      coreR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    for (var i = 0; i < 3; i++) {
      final rr = r * (1.4 + i * 0.4) * ring;
      final a = (0.18 - i * 0.05) * ring;
      if (a <= 0) continue;
      canvas.drawCircle(
        c,
        rr,
        Paint()
          ..color = C.accent.withValues(alpha: a.clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter o) =>
      o.ring != ring || o.breathe != breathe;
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.t, required this.breathe});
  final double t;
  final double breathe;

  static final _stars = List.generate(80, (i) {
    final rng = math.Random(i * 31 + 13);
    return (
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      r: 0.3 + rng.nextDouble() * 1.2,
      phase: rng.nextDouble(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.38;

    void glow(Offset c, double r, Color col, double a) {
      final rr = r * (1.0 + 0.04 * breathe);
      canvas.drawCircle(
        c,
        rr,
        Paint()
          ..shader = RadialGradient(colors: [
            col.withValues(alpha: a),
            col.withValues(alpha: a * 0.2),
            Colors.transparent,
          ]).createShader(Rect.fromCircle(center: c, radius: rr))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
      );
    }

    glow(Offset(cx, cy), 200, C.primary, 0.08);
    glow(Offset(cx + 90, cy + 120), 140, C.accent, 0.05);
    glow(Offset(cx - 70, cy + 200), 100, const Color(0xFF6366F1), 0.04);

    final sp = Paint();
    for (final s in _stars) {
      final tw = 0.15 +
          0.85 *
              (0.5 +
                  0.5 *
                      math.sin(
                          t * math.pi * 2 * 2.5 + s.phase * math.pi * 2));
      sp.color = Colors.white.withValues(alpha: tw);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.r,
        sp,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter o) =>
      o.t != t || o.breathe != breathe;
}
