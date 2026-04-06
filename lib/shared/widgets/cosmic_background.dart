import 'dart:math';
import 'package:flutter/material.dart';
import 'package:meditator/core/aura/atmosphere.dart';
import 'package:meditator/shared/theme/cosmic.dart';

/// Living universe background with 3 parallax star layers, state-specific
/// gradients, bloom, vignette, and breathing animation.
///
/// Pass [mood] for full visual adaptation, or just [intensity] for simple mode.
class CosmicBackground extends StatefulWidget {
  final Widget child;
  final UniverseMood? mood;
  final double intensity;
  final bool silentMode;
  final int seed;
  final int extraStars;
  final double bloomBoost;

  const CosmicBackground({
    super.key,
    required this.child,
    this.mood,
    this.intensity = 1.0,
    this.silentMode = false,
    this.seed = 42,
    this.extraStars = 0,
    this.bloomBoost = 0.0,
  });

  @override
  State<CosmicBackground> createState() => _CosmicBackgroundState();
}

class _CosmicBackgroundState extends State<CosmicBackground>
    with TickerProviderStateMixin {
  late final AnimationController _baseCtrl;
  late final AnimationController _breathCtrl;
  late final AnimationController _transCtrl;

  late final List<_Star> _farStars;
  late final List<_Star> _midStars;
  late final List<_Nebula> _nebulae;

  late UniverseVisualConfig _config;
  UniverseVisualConfig? _prevConfig;

  @override
  void initState() {
    super.initState();
    _config = widget.mood != null
        ? UniverseVisualConfig.of(widget.mood!)
        : _defaultConfig();

    final rng = Random(widget.seed);
    final farCount = 50 + (widget.extraStars * 0.6).round();
    final midCount = 40 + (widget.extraStars * 0.4).round();
    _farStars = List.generate(farCount, (_) => _Star.random(rng, layer: 0));
    _midStars = List.generate(midCount, (_) => _Star.random(rng, layer: 1));
    _nebulae = [
      _Nebula(cx: 0.25, cy: 0.2, radius: 0.45, speed: 0.12),
      _Nebula(cx: 0.75, cy: 0.75, radius: 0.4, speed: 0.1),
      _Nebula(cx: 0.5, cy: 0.5, radius: 0.5, speed: 0.07),
    ];

    _baseCtrl = AnimationController(vsync: this, duration: Anim.cosmic)
      ..repeat();

    _breathCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_config.breathPeriodSec * 1000).round()),
    )..repeat(reverse: true);

    _transCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: 1.0,
    );
  }

  @override
  void didUpdateWidget(CosmicBackground old) {
    super.didUpdateWidget(old);
    if (widget.mood != old.mood) {
      final newConfig = widget.mood != null
          ? UniverseVisualConfig.of(widget.mood!)
          : _defaultConfig();
      _prevConfig = _config;
      _config = newConfig;
      _transCtrl.forward(from: 0);

      _breathCtrl.duration = Duration(
        milliseconds: (newConfig.breathPeriodSec * 1000).round(),
      );
    }
  }

  UniverseVisualConfig _defaultConfig() => UniverseVisualConfig(
        bgA: Cosmic.bg,
        bgB: const Color(0xFF0A0A1A),
        radialGradient: true,
        bloomColor: Cosmic.primary,
        bloomIntensity: 0.06 * widget.intensity,
        accentColor: Cosmic.primary,
        vignetteStrength: 0.4,
        breathAmplitude: 0.05,
        breathPeriodSec: 6,
      );

  @override
  void dispose() {
    _baseCtrl.dispose();
    _breathCtrl.dispose();
    _transCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([_baseCtrl, _breathCtrl, _transCtrl]),
              builder: (_, __) {
                final cfg = _prevConfig != null && _transCtrl.value < 1.0
                    ? UniverseVisualConfig.lerp(
                        _prevConfig!, _config, _transCtrl.value)
                    : _config;

                final breathVal = Curves.easeInOut.transform(_breathCtrl.value);
                final scale = 1.0 + cfg.breathAmplitude * breathVal;

                return Transform.scale(
                  scale: scale,
                  child: CustomPaint(
                    painter: _UniversePainter(
                      config: cfg,
                      progress: _baseCtrl.value,
                      farStars: _farStars,
                      midStars: _midStars,
                      nebulae: _nebulae,
                      intensity: widget.intensity,
                      silentMode: widget.silentMode,
                      bloomBoost: widget.bloomBoost,
                    ),
                  ),
                );
              },
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

// ─── Star data ───────────────────────────────────────────────────────────────

class _Star {
  final double x, y, baseAlpha, phase, speed;
  final double radius;
  final int layer;

  const _Star({
    required this.x, required this.y,
    required this.radius, required this.baseAlpha,
    required this.phase, required this.speed,
    required this.layer,
  });

  factory _Star.random(Random rng, {required int layer}) {
    final radiusRange = switch (layer) {
      0 => (0.4, 1.2),
      1 => (0.7, 2.0),
      _ => (1.0, 2.5),
    };
    final alphaRange = switch (layer) {
      0 => (0.2, 0.5),
      1 => (0.3, 0.7),
      _ => (0.5, 0.9),
    };
    return _Star(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      radius: radiusRange.$1 + rng.nextDouble() * (radiusRange.$2 - radiusRange.$1),
      baseAlpha: alphaRange.$1 + rng.nextDouble() * (alphaRange.$2 - alphaRange.$1),
      phase: rng.nextDouble() * 2 * pi,
      speed: 0.3 + rng.nextDouble() * 1.2,
      layer: layer,
    );
  }
}

class _Nebula {
  final double cx, cy, radius, speed;
  const _Nebula({
    required this.cx, required this.cy,
    required this.radius, required this.speed,
  });
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _UniversePainter extends CustomPainter {
  final UniverseVisualConfig config;
  final double progress;
  final List<_Star> farStars;
  final List<_Star> midStars;
  final List<_Nebula> nebulae;
  final double intensity;
  final bool silentMode;
  final double bloomBoost;

  _UniversePainter({
    required this.config,
    required this.progress,
    required this.farStars,
    required this.midStars,
    required this.nebulae,
    required this.intensity,
    this.silentMode = false,
    this.bloomBoost = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGradient(canvas, size);
    _drawNebulae(canvas, size);
    _drawStarLayer(canvas, size, farStars, speedMul: 0.3);
    _drawStarLayer(canvas, size, midStars, speedMul: 0.65);
    _drawBloom(canvas, size);
    _drawVignette(canvas, size);
  }

  void _drawGradient(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final Gradient grad;

    if (config.radialGradient) {
      grad = RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [config.bgB, config.bgA],
      );
    } else {
      grad = LinearGradient(
        begin: config.gradBegin,
        end: config.gradEnd,
        colors: [config.bgA, config.bgB],
      );
    }
    canvas.drawRect(rect, Paint()..shader = grad.createShader(rect));
  }

  void _drawNebulae(Canvas canvas, Size size) {
    final t = progress * 2 * pi;
    for (final n in nebulae) {
      final cx = size.width * (n.cx + 0.05 * sin(t * n.speed));
      final cy = size.height * (n.cy + 0.04 * cos(t * n.speed * 0.7));
      final r = size.width * n.radius;
      final center = Offset(cx, cy);
      final alpha = 0.06 * intensity;

      canvas.drawCircle(
        center, r,
        Paint()
          ..shader = RadialGradient(colors: [
            config.accentColor.withValues(alpha: alpha),
            config.accentColor.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }
  }

  void _drawStarLayer(
    Canvas canvas, Size size, List<_Star> stars, {required double speedMul}
  ) {
    final t = progress * 2 * pi;
    final paint = Paint();
    final drift = progress * speedMul * 0.02;

    for (final s in stars) {
      final twinkle = (sin(t * s.speed * speedMul + s.phase) + 1.0) * 0.5;
      final alpha = (s.baseAlpha * (0.3 + 0.7 * twinkle) * intensity).clamp(0.0, 1.0);

      final px = ((s.x + drift * sin(s.phase)) % 1.0) * size.width;
      final py = ((s.y + drift * 0.5 * cos(s.phase)) % 1.0) * size.height;

      paint.color = Color.lerp(
        Colors.white,
        config.accentColor,
        s.layer == 1 ? 0.25 : 0.0,
      )!.withValues(alpha: alpha);

      canvas.drawCircle(Offset(px, py), s.radius, paint);
    }
  }

  void _drawBloom(Canvas canvas, Size size) {
    if (config.bloomIntensity < 0.01) return;

    final center = Offset(size.width / 2, size.height * 0.4);
    final r = size.width * (silentMode ? 0.85 : 0.7);
    final bloomMul = silentMode ? 1.3 : 1.0;
    final alpha = (config.bloomIntensity + bloomBoost) * intensity * bloomMul;

    canvas.drawCircle(
      center, r,
      Paint()
        ..shader = RadialGradient(colors: [
          config.bloomColor.withValues(alpha: alpha),
          config.bloomColor.withValues(alpha: alpha * 0.3),
          config.bloomColor.withValues(alpha: 0),
        ], stops: const [0.0, 0.35, 1.0])
            .createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  void _drawVignette(Canvas canvas, Size size) {
    final vStrength = silentMode
        ? config.vignetteStrength * 0.6
        : config.vignetteStrength;
    if (vStrength < 0.05) return;

    final center = Offset(size.width / 2, size.height / 2);
    final r = size.longestSide * 0.8;

    canvas.drawCircle(
      center, r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: vStrength * 0.5),
            Colors.black.withValues(alpha: vStrength),
          ],
          stops: const [0.4, 0.75, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_UniversePainter old) =>
      old.progress != progress || old.config != config ||
      old.intensity != intensity || old.silentMode != silentMode;
}
