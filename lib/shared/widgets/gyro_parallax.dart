import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:meditator/shared/utils/accessibility.dart';

class GyroParallax extends InheritedWidget {
  const GyroParallax({
    super.key,
    required super.child,
    required this.dx,
    required this.dy,
  });

  final double dx;
  final double dy;

  static GyroParallax? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GyroParallax>();

  static double offsetX(BuildContext context) =>
      maybeOf(context)?.dx ?? 0.0;

  static double offsetY(BuildContext context) =>
      maybeOf(context)?.dy ?? 0.0;

  @override
  bool updateShouldNotify(GyroParallax old) => old.dx != dx || old.dy != dy;
}

class GyroParallaxProvider extends StatefulWidget {
  const GyroParallaxProvider({super.key, required this.child});
  final Widget child;

  @override
  State<GyroParallaxProvider> createState() => _GyroParallaxProviderState();
}

class _GyroParallaxProviderState extends State<GyroParallaxProvider> {
  double _dx = 0.0;
  double _dy = 0.0;
  double _targetDx = 0.0;
  double _targetDy = 0.0;
  StreamSubscription<GyroscopeEvent>? _sub;
  Ticker? _ticker;
  bool _reduceMotion = false;

  static const double _sensitivity = 8.0;
  static const double _damping = 0.08;
  static const double _maxOffset = 20.0;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rm = AccessibilityUtils.reduceMotion(context);
    if (_reduceMotion != rm) {
      _reduceMotion = rm;
      if (_reduceMotion) {
        _stopListening();
        setState(() {
          _dx = 0;
          _dy = 0;
          _targetDx = 0;
          _targetDy = 0;
        });
      } else {
        _startListening();
      }
    }
  }

  void _startListening() {
    _ticker?.dispose();
    _ticker = Ticker(_onTick)..start();
    _sub?.cancel();
    _sub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 32),
    ).listen(_onGyro, onError: (_) {});
  }

  void _stopListening() {
    _ticker?.dispose();
    _ticker = null;
    _sub?.cancel();
    _sub = null;
  }

  void _onGyro(GyroscopeEvent e) {
    _targetDx = (_targetDx + e.y * _sensitivity)
        .clamp(-_maxOffset, _maxOffset);
    _targetDy = (_targetDy + e.x * _sensitivity)
        .clamp(-_maxOffset, _maxOffset);
  }

  void _onTick(Duration _) {
    final ndx = _dx + (_targetDx - _dx) * _damping;
    final ndy = _dy + (_targetDy - _dy) * _damping;
    if ((ndx - _dx).abs() > 0.01 || (ndy - _dy).abs() > 0.01) {
      setState(() {
        _dx = ndx;
        _dy = ndy;
      });
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GyroParallax(dx: _dx, dy: _dy, child: widget.child);
  }
}
