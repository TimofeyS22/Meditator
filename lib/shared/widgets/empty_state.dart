import 'dart:math';

import 'package:flutter/material.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';
import 'package:meditator/shared/widgets/glow_button.dart';

enum EmptyStateType { journal, garden, partner }

class EmptyState extends StatefulWidget {
  const EmptyState({
    super.key,
    required this.type,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final EmptyStateType type;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    if (_reduceMotion == reduceMotion) return;
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
    final t = Theme.of(context).textTheme;
    final progress = _reduceMotion ? 0.0 : _ctrl.value;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              label: 'Иллюстрация пустого состояния',
              child: SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _EmptyIllustrationPainter(
                    type: widget.type,
                    progress: progress,
                  ),
                ),
              ),
            ),
            const SizedBox(height: S.m),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                style: t.headlineSmall?.copyWith(color: C.text),
              ),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: S.s),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: C.textSec, height: 1.45),
                ),
              ),
            ],
            if (widget.actionLabel != null && widget.onAction != null) ...[
              const SizedBox(height: S.l),
              GlowButton(
                onPressed: widget.onAction,
                semanticLabel: widget.actionLabel,
                child: Text(widget.actionLabel!),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _EmptyIllustrationPainter extends CustomPainter {
  _EmptyIllustrationPainter({required this.type, required this.progress});

  final EmptyStateType type;
  final double progress;

  static const double _sw = 1.35;

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case EmptyStateType.journal:
        _paintJournal(canvas, size);
        break;
      case EmptyStateType.garden:
        _paintGarden(canvas, size);
        break;
      case EmptyStateType.partner:
        _paintPartner(canvas, size);
        break;
    }
  }

  void _paintJournal(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final baseY = size.height * 0.78;

    final fill = Paint()
      ..color = C.primary.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = C.primary.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _sw
      ..strokeCap = StrokeCap.round;

    final leftPage = Path()
      ..moveTo(cx, baseY)
      ..quadraticBezierTo(cx - 8, baseY - 28, cx - 42, baseY - 38)
      ..quadraticBezierTo(cx - 18, baseY - 52, cx - 2, baseY - 48)
      ..quadraticBezierTo(cx - 4, baseY - 22, cx, baseY)
      ..close();

    final rightPage = Path()
      ..moveTo(cx, baseY)
      ..quadraticBezierTo(cx + 8, baseY - 28, cx + 42, baseY - 38)
      ..quadraticBezierTo(cx + 18, baseY - 52, cx + 2, baseY - 48)
      ..quadraticBezierTo(cx + 4, baseY - 22, cx, baseY)
      ..close();

    canvas.drawPath(leftPage, fill);
    canvas.drawPath(rightPage, fill);
    canvas.drawPath(leftPage, stroke);
    canvas.drawPath(rightPage, stroke);

    final linePaint = Paint()
      ..color = C.primary.withValues(alpha: 0.45)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final t = i / 3.0;
      final y = baseY - 40 + t * 18;
      canvas.drawLine(Offset(cx + 10, y), Offset(cx + 32, y), linePaint);
    }

    final sparklePaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 5; i++) {
      final phase = i * 1.17;
      final bob = sin(progress * 2 * pi + phase) * 6;
      final drift = cos(progress * 2 * pi * 0.7 + phase) * 4;
      final ox = cx - 28 + (i % 3) * 26.0 + drift;
      final oy = size.height * 0.12 + (i * 7.0) % 22 + bob;
      final a = 0.35 + 0.35 * sin(progress * 2 * pi * 2 + i);
      sparklePaint.color = C.accentLight.withValues(alpha: a);
      canvas.drawCircle(Offset(ox, oy), 1.4 + 0.4 * sin(progress * 2 * pi + i), sparklePaint);
    }
  }

  void _paintGarden(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final groundY = size.height * 0.82;
    final moundW = size.width * 0.42;
    final moundH = size.height * 0.14;

    final mound = Rect.fromCenter(
      center: Offset(cx, groundY),
      width: moundW,
      height: moundH,
    );
    final earth = Paint()
      ..color = C.accent.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final earthStroke = Paint()
      ..color = C.accent.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _sw
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(mound, earth);
    canvas.drawOval(mound, earthStroke);

    final sway = 0.12 * sin(progress * 2 * pi);
    canvas.save();
    canvas.translate(cx, groundY - moundH * 0.35);
    canvas.rotate(sway);

    final stem = Paint()
      ..color = C.accent.withValues(alpha: 0.85)
      ..strokeWidth = _sw
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final stemTop = Offset(0, -32);
    canvas.drawLine(Offset(0, 4), stemTop, stem);

    final leaf = Paint()
      ..color = C.accent.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final leafOutline = Paint()
      ..color = C.accent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (final sign in [-1.0, 1.0]) {
      final lp = Path()
        ..moveTo(0, -18)
        ..quadraticBezierTo(sign * 14, -22, sign * 18, -30)
        ..quadraticBezierTo(sign * 8, -24, 0, -18);
      canvas.drawPath(lp, leaf);
      canvas.drawPath(lp, leafOutline);
    }

    canvas.restore();

    final starPaint = Paint()
      ..color = C.accent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final ang = progress * 2 * pi * 0.9 + i * 1.05;
      final rr = 22 + 10 * sin(progress * 2 * pi + i * 0.8);
      final sx = cx + cos(ang) * rr;
      final sy = groundY - moundH - 8 + sin(ang * 1.3) * 8;
      _drawTinyStar(canvas, Offset(sx, sy), 3.2 + sin(progress * 2 * pi * 2 + i), starPaint);
    }
  }

  void _drawTinyStar(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var k = 0; k < 4; k++) {
      final a = -pi / 2 + k * pi / 2;
      final p = Offset(c.dx + cos(a) * r, c.dy + sin(a) * r);
      if (k == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _paintPartner(Canvas canvas, Size size) {
    final left = Offset(size.width * 0.28, size.height * 0.52);
    final right = Offset(size.width * 0.72, size.height * 0.52);
    const r = 18.0;

    void drawGlow(Offset c, Color base) {
      final g = Paint()
        ..color = base.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(c, r + 8, g);
    }

    drawGlow(left, C.primary);
    drawGlow(right, C.accent);

    final fillL = Paint()..color = C.primary.withValues(alpha: 0.35);
    final fillR = Paint()..color = C.accent.withValues(alpha: 0.35);
    final strokeL = Paint()
      ..color = C.primary.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _sw;
    final strokeR = Paint()
      ..color = C.accent.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _sw;

    canvas.drawCircle(left, r, fillL);
    canvas.drawCircle(left, r, strokeL);
    canvas.drawCircle(right, r, fillR);
    canvas.drawCircle(right, r, strokeR);

    final bridge = Path()
      ..moveTo(left.dx + r * 0.65, left.dy - 4)
      ..quadraticBezierTo(
        (left.dx + right.dx) / 2,
        left.dy - 28 - 6 * sin(progress * 2 * pi),
        right.dx - r * 0.65,
        right.dy - 4,
      );

    final dotPaint = Paint()
      ..color = C.textSec.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    for (final metric in bridge.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final tan = metric.getTangentForOffset(d);
        if (tan != null) {
          canvas.drawCircle(tan.position, 1.15, dotPaint);
        }
        d += 7;
      }
    }

    final midX = (left.dx + right.dx) / 2;
    final midY = (left.dy + right.dy) / 2 - 14;
    for (var h = 0; h < 3; h++) {
      final float = sin(progress * 2 * pi + h * 1.3) * 10;
      final spread = (h - 1) * 9.0;
      _drawMiniHeart(
        canvas,
        Offset(midX + spread, midY + float + h * 3),
        4 + 0.8 * sin(progress * 2 * pi * 1.5 + h),
        C.rose.withValues(alpha: 0.45 + 0.25 * sin(progress * 2 * pi + h)),
      );
    }
  }

  void _drawMiniHeart(Canvas canvas, Offset c, double s, Color color) {
    final fill = Paint()..color = color;
    final p = Path()
      ..moveTo(c.dx, c.dy + s * 0.35)
      ..cubicTo(
        c.dx - s,
        c.dy - s * 0.1,
        c.dx - s * 0.55,
        c.dy - s * 0.85,
        c.dx,
        c.dy - s * 0.45,
      )
      ..cubicTo(
        c.dx + s * 0.55,
        c.dy - s * 0.85,
        c.dx + s,
        c.dy - s * 0.1,
        c.dx,
        c.dy + s * 0.35,
      )
      ..close();
    canvas.drawPath(p, fill);
  }

  @override
  bool shouldRepaint(covariant _EmptyIllustrationPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.progress != progress;
}
