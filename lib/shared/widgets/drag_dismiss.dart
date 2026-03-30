import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';
import 'package:meditator/shared/utils/spring_utils.dart';

class DragDismiss extends StatefulWidget {
  const DragDismiss({
    super.key,
    required this.child,
    required this.onDismiss,
    this.dismissThreshold = 0.25,
    this.velocityThreshold = 800.0,
    this.backgroundColor = C.bgDeep,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onDismiss;
  final double dismissThreshold;
  final double velocityThreshold;
  final Color backgroundColor;
  final bool enabled;

  @override
  State<DragDismiss> createState() => _DragDismissState();
}

class _DragDismissState extends State<DragDismiss>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _dragOffset = 0.0;
  bool _isDragging = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController.unbounded(vsync: this);
    _ctrl.addListener(() {
      if (!_isDragging) {
        setState(() => _dragOffset = _ctrl.value);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    if (!widget.enabled || _dismissed) return;
    _isDragging = true;
    _ctrl.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled || _dismissed) return;
    setState(() {
      _dragOffset = (_dragOffset + details.primaryDelta!).clamp(0.0, double.infinity);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enabled || _dismissed) return;
    _isDragging = false;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final fraction = _dragOffset / screenHeight;
    final velocity = details.velocity.pixelsPerSecond.dy;

    if (fraction > widget.dismissThreshold || velocity > widget.velocityThreshold) {
      _dismissed = true;
      _ctrl.value = _dragOffset;
      _ctrl
          .animateTo(
            screenHeight,
            duration: const Duration(milliseconds: 250),
            curve: Anim.curve,
          )
          .then((_) => widget.onDismiss());
    } else {
      _ctrl.value = _dragOffset;
      _ctrl.animateWith(
        SpringSimulation(SpringUtils.dismiss, _dragOffset, 0.0, -velocity),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AccessibilityUtils.reduceMotion(context) || !widget.enabled) {
      return widget.child;
    }

    final screenHeight = MediaQuery.sizeOf(context).height;
    final fraction = (screenHeight > 0 ? _dragOffset / screenHeight : 0.0).clamp(0.0, 1.0);
    final scale = 1.0 - fraction * 0.12;
    final opacity = (1.0 - fraction * 1.5).clamp(0.0, 1.0);
    final borderRadius = fraction * 24.0;
    final blurSigma = fraction * 8.0;

    return GestureDetector(
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (blurSigma > 0.5)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: widget.backgroundColor.withValues(
                    alpha: (1.0 - fraction * 0.6).clamp(0.0, 1.0),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(0, _dragOffset),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: Opacity(
                opacity: opacity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: widget.child,
                ),
              ),
            ),
          ),
          if (_dragOffset > 10)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: (fraction * 3).clamp(0.0, 0.6),
                  duration: Anim.fast,
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
