import 'dart:math';

import 'package:flutter/material.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';

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
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    final rng = Random(42);
    _stars = List.generate(50, (_) => _StarData.random(rng));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    if (reduceMotion == _reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      if (_ctrl.isAnimating) _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _reduceMotion ? 0.0 : _ctrl.value;
    return ColoredBox(
      color: C.bgDeep,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: RepaintBoundary(
              child: ListenableBuilder(
                listenable: _ctrl,
                builder: (context, _) => CustomPaint(
                  painter: _BlobPainter(
                    progress: progress,
                    intensity: widget.intensity,
                    verticalOffset: widget.parallaxOffset,
                  ),
                ),
              ),
            ),
          ),
          if (widget.showStars)
            ExcludeSemantics(
              child: RepaintBoundary(
                child: ListenableBuilder(
                  listenable: _ctrl,
                  builder: (context, _) => CustomPaint(
                    painter: _StarPainter(
                      progress: progress,
                      stars: _stars,
                      verticalOffset: widget.parallaxOffset,
                    ),
                  ),
                ),
              ),
            ),
          if (widget.showAurora)
            ExcludeSemantics(
              child: RepaintBoundary(
                child: ListenableBuilder(
                  listenable: _ctrl,
                  builder: (context, _) => CustomPaint(
                    painter: _AuroraPainter(
                      progress: progress,
                      intensity: widget.intensity,
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(child: widget.child),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Star data – generated once, reused across paints
// ---------------------------------------------------------------------------

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
}

// ---------------------------------------------------------------------------
// Blob painter – 3 drifting radial-gradient blobs
// ---------------------------------------------------------------------------

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
    final v = verticalOffset * 0.3;
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
  }

  void _drawBlob(
    Canvas canvas,
    Size size, {
    required double cx,
    required double cy,
    required double r,
    required Color color,
  }) {
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

// ---------------------------------------------------------------------------
// Star painter – 50 twinkling stars
// ---------------------------------------------------------------------------

class _StarPainter extends CustomPainter {
  _StarPainter({
    required this.progress,
    required this.stars,
    required this.verticalOffset,
  });

  final double progress;
  final List<_StarData> stars;
  final double verticalOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * pi;
    final paint = Paint();
    final vy = verticalOffset * 0.15;

    for (final s in stars) {
      final raw = s.baseOpacity *
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

// ---------------------------------------------------------------------------
// Aurora painter – gradient wave along the top edge
// ---------------------------------------------------------------------------

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({required this.progress, required this.intensity});

  final double progress;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * pi;
    final path = Path()..moveTo(0, 0);

    for (double x = 0; x <= size.width; x += 2) {
      final nx = x / size.width;
      final y = size.height * 0.12 +
          sin(nx * 3 * pi + t) * size.height * 0.025 * intensity +
          sin(nx * 5 * pi + t * 1.5) * size.height * 0.015 * intensity;
      path.lineTo(x, y);
    }

    path
      ..lineTo(size.width, 0)
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
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.20)),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.progress != progress || old.intensity != intensity;
}
