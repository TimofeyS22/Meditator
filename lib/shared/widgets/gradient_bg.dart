import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';
import 'package:meditator/shared/widgets/gyro_parallax.dart';

class GradientBg extends StatefulWidget {
  const GradientBg({
    super.key,
    required this.child,
    this.showStars = true,
    this.showAurora = false,
    this.intensity = 0.5,
    this.parallaxOffset = 0.0,
  });

  final Widget child;
  final bool showStars;
  final bool showAurora;
  final double intensity;
  final double parallaxOffset;

  @override
  State<GradientBg> createState() => _GradientBgState();
}

class _GradientBgState extends State<GradientBg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_StarData> _stars;
  late final List<_StarData> _deepStars;
  bool _reduceMotion = false;

  ui.FragmentShader? _darkShader;
  ui.FragmentShader? _lightShader;
  final Stopwatch _time = Stopwatch();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _time.start();

    final rng = Random(42);
    _stars = List.generate(50, (_) => _StarData.random(rng));
    _deepStars = List.generate(25, (_) => _StarData.randomDeep(rng));

    _loadShaders();
  }

  Future<void> _loadShaders() async {
    final results = await Future.wait([
      ui.FragmentProgram.fromAsset('shaders/cosmic_nebula.frag')
          .then<ui.FragmentProgram?>((p) => p, onError: (_) => null),
      ui.FragmentProgram.fromAsset('shaders/light_atmosphere.frag')
          .then<ui.FragmentProgram?>((p) => p, onError: (_) => null),
    ]);
    if (!mounted) return;
    setState(() {
      if (results[0] != null) _darkShader = results[0]!.fragmentShader();
      if (results[1] != null) _lightShader = results[1]!.fragmentShader();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = AccessibilityUtils.reduceMotion(context);
    if (reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    if (_reduceMotion) {
      if (_ctrl.isAnimating) _ctrl.stop();
      _time.stop();
    } else {
      if (!_ctrl.isAnimating) _ctrl.repeat();
      _time.start();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _time.stop();
    super.dispose();
  }

  double get _progress => _reduceMotion ? 0.0 : _ctrl.value;
  double get _elapsed =>
      _reduceMotion ? 0.0 : _time.elapsedMilliseconds / 1000.0;

  Widget _layer(double ox, double oy, CustomPainter Function() factory) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: ListenableBuilder(
          listenable: _ctrl,
          builder: (_, __) => Transform.translate(
            offset: Offset(ox, oy),
            child: CustomPaint(painter: factory()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gx = GyroParallax.offsetX(context);
    final gy = GyroParallax.offsetY(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final hasGpu = isLight ? _lightShader != null : _darkShader != null;

    final layers = <Widget>[];

    // --- Nebula / atmosphere ---
    if (hasGpu && isLight) {
      layers.add(_layer(gx * 0.3, gy * 0.3, () => _LightShaderPainter(
            shader: _lightShader!,
            time: _elapsed,
            intensity: widget.intensity,
            scrollOffset: widget.parallaxOffset,
          )));
    } else if (hasGpu) {
      final tod = C.timeOfDay();
      layers.add(_layer(gx * 0.3, gy * 0.3, () => _DarkShaderPainter(
            shader: _darkShader!,
            time: _elapsed,
            intensity: widget.intensity,
            scrollOffset: widget.parallaxOffset,
            color1: tod.blob1,
            color2: tod.blob2,
            color3: tod.blob3,
          )));
    } else if (isLight) {
      layers.add(_layer(gx * 0.3, gy * 0.3, () => _LightFallbackPainter(
            progress: _progress,
            intensity: widget.intensity,
            verticalOffset: widget.parallaxOffset * 0.08,
          )));
    } else {
      layers.add(_layer(gx * 0.3, gy * 0.3, () => _NebulaPainter(
            progress: _progress,
            intensity: widget.intensity,
            verticalOffset: widget.parallaxOffset * 0.08,
          )));
    }

    // Deep stars (dark only)
    if (widget.showStars && !isLight) {
      layers.add(_layer(gx * 0.15, gy * 0.15, () => _StarPainter(
            progress: _progress,
            stars: _deepStars,
            verticalOffset: widget.parallaxOffset * 0.1,
            baseOpacityScale: 0.5,
          )));
    }

    // Blob layer — only needed in CPU-fallback dark mode
    if (!hasGpu && !isLight) {
      layers.add(_layer(gx * 0.6, gy * 0.6, () => _BlobPainter(
            progress: _progress,
            intensity: widget.intensity,
            verticalOffset: widget.parallaxOffset * 0.2,
          )));
    }

    // Foreground stars (dark only)
    if (widget.showStars && !isLight) {
      layers.add(_layer(gx * 0.4, gy * 0.4, () => _StarPainter(
            progress: _progress,
            stars: _stars,
            verticalOffset: widget.parallaxOffset * 0.25,
            baseOpacityScale: 1.0,
          )));
    }

    // Aurora
    if (widget.showAurora) {
      layers.add(_layer(gx * 0.8, gy * 0.8, () => _AuroraPainter(
            progress: _progress,
            intensity: widget.intensity,
            verticalOffset: widget.parallaxOffset * 0.35,
          )));
    }

    layers.add(SafeArea(child: widget.child));

    return ColoredBox(
      color: context.cBgDeep,
      child: Stack(fit: StackFit.expand, children: layers),
    );
  }
}

// ── Shader helpers ─────────────────────────────────────────────────────

void _setColorUniform(ui.FragmentShader s, int base, Color c) {
  s.setFloat(base, c.r);
  s.setFloat(base + 1, c.g);
  s.setFloat(base + 2, c.b);
  s.setFloat(base + 3, c.a);
}

// ── GPU painters ───────────────────────────────────────────────────────

class _DarkShaderPainter extends CustomPainter {
  _DarkShaderPainter({
    required this.shader,
    required this.time,
    required this.intensity,
    required this.scrollOffset,
    required this.color1,
    required this.color2,
    required this.color3,
  });

  final ui.FragmentShader shader;
  final double time;
  final double intensity;
  final double scrollOffset;
  final Color color1;
  final Color color2;
  final Color color3;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, intensity)
      ..setFloat(4, scrollOffset);
    _setColorUniform(shader, 5, color1);
    _setColorUniform(shader, 9, color2);
    _setColorUniform(shader, 13, color3);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_DarkShaderPainter old) =>
      old.time != time ||
      old.intensity != intensity ||
      old.scrollOffset != scrollOffset;
}

class _LightShaderPainter extends CustomPainter {
  _LightShaderPainter({
    required this.shader,
    required this.time,
    required this.intensity,
    required this.scrollOffset,
  });

  final ui.FragmentShader shader;
  final double time;
  final double intensity;
  final double scrollOffset;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, intensity)
      ..setFloat(4, scrollOffset);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_LightShaderPainter old) =>
      old.time != time ||
      old.intensity != intensity ||
      old.scrollOffset != scrollOffset;
}

// ── Star data ──────────────────────────────────────────────────────────

class _StarData {
  final double x;
  final double y;
  final double radius;
  final double baseOpacity;
  final double phase;
  final double speed;

  const _StarData({
    required this.x,
    required this.y,
    required this.radius,
    required this.baseOpacity,
    required this.phase,
    required this.speed,
  });

  factory _StarData.random(Random rng) => _StarData(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 0.5 + rng.nextDouble() * 1.5,
        baseOpacity: 0.3 + rng.nextDouble() * 0.7,
        phase: rng.nextDouble() * 2 * pi,
        speed: 0.5 + rng.nextDouble() * 1.5,
      );

  factory _StarData.randomDeep(Random rng) => _StarData(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 0.3 + rng.nextDouble() * 0.8,
        baseOpacity: 0.15 + rng.nextDouble() * 0.35,
        phase: rng.nextDouble() * 2 * pi,
        speed: 0.2 + rng.nextDouble() * 0.6,
      );
}

// ── CPU fallback painters ──────────────────────────────────────────────

class _NebulaPainter extends CustomPainter {
  _NebulaPainter({
    required this.progress,
    required this.intensity,
    required this.verticalOffset,
  });

  final double progress;
  final double intensity;
  final double verticalOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * pi;
    final vy = verticalOffset;
    final tod = C.timeOfDay();

    _drawNebula(canvas, size,
        cx: size.width * (0.3 + 0.08 * sin(t * 0.2)),
        cy: size.height * (0.2 + 0.06 * cos(t * 0.15)) + vy,
        r: size.width * 0.55,
        color: tod.blob1.withValues(alpha: 0.06 * intensity));

    _drawNebula(canvas, size,
        cx: size.width * (0.7 + 0.06 * cos(t * 0.18)),
        cy: size.height * (0.75 + 0.04 * sin(t * 0.12)) + vy,
        r: size.width * 0.45,
        color: tod.blob2.withValues(alpha: 0.04 * intensity));

    _drawNebula(canvas, size,
        cx: size.width * (0.5 + 0.05 * sin(t * 0.25)),
        cy: size.height * (0.5 + 0.05 * cos(t * 0.1)) + vy,
        r: size.width * 0.6,
        color: C.primary.withValues(alpha: 0.025 * intensity));
  }

  void _drawNebula(Canvas canvas, Size size,
      {required double cx,
      required double cy,
      required double r,
      required Color color}) {
    final center = Offset(cx, cy);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_NebulaPainter old) =>
      old.progress != progress ||
      old.intensity != intensity ||
      old.verticalOffset != verticalOffset;
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({
    required this.progress,
    required this.intensity,
    required this.verticalOffset,
  });

  final double progress;
  final double intensity;
  final double verticalOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * pi;
    final v = verticalOffset;
    final tod = C.timeOfDay();

    _drawBlob(canvas, size,
        cx: size.width * (0.25 + 0.20 * sin(t * 0.7)),
        cy: size.height * (0.20 + 0.15 * cos(t * 0.5)) + v,
        r: size.width * 0.60,
        color: tod.blob1.withValues(alpha: 0.12 * intensity));

    _drawBlob(canvas, size,
        cx: size.width * (0.75 + 0.15 * cos(t * 0.6)),
        cy: size.height * (0.70 + 0.10 * sin(t * 0.8)) + v,
        r: size.width * 0.50,
        color: tod.blob2.withValues(alpha: 0.10 * intensity));

    _drawBlob(canvas, size,
        cx: size.width * (0.50 + 0.20 * sin(t * 0.4 + 1.0)),
        cy: size.height * (0.45 + 0.15 * cos(t * 0.3 + 0.5)) + v,
        r: size.width * 0.45,
        color: tod.blob3.withValues(alpha: 0.08 * intensity));

    _drawBlob(canvas, size,
        cx: size.width * (0.15 + 0.12 * cos(t * 0.35 + 2.0)),
        cy: size.height * (0.85 + 0.08 * sin(t * 0.45 + 1.5)) + v,
        r: size.width * 0.35,
        color: tod.blob1.withValues(alpha: 0.05 * intensity));

    _drawBlob(canvas, size,
        cx: size.width * (0.85 + 0.10 * sin(t * 0.55 + 0.8)),
        cy: size.height * (0.15 + 0.10 * cos(t * 0.25 + 2.0)) + v,
        r: size.width * 0.30,
        color: tod.blob3.withValues(alpha: 0.04 * intensity));
  }

  void _drawBlob(Canvas canvas, Size size,
      {required double cx,
      required double cy,
      required double r,
      required Color color}) {
    final center = Offset(cx, cy);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_BlobPainter old) =>
      old.progress != progress ||
      old.intensity != intensity ||
      old.verticalOffset != verticalOffset;
}

class _LightFallbackPainter extends CustomPainter {
  _LightFallbackPainter({
    required this.progress,
    required this.intensity,
    required this.verticalOffset,
  });

  final double progress;
  final double intensity;
  final double verticalOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFAF9F7), Color(0xFFF5F0EB), Color(0xFFF0EBF5)],
        ).createShader(rect),
    );

    final t = progress * 2 * pi;
    final glowCenter = Offset(
      size.width * (0.7 + 0.05 * sin(t * 0.3)),
      size.height * (0.12 + 0.03 * cos(t * 0.2)) + verticalOffset,
    );
    final glowR = size.width * 0.45;
    canvas.drawCircle(
      glowCenter,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFBBF24).withValues(alpha: 0.06 * intensity),
            const Color(0xFFFBBF24).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: glowR)),
    );

    final coolCenter = Offset(
      size.width * (0.3 + 0.04 * cos(t * 0.25)),
      size.height * (0.7 + 0.03 * sin(t * 0.18)) + verticalOffset,
    );
    final coolR = size.width * 0.40;
    canvas.drawCircle(
      coolCenter,
      coolR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF6366F1).withValues(alpha: 0.03 * intensity),
            const Color(0xFF6366F1).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: coolCenter, radius: coolR)),
    );
  }

  @override
  bool shouldRepaint(_LightFallbackPainter old) =>
      old.progress != progress ||
      old.intensity != intensity ||
      old.verticalOffset != verticalOffset;
}

// ── Star & aurora painters (unchanged) ─────────────────────────────────

class _StarPainter extends CustomPainter {
  _StarPainter({
    required this.progress,
    required this.stars,
    required this.verticalOffset,
    required this.baseOpacityScale,
  });

  final double progress;
  final List<_StarData> stars;
  final double verticalOffset;
  final double baseOpacityScale;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * pi;
    final paint = Paint();
    final vy = verticalOffset;

    for (final s in stars) {
      final raw = s.baseOpacity *
          baseOpacityScale *
          (0.3 + 0.7 * ((sin(t * s.speed + s.phase) + 1.0) * 0.5));
      paint.color = Colors.white.withValues(alpha: raw.clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height + vy),
        s.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.progress != progress || old.verticalOffset != verticalOffset;
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.progress,
    required this.intensity,
    this.verticalOffset = 0.0,
  });

  final double progress;
  final double intensity;
  final double verticalOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * pi;
    final vy = verticalOffset;

    final path = Path()..moveTo(0, vy);
    for (double x = 0; x <= size.width; x += 2) {
      final nx = x / size.width;
      final y = vy +
          size.height * 0.12 +
          sin(nx * 3 * pi + t) * size.height * 0.025 * intensity +
          sin(nx * 5 * pi + t * 1.5) * size.height * 0.015 * intensity +
          sin(nx * 7 * pi + t * 0.7) * size.height * 0.008 * intensity;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, vy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            C.primary.withValues(alpha: 0.12 * intensity),
            C.accent.withValues(alpha: 0.08 * intensity),
            C.calm.withValues(alpha: 0.06 * intensity),
          ],
        ).createShader(Rect.fromLTWH(0, vy, size.width, size.height * 0.20)),
    );

    final path2 = Path()..moveTo(0, vy);
    for (double x = 0; x <= size.width; x += 2) {
      final nx = x / size.width;
      final y = vy +
          size.height * 0.08 +
          sin(nx * 4 * pi + t * 1.2 + 1.0) *
              size.height *
              0.018 *
              intensity +
          sin(nx * 6 * pi + t * 0.8 + 2.0) *
              size.height *
              0.01 *
              intensity;
      path2.lineTo(x, y);
    }
    path2
      ..lineTo(size.width, vy)
      ..close();

    canvas.drawPath(
      path2,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            C.accent.withValues(alpha: 0.06 * intensity),
            C.calm.withValues(alpha: 0.04 * intensity),
          ],
        ).createShader(Rect.fromLTWH(0, vy, size.width, size.height * 0.15)),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.progress != progress ||
      old.intensity != intensity ||
      old.verticalOffset != verticalOffset;
}
