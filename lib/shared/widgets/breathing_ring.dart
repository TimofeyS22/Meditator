import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';

class BreathingPhase {
  const BreathingPhase({
    required this.label,
    required this.seconds,
    required this.targetScale,
  });

  final String label;
  final int seconds;
  final double targetScale;
}

class BreathingRingController extends ChangeNotifier {
  BreathingRingController({
    required List<BreathingPhase> phases,
    required this.cycles,
    this.onPhaseChange,
    this.onCycleComplete,
    this.onFinished,
  })  : _phases = List.unmodifiable(phases),
        assert(cycles > 0, 'cycles must be positive') {
    if (_phases.isNotEmpty) {
      _secondsLeft = _phases[0].seconds;
    }
  }

  final List<BreathingPhase> _phases;
  final int cycles;
  final void Function(int phaseIndex)? onPhaseChange;
  final void Function()? onCycleComplete;
  final void Function()? onFinished;

  Timer? _timer;
  bool _running = false;
  bool _paused = false;
  bool _finished = false;
  int _phaseIndex = 0;
  int _cycleIndex = 0;
  Duration _elapsedInPhase = Duration.zero;
  double _phaseStartScale = 1;
  double _scale = 1;
  int _secondsLeft = 0;

  List<BreathingPhase> get phases => _phases;
  int get phaseIndex => _phaseIndex;
  BreathingPhase? get currentPhase =>
      _phases.isEmpty ? null : _phases[_phaseIndex];
  double get scale => _scale;
  int get secondsLeft => _secondsLeft;
  bool get isRunning => _running && !_paused;
  bool get isFinished => _finished;

  void start() {
    if (_phases.isEmpty || _finished) return;
    if (_running && !_paused) return;

    if (!_running) {
      _running = true;
      _elapsedInPhase = Duration.zero;
      _phaseStartScale = 1;
      _phaseIndex = 0;
      _cycleIndex = 0;
      _finished = false;
      _syncSecondsLeft();
      onPhaseChange?.call(_phaseIndex);
    }

    _paused = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), _tick);
    notifyListeners();
  }

  void pause() {
    if (!_running) return;
    _paused = true;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _paused = false;
    _finished = false;
    _phaseIndex = 0;
    _cycleIndex = 0;
    _elapsedInPhase = Duration.zero;
    _phaseStartScale = 1;
    _scale = 1;
    _syncSecondsLeft();
    notifyListeners();
  }

  void _syncSecondsLeft() {
    final p = currentPhase;
    if (p == null) {
      _secondsLeft = 0;
      return;
    }
    final totalMs = p.seconds * 1000;
    if (totalMs <= 0) {
      _secondsLeft = 0;
      return;
    }
    final t = (_elapsedInPhase.inMilliseconds / totalMs).clamp(0.0, 1.0);
    _secondsLeft = ((1 - t) * p.seconds).ceil().clamp(0, p.seconds);
  }

  void _tick(Timer timer) {
    if (!_running || _paused || _finished || _phases.isEmpty) return;

    final p = _phases[_phaseIndex];
    final phaseDur = Duration(seconds: p.seconds <= 0 ? 1 : p.seconds);
    _elapsedInPhase += const Duration(milliseconds: 16);

    if (_elapsedInPhase >= phaseDur) {
      _completeCurrentPhase();
      return;
    }

    final t = (_elapsedInPhase.inMilliseconds / phaseDur.inMilliseconds)
        .clamp(0.0, 1.0);
    final curved = Curves.easeInOut.transform(t);
    _scale = _phaseStartScale + (p.targetScale - _phaseStartScale) * curved;
    _syncSecondsLeft();
    notifyListeners();
  }

  void _completeCurrentPhase() {
    final p = _phases[_phaseIndex];
    _scale = p.targetScale;
    _phaseStartScale = p.targetScale;
    _elapsedInPhase = Duration.zero;

    final isLast = _phaseIndex >= _phases.length - 1;
    if (!isLast) {
      _phaseIndex += 1;
      onPhaseChange?.call(_phaseIndex);
      _syncSecondsLeft();
      notifyListeners();
      return;
    }

    onCycleComplete?.call();
    _cycleIndex += 1;
    if (_cycleIndex >= cycles) {
      _finish();
      return;
    }

    _phaseIndex = 0;
    onPhaseChange?.call(_phaseIndex);
    _syncSecondsLeft();
    notifyListeners();
  }

  void _finish() {
    _finished = true;
    _running = false;
    _paused = false;
    _timer?.cancel();
    _timer = null;
    onFinished?.call();
    _syncSecondsLeft();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class BreathingRing extends StatefulWidget {
  const BreathingRing({
    super.key,
    required this.phases,
    required this.cycles,
    required this.size,
    this.controller,
    this.onPhaseChange,
    this.onCycleComplete,
    this.onFinished,
  });

  final List<BreathingPhase> phases;
  final int cycles;
  final double size;
  final BreathingRingController? controller;
  final void Function(int phaseIndex)? onPhaseChange;
  final void Function()? onCycleComplete;
  final void Function()? onFinished;

  @override
  State<BreathingRing> createState() => _BreathingRingState();
}

class _BreathingRingState extends State<BreathingRing>
    with TickerProviderStateMixin {
  late BreathingRingController _controller;
  bool _ownsController = false;
  late final AnimationController _ringRotation;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ringRotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = BreathingRingController(
        phases: widget.phases,
        cycles: widget.cycles,
        onPhaseChange: widget.onPhaseChange,
        onCycleComplete: widget.onCycleComplete,
        onFinished: widget.onFinished,
      );
      _ownsController = true;
    }
    _controller.addListener(_onCtrl);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    if (reduceMotion == _reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      if (_ringRotation.isAnimating) _ringRotation.stop();
    } else if (!_ringRotation.isAnimating) {
      _ringRotation.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant BreathingRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null &&
        widget.controller != oldWidget.controller) {
      if (_ownsController) {
        _controller.removeListener(_onCtrl);
        _controller.dispose();
        _ownsController = false;
      } else {
        _controller.removeListener(_onCtrl);
      }
      _controller = widget.controller!;
      _controller.addListener(_onCtrl);
    }
  }

  void _onCtrl() => setState(() {});

  @override
  void dispose() {
    _ringRotation.dispose();
    _controller.removeListener(_onCtrl);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = _controller.currentPhase;
    if (phase == null) {
      return SizedBox(width: widget.size, height: widget.size);
    }

    final scale = _controller.scale.clamp(0.2, 3.0);
    final orbDiameter = widget.size * 0.5;

    final delta = phase.targetScale - _controller.scale;
    final isInhale = delta > 0.01;
    final isExhale = delta < -0.01;

    final Gradient orbGradient;
    final Color glowBase;
    if (isInhale) {
      orbGradient = const LinearGradient(
        colors: [C.primary, C.gold],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      glowBase = C.primary;
    } else if (isExhale) {
      orbGradient = const LinearGradient(
        colors: [C.accent, C.calm],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      glowBase = C.accent;
    } else {
      orbGradient = C.gradientPrimary;
      glowBase = C.primary;
    }

    return Semantics(
      label:
          '${phase.label}, ${_controller.secondsLeft} секунд',
      child: RepaintBoundary(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: AnimatedBuilder(
                animation: _ringRotation,
                builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: [
                  for (int i = 0; i < 3; i++)
                    Transform.rotate(
                      angle: _ringRotation.value *
                          math.pi *
                          2 *
                          (i.isEven ? 1.0 : -1.0) *
                          (1.0 + i * 0.4),
                      child: Container(
                        width: orbDiameter * scale + (i + 1) * 16,
                        height: orbDiameter * scale + (i + 1) * 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (i == 0 ? C.primary : C.accent)
                                .withValues(alpha: 0.15 - i * 0.04),
                            width: 1.5 - i * 0.4,
                          ),
                        ),
                      ),
                    ),
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width: orbDiameter,
                      height: orbDiameter,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: orbGradient,
                        boxShadow: [
                          BoxShadow(
                            color: glowBase.withValues(
                              alpha: (0.3 * scale).clamp(0.0, 1.0),
                            ),
                            blurRadius: 28 * scale,
                            spreadRadius: 4 * scale,
                          ),
                          BoxShadow(
                            color: C.accent.withValues(
                              alpha: (0.12 * scale).clamp(0.0, 1.0),
                            ),
                            blurRadius: 48 * scale,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                ),
              ),
            ),
            const SizedBox(height: S.l),
            AnimatedSwitcher(
              duration: Anim.normal,
              switchInCurve: Anim.curve,
              switchOutCurve: Anim.curve,
              child: Text(
                phase.label,
                key: ValueKey(phase.label),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: C.text,
                      letterSpacing: 1.2,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: S.xs),
            Text(
              '${_controller.secondsLeft} сек',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: C.textSec,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
