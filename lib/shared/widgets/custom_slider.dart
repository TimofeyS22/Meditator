import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';
import 'package:meditator/shared/utils/spring_utils.dart';

class GlowSlider extends StatefulWidget {
  const GlowSlider({
    super.key,
    required this.value,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor,
    this.trackColor,
    this.showGlow = true,
    this.height = 4.0,
    this.semanticLabel,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final Color? activeColor;
  final Color? trackColor;
  final bool showGlow;
  final double height;
  final String? semanticLabel;

  @override
  State<GlowSlider> createState() => _GlowSliderState();
}

class _GlowSliderState extends State<GlowSlider> with TickerProviderStateMixin {
  static const double _thumbBase = 16;
  static const double _thumbActive = 20;
  static const double _maxThumbRadius = _thumbActive / 2;
  static const double _glowSlack = 12;

  late final AnimationController _thumbScaleCtrl;
  late final AnimationController _glowCtrl;

  bool _dragging = false;
  double? _dragValue;
  bool _reduceMotion = false;

  double get _effectiveValue {
    if (_dragging && _dragValue != null) return _dragValue!;
    return widget.value.clamp(0.0, 1.0);
  }

  Color get _active => widget.activeColor ?? C.accent;
  Color get _track => widget.trackColor ?? C.surfaceLight;

  @override
  void initState() {
    super.initState();
    _thumbScaleCtrl = AnimationController(
      vsync: this,
      duration: Anim.fast,
    );
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  void _syncGlowRepeat() {
    final wantGlow =
        widget.showGlow && !_reduceMotion && widget.onChanged != null;
    if (wantGlow) {
      if (!_glowCtrl.isAnimating) {
        _glowCtrl.repeat(reverse: true);
      }
    } else {
      if (_glowCtrl.isAnimating) _glowCtrl.stop();
      _glowCtrl.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rm = AccessibilityUtils.reduceMotion(context);
    if (_reduceMotion != rm) {
      _reduceMotion = rm;
      _syncGlowRepeat();
    }
  }

  @override
  void didUpdateWidget(covariant GlowSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showGlow != widget.showGlow ||
        oldWidget.onChanged != widget.onChanged) {
      _syncGlowRepeat();
    }
  }

  @override
  void dispose() {
    _thumbScaleCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  double get _horizontalInset => _maxThumbRadius + _glowSlack + S.xs;

  double _valueFromDx(double dx, double width) {
    final inset = _horizontalInset;
    final span = (width - 2 * inset).clamp(1.0, double.infinity);
    return ((dx - inset) / span).clamp(0.0, 1.0);
  }

  void _setThumbScale(double target) {
    _thumbScaleCtrl.animateWith(
      SpringUtils.simulation(
        SpringUtils.snappy,
        start: _thumbScaleCtrl.value,
        end: target,
        velocity: _thumbScaleCtrl.velocity,
      ),
    );
  }

  void _onDragStart() {
    if (widget.onChanged == null) return;
    _dragging = true;
    _dragValue = widget.value.clamp(0.0, 1.0);
    HapticFeedback.selectionClick();
    widget.onChangeStart?.call(_dragValue!);
    _setThumbScale(1);
    setState(() {});
  }

  void _onDragUpdate(double dx, double width) {
    if (widget.onChanged == null) return;
    final v = _valueFromDx(dx, width);
    _dragValue = v;
    widget.onChanged!.call(v);
    setState(() {});
  }

  void _onDragEnd() {
    if (widget.onChanged == null) return;
    final end = _dragValue ?? widget.value.clamp(0.0, 1.0);
    widget.onChangeEnd?.call(end);
    _dragging = false;
    _dragValue = null;
    _setThumbScale(0);
    setState(() {});
  }

  void _onTapDown(TapDownDetails details, double width) {
    if (widget.onChanged == null) return;
    final v = _valueFromDx(details.localPosition.dx, width);
    widget.onChangeStart?.call(widget.value.clamp(0.0, 1.0));
    widget.onChanged!.call(v);
    widget.onChangeEnd?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = AccessibilityUtils.reduceMotion(context);
    _syncGlowRepeat();

    final paintHeight = widget.height + 2 * (_maxThumbRadius + _glowSlack);
    final semanticsValue =
        '${(_effectiveValue * 100).round()}%';

    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: semanticsValue,
      enabled: widget.onChanged != null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.onChanged != null
                ? (d) => _onTapDown(d, width)
                : null,
            onHorizontalDragStart: widget.onChanged != null
                ? (_) => _onDragStart()
                : null,
            onHorizontalDragUpdate: widget.onChanged != null
                ? (details) =>
                    _onDragUpdate(details.localPosition.dx, width)
                : null,
            onHorizontalDragEnd: widget.onChanged != null
                ? (_) => _onDragEnd()
                : null,
            onHorizontalDragCancel: widget.onChanged != null ? _onDragEnd : null,
            child: SizedBox(
              width: width,
              height: paintHeight,
              child: AnimatedBuilder(
                animation: Listenable.merge([_thumbScaleCtrl, _glowCtrl]),
                builder: (context, _) {
                  final tScale = Curves.easeOutCubic
                      .transform(_thumbScaleCtrl.value.clamp(0.0, 1.0));
                  final thumbDiameter = ui.lerpDouble(
                        _thumbBase,
                        _thumbActive,
                        tScale,
                      ) ??
                      _thumbBase;
                  final glowPulse = (!widget.showGlow || _reduceMotion)
                      ? (widget.showGlow && _reduceMotion ? 0.72 : 0.0)
                      : (0.38 + 0.62 * _glowCtrl.value);

                  return RepaintBoundary(
                    child: CustomPaint(
                      painter: _GlowSliderPainter(
                        value: _effectiveValue.clamp(0.0, 1.0),
                        trackHeight: widget.height,
                        activeColor: _active,
                        trackColor: _track,
                        thumbDiameter: thumbDiameter,
                        glowPulse: glowPulse,
                        horizontalInset: _horizontalInset,
                      ),
                      child: SizedBox(width: width, height: paintHeight),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GlowSliderPainter extends CustomPainter {
  _GlowSliderPainter({
    required this.value,
    required this.trackHeight,
    required this.activeColor,
    required this.trackColor,
    required this.thumbDiameter,
    required this.glowPulse,
    required this.horizontalInset,
  });

  final double value;
  final double trackHeight;
  final Color activeColor;
  final Color trackColor;
  final double thumbDiameter;
  final double glowPulse;
  final double horizontalInset;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final w = size.width;
    final left = horizontalInset;
    final right = w - horizontalInset;
    final trackW = (right - left).clamp(0.0, double.infinity);
    final thumbX = left + value * trackW;
    final capR = trackHeight / 2;

    final trackRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(left + trackW / 2, cy),
        width: trackW,
        height: trackHeight,
      ),
      Radius.circular(capR),
    );

    final inactivePaint = Paint()..color = trackColor;
    canvas.drawRRect(trackRect, inactivePaint);

    if (trackW > 0 && value > 0) {
      final activeW = (value * trackW).clamp(0.0, trackW);
      final atEnd = value >= 1.0 - 1e-9;
      final activeRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, cy - trackHeight / 2, activeW, trackHeight),
        topLeft: Radius.circular(capR),
        bottomLeft: Radius.circular(capR),
        topRight: atEnd ? Radius.circular(capR) : Radius.zero,
        bottomRight: atEnd ? Radius.circular(capR) : Radius.zero,
      );

      if (glowPulse > 0.01) {
        final glowPaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(left, cy),
            Offset(left + activeW, cy),
            [
              C.glowPrimary.withValues(alpha: 0.45 * glowPulse),
              C.glowAccent.withValues(alpha: 0.35 * glowPulse),
            ],
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 4 * glowPulse);
        canvas.save();
        canvas.drawRRect(activeRect.inflate(2), glowPaint);
        canvas.restore();
      }

      final activePaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(left, cy - trackHeight / 2),
          Offset(left + activeW, cy + trackHeight / 2),
          [C.primary, activeColor],
        );
      canvas.drawRRect(activeRect, activePaint);
    }

    final thumbR = thumbDiameter / 2;
    if (glowPulse > 0.01) {
      final halo = Paint()
        ..color = Color.lerp(C.glowPrimary, C.glowAccent, 0.5)!
            .withValues(alpha: 0.55 * glowPulse)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, 5 + 7 * glowPulse);
      canvas.drawCircle(Offset(thumbX, cy), thumbR + 4 + 3 * glowPulse, halo);
    }

    final thumbPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(thumbX - thumbR, cy - thumbR),
        Offset(thumbX + thumbR, cy + thumbR),
        [C.primary, activeColor],
      );
    canvas.drawCircle(Offset(thumbX, cy), thumbR, thumbPaint);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(Offset(thumbX, cy), thumbR, rim);
  }

  @override
  bool shouldRepaint(covariant _GlowSliderPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.trackHeight != trackHeight ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.thumbDiameter != thumbDiameter ||
        oldDelegate.glowPulse != glowPulse ||
        oldDelegate.horizontalInset != horizontalInset;
  }
}
