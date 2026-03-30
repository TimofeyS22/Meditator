import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/health/health_service.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';

enum BiometricState { rising, stable, dropping, unknown }

class BiometricData {
  BiometricData({this.heartRate, this.hrv, this.state = BiometricState.unknown});
  final double? heartRate;
  final double? hrv;
  final BiometricState state;

  bool get hasData => heartRate != null;
}

class BiometricMonitor extends ChangeNotifier {
  BiometricMonitor() {
    _init();
  }

  Timer? _timer;
  final List<double> _hrHistory = [];
  BiometricData _data = BiometricData();

  BiometricData get data => _data;

  Future<void> _init() async {
    final auth = HealthService.instance.isAuthorized;
    if (!auth) {
      await HealthService.instance.requestAuthorization();
    }
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final hr = await HealthService.instance.getCurrentHeartRate();
      final hrv = await HealthService.instance.getHRV();

      BiometricState state = BiometricState.unknown;
      if (hr != null) {
        _hrHistory.add(hr);
        if (_hrHistory.length > 10) _hrHistory.removeAt(0);

        if (_hrHistory.length >= 3) {
          final recent = _hrHistory.sublist(_hrHistory.length - 3);
          final trend = recent.last - recent.first;
          if (trend > 3) {
            state = BiometricState.rising;
          } else if (trend < -3) {
            state = BiometricState.dropping;
          } else {
            state = BiometricState.stable;
          }
        }
      }

      _data = BiometricData(heartRate: hr, hrv: hrv, state: state);
      notifyListeners();
    } catch (_) {}
  }

  String get adaptiveHint {
    switch (_data.state) {
      case BiometricState.rising:
        return 'Пульс повышается — давай замедлимся';
      case BiometricState.dropping:
        return 'Пульс снижается — отлично, расслабление идёт';
      case BiometricState.stable:
        if ((_data.heartRate ?? 80) < 65) {
          return 'Глубокое расслабление — переходим к следующей фазе';
        }
        return 'Стабильный ритм — всё идёт хорошо';
      case BiometricState.unknown:
        return '';
    }
  }

  double get ambientIntensity {
    final hr = _data.heartRate ?? 72;
    if (hr > 90) return 0.8;
    if (hr > 75) return 0.5;
    return 0.3;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class BiometricOverlay extends StatelessWidget {
  const BiometricOverlay({super.key, required this.monitor});
  final BiometricMonitor monitor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final data = monitor.data;
        if (!data.hasData) {
          return _NoDataHint();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.m, vertical: S.s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _HeartRateWidget(
                    bpm: data.heartRate!,
                    state: data.state,
                  ),
                  if (data.hrv != null) ...[
                    const SizedBox(width: S.l),
                    _HRVWidget(hrv: data.hrv!),
                  ],
                ],
              ),
              if (monitor.adaptiveHint.isNotEmpty) ...[
                const SizedBox(height: S.s),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    monitor.adaptiveHint,
                    key: ValueKey(monitor.adaptiveHint),
                    style: t.bodySmall?.copyWith(
                      color: _stateColor(data.state),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ).animate().fadeIn(duration: 600.ms),
        );
      },
    );
  }

  Color _stateColor(BiometricState state) => switch (state) {
        BiometricState.rising => C.warm,
        BiometricState.dropping => C.accent,
        BiometricState.stable => C.calm,
        BiometricState.unknown => C.textDim,
      };
}

class _NoDataHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: S.m, vertical: S.s),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          MIcon(MIconType.heart, size: 14, color: context.cTextDim),
          const SizedBox(width: S.xs),
          Text(
            'Часы не подключены',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _HeartRateWidget extends StatefulWidget {
  const _HeartRateWidget({required this.bpm, required this.state});
  final double bpm;
  final BiometricState state;

  @override
  State<_HeartRateWidget> createState() => _HeartRateWidgetState();
}

class _HeartRateWidgetState extends State<_HeartRateWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beatCtrl;

  @override
  void initState() {
    super.initState();
    final bpm = widget.bpm.clamp(40, 180);
    final beatDuration = Duration(milliseconds: (60000 / bpm).round());
    _beatCtrl = AnimationController(vsync: this, duration: beatDuration)
      ..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _HeartRateWidget old) {
    super.didUpdateWidget(old);
    if (old.bpm != widget.bpm) {
      final bpm = widget.bpm.clamp(40, 180);
      _beatCtrl.duration = Duration(milliseconds: (60000 / bpm).round());
    }
  }

  @override
  void dispose() {
    _beatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = switch (widget.state) {
      BiometricState.rising => C.rose,
      BiometricState.dropping => C.accent,
      BiometricState.stable => C.calm,
      BiometricState.unknown => C.textSec,
    };

    return AnimatedBuilder(
      animation: _beatCtrl,
      builder: (ctx, child) => Transform.scale(
        scale: 1.0 + 0.08 * _beatCtrl.value,
        child: child,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MIcon(MIconType.heart, size: 20, color: color),
          const SizedBox(width: 6),
          Text(
            '${widget.bpm.round()}',
            style: t.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 2),
          Text('уд/м', style: t.labelSmall?.copyWith(color: color.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

class _HRVWidget extends StatelessWidget {
  const _HRVWidget({required this.hrv});
  final double hrv;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final good = hrv > 40;
    final color = good ? C.accent : C.warm;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text('HRV ', style: t.labelSmall),
        Text(
          '${hrv.round()} мс',
          style: t.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
