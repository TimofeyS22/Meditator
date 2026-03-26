import 'dart:math';

import 'package:flutter/material.dart';
import 'package:meditator/shared/utils/accessibility.dart';

class MorphingBlob extends StatefulWidget {
  final double size;
  final Color color;
  final Duration period;

  const MorphingBlob({
    super.key,
    required this.size,
    required this.color,
    this.period = const Duration(seconds: 8),
  });

  @override
  State<MorphingBlob> createState() => _MorphingBlobState();
}

class _MorphingBlobState extends State<MorphingBlob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rm = AccessibilityUtils.reduceMotion(context);
    if (rm) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              size: Size.square(widget.size),
              painter: _BlobPainter(
                progress: reduceMotion ? 0.0 : _controller.value,
                color: widget.color,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final double progress;
  final Color color;

  static const int _pointCount = 7;
  static const double _wobbleAmount = 0.18;

  _BlobPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2 * 0.7;
    final phaseStep = (2 * pi) / _pointCount;
    final animAngle = progress * 2 * pi;

    final points = <Offset>[];
    for (var i = 0; i < _pointCount; i++) {
      final angle = i * phaseStep;
      final wobble =
          sin(animAngle + i * 1.7) * _wobbleAmount +
          sin(animAngle * 1.3 + i * 2.5) * _wobbleAmount * 0.5;
      final r = baseRadius * (1.0 + wobble);
      points.add(Offset(center.dx + r * cos(angle), center.dy + r * sin(angle)));
    }

    final path = _smoothPath(points);

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawCircle(center, baseRadius * 1.1, glowPaint);

    final rect = Rect.fromCircle(center: center, radius: baseRadius * 1.2);
    final gradient = RadialGradient(
      colors: [color, color.withValues(alpha: 0)],
      stops: const [0.0, 1.0],
    );
    final fillPaint = Paint()..shader = gradient.createShader(rect);
    canvas.drawPath(path, fillPaint);
  }

  Path _smoothPath(List<Offset> pts) {
    final path = Path();
    final n = pts.length;
    if (n < 3) return path;

    path.moveTo(
      (pts[n - 1].dx + pts[0].dx) / 2,
      (pts[n - 1].dy + pts[0].dy) / 2,
    );

    for (var i = 0; i < n; i++) {
      final curr = pts[i];
      final next = pts[(i + 1) % n];
      final mid = Offset((curr.dx + next.dx) / 2, (curr.dy + next.dy) / 2);
      path.quadraticBezierTo(curr.dx, curr.dy, mid.dx, mid.dy);
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_BlobPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
