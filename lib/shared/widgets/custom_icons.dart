import 'dart:math';

import 'package:flutter/material.dart';

enum NavIconType { home, garden, breathing, journal, profile }

class CustomNavIcon extends StatelessWidget {
  const CustomNavIcon({
    super.key,
    required this.type,
    this.size = 24,
    this.color = Colors.white,
  });

  final NavIconType type;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _NavIconPainter(type: type, color: color),
    );
  }
}

class _NavIconPainter extends CustomPainter {
  _NavIconPainter({required this.type, required this.color});

  final NavIconType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height);
    canvas.save();
    canvas.scale(s / 24.0);
    switch (type) {
      case NavIconType.home:
        _paintHome(canvas);
        break;
      case NavIconType.garden:
        _paintGarden(canvas);
        break;
      case NavIconType.breathing:
        _paintBreathing(canvas);
        break;
      case NavIconType.journal:
        _paintJournal(canvas);
        break;
      case NavIconType.profile:
        _paintProfile(canvas);
        break;
    }
    canvas.restore();
  }

  void _paintHome(Canvas canvas) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const peak = Offset(12, 6.5);
    const roofL = Offset(5.5, 13);
    const roofR = Offset(18.5, 13);
    final house = Path()
      ..moveTo(roofL.dx, roofL.dy)
      ..lineTo(peak.dx, peak.dy)
      ..lineTo(roofR.dx, roofR.dy)
      ..lineTo(17, 13)
      ..lineTo(17, 20.5)
      ..lineTo(7, 20.5)
      ..lineTo(7, 13)
      ..close();
    canvas.drawPath(house, stroke);

    _drawFivePointStar(canvas, const Offset(12, 3.2), outerR: 1.35, innerR: 0.55, paint: stroke);
  }

  void _paintGarden(Canvas canvas) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final soil = Path();
    soil.addArc(
      const Rect.fromLTWH(5, 15, 14, 8),
      pi,
      pi,
    );
    canvas.drawPath(soil, stroke);

    const stemBase = Offset(12, 18.5);
    const stemTop = Offset(12, 9.5);
    canvas.drawLine(stemBase, stemTop, stroke);

    final leafL = Path()
      ..moveTo(stemTop.dx, stemTop.dy)
      ..quadraticBezierTo(7, 8, 5.5, 10.5);
    final leafR = Path()
      ..moveTo(stemTop.dx, stemTop.dy)
      ..quadraticBezierTo(17, 8, 18.5, 10.5);
    canvas.drawPath(leafL, stroke);
    canvas.drawPath(leafR, stroke);
  }

  void _paintBreathing(Canvas canvas) {
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const c = Offset(12, 12);
    const start = 5 * pi / 6;
    const sweep = -2 * pi / 3;

    for (final r in [3.2, 5.4, 7.6]) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        sweep,
        false,
        arcPaint,
      );
    }

    canvas.drawCircle(
      c,
      1.1,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  void _paintJournal(Canvas canvas) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const spine = Offset(12, 19.5);
    final leftPage = Path()
      ..moveTo(spine.dx, spine.dy)
      ..cubicTo(5, 17, 4, 9, 7.5, 6)
      ..cubicTo(9, 5, 11, 5.5, spine.dx, 7.5);
    final rightPage = Path()
      ..moveTo(spine.dx, spine.dy)
      ..cubicTo(19, 17, 20, 9, 16.5, 6)
      ..cubicTo(15, 5, 13, 5.5, spine.dx, 7.5);
    canvas.drawPath(leftPage, stroke);
    canvas.drawPath(rightPage, stroke);

    canvas.drawLine(const Offset(13.5, 11), const Offset(17, 11), stroke);
    canvas.drawLine(const Offset(13.5, 13.2), const Offset(16.5, 13.2), stroke);
    canvas.drawLine(const Offset(13.5, 15.4), const Offset(17.2, 15.4), stroke);

    final quill = Path()
      ..moveTo(17.5, 4.5)
      ..quadraticBezierTo(20, 6.5, 19, 9.5);
    canvas.drawPath(quill, stroke);
    canvas.drawLine(const Offset(18.2, 7.8), const Offset(19.4, 8.4), stroke);
  }

  void _paintProfile(Canvas canvas) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const headCenter = Offset(12, 9);
    const headR = 3.2;
    canvas.drawCircle(headCenter, headR, stroke);

    canvas.drawArc(
      Rect.fromCircle(center: headCenter, radius: headR + 1.35),
      pi,
      -pi,
      false,
      stroke,
    );

    final body = Path()
      ..moveTo(6.5, 20.5)
      ..quadraticBezierTo(6, 15.5, 9, 13.5)
      ..quadraticBezierTo(12, 12.8, 15, 13.5)
      ..quadraticBezierTo(18, 15.5, 17.5, 20.5);
    canvas.drawPath(body, stroke);
  }

  static void _drawFivePointStar(
    Canvas canvas,
    Offset center, {
    required double outerR,
    required double innerR,
    required Paint paint,
  }) {
    final path = Path();
    const n = 5;
    for (int i = 0; i < n * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final a = -pi / 2 + (i * pi) / n;
      final p = Offset(center.dx + r * cos(a), center.dy + r * sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NavIconPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}

enum MIconType {
  play,
  pause,
  stop,
  close,
  timer,
  bolt,
  fire,
  eco,
  park,
  florist,
  heart,
  sos,
  air,
  book,
  settings,
  premium,
  logout,
  check,
  lock,
  volumeDown,
  volumeUp,
  speed,
  rewind,
  forward,
  add,
  insights,
  chevronRight,
  arrowBack,
  arrowForward,
  delete,
  meditation,
  star,
}

class MIcon extends StatelessWidget {
  const MIcon(this.type, {super.key, this.size = 24, this.color = Colors.white});

  final MIconType type;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MIconPainter(type: type, color: color),
    );
  }
}

class _MIconPainter extends CustomPainter {
  _MIconPainter({required this.type, required this.color});

  final MIconType type;
  final Color color;

  static const double _sw = 1.7;

  Paint _stroke() => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = _sw
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height);
    canvas.save();
    canvas.scale(s / 24.0);
    switch (type) {
      case MIconType.play:
        _paintPlay(canvas);
        break;
      case MIconType.pause:
        _paintPause(canvas);
        break;
      case MIconType.stop:
        _paintStop(canvas);
        break;
      case MIconType.close:
        _paintClose(canvas);
        break;
      case MIconType.timer:
        _paintTimer(canvas);
        break;
      case MIconType.bolt:
        _paintBolt(canvas);
        break;
      case MIconType.fire:
        _paintFire(canvas);
        break;
      case MIconType.eco:
        _paintEco(canvas);
        break;
      case MIconType.park:
        _paintPark(canvas);
        break;
      case MIconType.florist:
        _paintFlorist(canvas);
        break;
      case MIconType.heart:
        _paintHeart(canvas);
        break;
      case MIconType.sos:
        _paintSos(canvas);
        break;
      case MIconType.air:
        _paintAir(canvas);
        break;
      case MIconType.book:
        _paintBook(canvas);
        break;
      case MIconType.settings:
        _paintSettings(canvas);
        break;
      case MIconType.premium:
        _paintPremium(canvas);
        break;
      case MIconType.logout:
        _paintLogout(canvas);
        break;
      case MIconType.check:
        _paintCheck(canvas);
        break;
      case MIconType.lock:
        _paintLock(canvas);
        break;
      case MIconType.volumeDown:
        _paintVolumeDown(canvas);
        break;
      case MIconType.volumeUp:
        _paintVolumeUp(canvas);
        break;
      case MIconType.speed:
        _paintSpeed(canvas);
        break;
      case MIconType.rewind:
        _paintRewind(canvas);
        break;
      case MIconType.forward:
        _paintForward(canvas);
        break;
      case MIconType.add:
        _paintAdd(canvas);
        break;
      case MIconType.insights:
        _paintInsights(canvas);
        break;
      case MIconType.chevronRight:
        _paintChevronRight(canvas);
        break;
      case MIconType.arrowBack:
        _paintArrowBack(canvas);
        break;
      case MIconType.arrowForward:
        _paintArrowForward(canvas);
        break;
      case MIconType.delete:
        _paintDelete(canvas);
        break;
      case MIconType.meditation:
        _paintMeditation(canvas);
        break;
      case MIconType.star:
        _paintStar(canvas);
        break;
    }
    canvas.restore();
  }

  void _paintPlay(Canvas canvas) {
    final p = _stroke();
    final path = Path()
      ..moveTo(8, 6.8)
      ..quadraticBezierTo(7.2, 12, 8, 17.2)
      ..quadraticBezierTo(8.35, 18.05, 9.25, 17.35)
      ..lineTo(17.85, 12.75)
      ..quadraticBezierTo(18.45, 12, 17.85, 11.25)
      ..lineTo(9.25, 6.65)
      ..quadraticBezierTo(8.35, 5.95, 8, 6.8)
      ..close();
    canvas.drawPath(path, p);
  }

  void _paintPause(Canvas canvas) {
    final p = _stroke();
    canvas.drawLine(const Offset(8.5, 7), const Offset(8.5, 17), p);
    canvas.drawLine(const Offset(15.5, 7), const Offset(15.5, 17), p);
  }

  void _paintStop(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(7, 7, 10, 10), const Radius.circular(2.2)),
      _stroke(),
    );
  }

  void _paintClose(Canvas canvas) {
    final p = _stroke();
    canvas.drawLine(const Offset(7, 7), const Offset(17, 17), p);
    canvas.drawLine(const Offset(17, 7), const Offset(7, 17), p);
  }

  void _paintTimer(Canvas canvas) {
    final p = _stroke();
    const c = Offset(12, 12);
    canvas.drawCircle(c, 8.2, p);
    canvas.drawCircle(const Offset(12, 4.2), 0.9, Paint()..color = color..style = PaintingStyle.fill);
    const handLen = 5.2;
    final a = -2 * pi / 3;
    canvas.drawLine(c, Offset(c.dx + handLen * cos(a), c.dy + handLen * sin(a)), p);
  }

  void _paintBolt(Canvas canvas) {
    final p = _stroke();
    final path = Path()
      ..moveTo(13.5, 4.5)
      ..lineTo(8.5, 12.5)
      ..lineTo(12, 12.5)
      ..lineTo(10.5, 19.5)
      ..lineTo(16.5, 10)
      ..lineTo(12.5, 10)
      ..close();
    canvas.drawPath(path, p);
  }

  void _paintFire(Canvas canvas) {
    final p = _stroke();
    final outer = Path()
      ..moveTo(12, 19.5)
      ..cubicTo(6.5, 16, 6, 12, 8.5, 8.5)
      ..cubicTo(9.5, 7, 11, 5.8, 12, 4.5)
      ..cubicTo(13, 5.8, 14.5, 7, 15.5, 8.5)
      ..cubicTo(18, 12, 17.5, 16, 12, 19.5)
      ..close();
    canvas.drawPath(outer, p);
    final inner = Path()
      ..moveTo(12, 15.5)
      ..quadraticBezierTo(9.5, 12.5, 11, 9.5)
      ..quadraticBezierTo(12, 8, 13, 9.5)
      ..quadraticBezierTo(14.5, 12.5, 12, 15.5);
    canvas.drawPath(inner, p);
  }

  void _paintEco(Canvas canvas) {
    final p = _stroke();
    final leaf = Path()
      ..moveTo(12, 19)
      ..quadraticBezierTo(6, 14, 7, 8.5)
      ..quadraticBezierTo(8, 5.5, 12, 5)
      ..quadraticBezierTo(16, 5.5, 17, 8.5)
      ..quadraticBezierTo(18, 14, 12, 19)
      ..close();
    canvas.drawPath(leaf, p);
    canvas.drawLine(const Offset(12, 19), const Offset(12, 10.5), p);
  }

  void _paintPark(Canvas canvas) {
    final p = _stroke();
    canvas.drawLine(const Offset(12, 19), const Offset(12, 14.5), p);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(12, 9.5), radius: 6.2),
      pi * 0.08,
      pi * 0.84,
      false,
      p,
    );
  }

  void _paintFlorist(Canvas canvas) {
    final p = _stroke();
    const c = Offset(12, 11);
    for (int i = 0; i < 5; i++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-pi / 2 + i * 2 * pi / 5);
      canvas.translate(0, -3.1);
      canvas.drawOval(const Rect.fromCenter(center: Offset.zero, width: 2.6, height: 5.4), p);
      canvas.restore();
    }
    canvas.drawCircle(c, 1.6, p);
  }

  void _paintHeart(Canvas canvas) {
    final p = _stroke();
    final path = Path()
      ..moveTo(12, 18.2)
      ..cubicTo(5.5, 14, 5.5, 9.5, 8.5, 7.2)
      ..cubicTo(10.2, 6, 12, 6.8, 12, 8.5)
      ..cubicTo(12, 6.8, 13.8, 6, 15.5, 7.2)
      ..cubicTo(18.5, 9.5, 18.5, 14, 12, 18.2)
      ..close();
    canvas.drawPath(path, p);
  }

  void _paintSos(Canvas canvas) {
    final p = _stroke();
    canvas.drawCircle(const Offset(12, 12), 9, p);
    canvas.drawLine(const Offset(12, 7.5), const Offset(12, 13.5), p);
    canvas.drawCircle(const Offset(12, 16.8), 0.85, Paint()..color = color..style = PaintingStyle.fill);
  }

  void _paintAir(Canvas canvas) {
    final p = _stroke();
    void wave(double y0) {
      final path = Path()
        ..moveTo(5, y0)
        ..quadraticBezierTo(9, y0 - 1.8, 13, y0)
        ..quadraticBezierTo(17, y0 + 1.8, 19, y0);
      canvas.drawPath(path, p);
    }

    wave(9.0);
    wave(12.0);
    wave(15.0);
  }

  void _paintBook(Canvas canvas) {
    final p = _stroke();
    const spine = Offset(12, 18.5);
    final left = Path()
      ..moveTo(spine.dx, spine.dy)
      ..quadraticBezierTo(5.5, 16, 5.5, 10)
      ..quadraticBezierTo(5.5, 6.5, spine.dx, 7);
    final right = Path()
      ..moveTo(spine.dx, spine.dy)
      ..quadraticBezierTo(18.5, 16, 18.5, 10)
      ..quadraticBezierTo(18.5, 6.5, spine.dx, 7);
    canvas.drawPath(left, p);
    canvas.drawPath(right, p);
  }

  void _paintSettings(Canvas canvas) {
    final p = _stroke();
    const c = Offset(12, 12);
    const rOuter = 6.8;
    const rInner = 4.5;
    const teeth = 6;
    final path = Path();
    for (int i = 0; i < teeth; i++) {
      final a0 = -pi / 2 + (i * 2 * pi / teeth);
      final a1 = a0 + pi / teeth * 0.35;
      final a2 = a0 + pi / teeth * 0.65;
      final a3 = a0 + pi / teeth;
      final pOut0 = Offset(c.dx + rOuter * cos(a0), c.dy + rOuter * sin(a0));
      final pOut1 = Offset(c.dx + rOuter * cos(a1), c.dy + rOuter * sin(a1));
      final pIn1 = Offset(c.dx + rInner * cos(a2), c.dy + rInner * sin(a2));
      final pIn2 = Offset(c.dx + rInner * cos(a3), c.dy + rInner * sin(a3));
      if (i == 0) {
        path.moveTo(pOut0.dx, pOut0.dy);
      } else {
        path.lineTo(pOut0.dx, pOut0.dy);
      }
      path.lineTo(pOut1.dx, pOut1.dy);
      path.lineTo(pIn1.dx, pIn1.dy);
      path.lineTo(pIn2.dx, pIn2.dy);
    }
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(c, 2.4, p);
  }

  void _paintPremium(Canvas canvas) {
    final p = _stroke();
    final path = Path()
      ..moveTo(12, 4.5)
      ..lineTo(17.5, 11)
      ..lineTo(12, 19.5)
      ..lineTo(6.5, 11)
      ..close();
    canvas.drawPath(path, p);
    canvas.drawLine(const Offset(12, 8.5), const Offset(12, 15.5), p);
  }

  void _paintLogout(Canvas canvas) {
    final p = _stroke();
    canvas.drawLine(const Offset(5.5, 6), const Offset(5.5, 18), p);
    canvas.drawLine(const Offset(5.5, 6), const Offset(10, 6), p);
    canvas.drawLine(const Offset(5.5, 18), const Offset(10, 18), p);
    final arrow = Path()
      ..moveTo(12, 12)
      ..lineTo(19, 12)
      ..moveTo(16.5, 9)
      ..lineTo(19, 12)
      ..lineTo(16.5, 15);
    canvas.drawPath(arrow, p);
  }

  void _paintCheck(Canvas canvas) {
    final p = _stroke();
    final path = Path()
      ..moveTo(5.5, 12.5)
      ..quadraticBezierTo(8.5, 15.5, 10.5, 17)
      ..quadraticBezierTo(13, 14, 18.5, 7);
    canvas.drawPath(path, p);
  }

  void _paintLock(Canvas canvas) {
    final p = _stroke();
    canvas.drawArc(
      const Rect.fromLTWH(7.5, 7, 9, 7),
      pi,
      pi,
      false,
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(6.5, 13, 11, 9), const Radius.circular(1.8)),
      p,
    );
    canvas.drawCircle(const Offset(12, 17.2), 1.4, p);
  }

  void _paintVolumeDown(Canvas canvas) {
    final p = _stroke();
    final speaker = Path()
      ..moveTo(5, 10)
      ..lineTo(8, 10)
      ..lineTo(11.5, 7)
      ..lineTo(11.5, 17)
      ..lineTo(8, 14)
      ..lineTo(5, 14)
      ..close();
    canvas.drawPath(speaker, p);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(15, 12), radius: 3.5),
      -pi / 4,
      pi / 2,
      false,
      p,
    );
  }

  void _paintVolumeUp(Canvas canvas) {
    final p = _stroke();
    final speaker = Path()
      ..moveTo(4, 10)
      ..lineTo(7, 10)
      ..lineTo(10.5, 7)
      ..lineTo(10.5, 17)
      ..lineTo(7, 14)
      ..lineTo(4, 14)
      ..close();
    canvas.drawPath(speaker, p);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(14, 12), radius: 3),
      -pi / 4,
      pi / 2,
      false,
      p,
    );
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(14, 12), radius: 5.2),
      -pi / 3.2,
      2 * pi / 3.2,
      false,
      p,
    );
  }

  void _paintSpeed(Canvas canvas) {
    final p = _stroke();
    const c = Offset(12, 14);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: 8),
      pi * 1.05,
      pi * 0.9,
      false,
      p,
    );
    final a = pi * 1.35;
    const len = 5.5;
    canvas.drawLine(c, Offset(c.dx + len * cos(a), c.dy + len * sin(a)), p);
    canvas.drawCircle(c, 1.1, Paint()..color = color..style = PaintingStyle.fill);
  }

  void _paintRewind(Canvas canvas) {
    final p = _stroke();
    void tri(double offset) {
      final path = Path()
        ..moveTo(17.5 + offset, 6)
        ..lineTo(9.5 + offset, 12)
        ..lineTo(17.5 + offset, 18)
        ..close();
      canvas.drawPath(path, p);
    }

    tri(-5.5);
    tri(0.5);
  }

  void _paintForward(Canvas canvas) {
    final p = _stroke();
    void tri(double offset) {
      final path = Path()
        ..moveTo(6.5 + offset, 6)
        ..lineTo(14.5 + offset, 12)
        ..lineTo(6.5 + offset, 18)
        ..close();
      canvas.drawPath(path, p);
    }

    tri(-0.5);
    tri(5.5);
  }

  void _paintAdd(Canvas canvas) {
    final p = _stroke();
    canvas.drawCircle(const Offset(12, 12), 8.5, p);
    canvas.drawLine(const Offset(12, 7.5), const Offset(12, 16.5), p);
    canvas.drawLine(const Offset(7.5, 12), const Offset(16.5, 12), p);
  }

  void _paintInsights(Canvas canvas) {
    final p = _stroke();
    canvas.drawLine(const Offset(6.5, 17), const Offset(6.5, 11), p);
    canvas.drawLine(const Offset(12, 17), const Offset(12, 7), p);
    canvas.drawLine(const Offset(17.5, 17), const Offset(17.5, 13.5), p);
  }

  void _paintChevronRight(Canvas canvas) {
    final p = _stroke();
    final path = Path()
      ..moveTo(9, 6.5)
      ..lineTo(15, 12)
      ..lineTo(9, 17.5);
    canvas.drawPath(path, p);
  }

  void _paintArrowBack(Canvas canvas) {
    final p = _stroke();
    canvas.drawLine(const Offset(19, 12), const Offset(8, 12), p);
    final path = Path()
      ..moveTo(11, 7)
      ..lineTo(5.5, 12)
      ..lineTo(11, 17);
    canvas.drawPath(path, p);
  }

  void _paintArrowForward(Canvas canvas) {
    final p = _stroke();
    canvas.drawLine(const Offset(5, 12), const Offset(16, 12), p);
    final path = Path()
      ..moveTo(13, 7)
      ..lineTo(18.5, 12)
      ..lineTo(13, 17);
    canvas.drawPath(path, p);
  }

  void _paintDelete(Canvas canvas) {
    final p = _stroke();
    canvas.drawLine(const Offset(8, 6.5), const Offset(16, 6.5), p);
    canvas.drawLine(const Offset(9, 6.5), const Offset(9.5, 19), p);
    canvas.drawLine(const Offset(15, 6.5), const Offset(14.5, 19), p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(7.5, 8.5, 9, 12), const Radius.circular(1.2)),
      p,
    );
    canvas.drawLine(const Offset(10, 11), const Offset(14, 15), p);
    canvas.drawLine(const Offset(14, 11), const Offset(10, 15), p);
  }

  void _paintMeditation(Canvas canvas) {
    final p = _stroke();
    canvas.drawCircle(const Offset(12, 7.8), 2.6, p);
    final legs = Path()
      ..moveTo(6.5, 19)
      ..quadraticBezierTo(7, 14.5, 10, 13)
      ..lineTo(14, 13)
      ..quadraticBezierTo(17, 14.5, 17.5, 19);
    canvas.drawPath(legs, p);
    final torso = Path()
      ..moveTo(12, 10.2)
      ..quadraticBezierTo(9.5, 12, 8.5, 14.5)
      ..moveTo(12, 10.2)
      ..quadraticBezierTo(14.5, 12, 15.5, 14.5);
    canvas.drawPath(torso, p);
    canvas.drawLine(const Offset(8.5, 14.5), const Offset(10, 16.5), p);
    canvas.drawLine(const Offset(15.5, 14.5), const Offset(14, 16.5), p);
  }

  void _paintStar(Canvas canvas) {
    _drawFivePointStarOutline(canvas, const Offset(12, 12), outerR: 7.2, innerR: 2.85, paint: _stroke());
  }

  static void _drawFivePointStarOutline(
    Canvas canvas,
    Offset center, {
    required double outerR,
    required double innerR,
    required Paint paint,
  }) {
    final path = Path();
    const n = 5;
    for (int i = 0; i < n * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final a = -pi / 2 + (i * pi) / n;
      final pt = Offset(center.dx + r * cos(a), center.dy + r * sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MIconPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}
