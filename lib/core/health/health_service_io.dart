import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:health/health.dart';

class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  final Health _health = Health();
  bool _configured = false;
  bool _authorized = false;

  static const List<HealthDataType> _readTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
  ];

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  Future<bool> requestAuthorization() async {
    if (kIsWeb) return false;
    await _ensureConfigured();
    final types = _readTypes.where(_health.isDataTypeAvailable).toList();
    if (types.isEmpty) return false;
    try {
      final ok = await _health.requestAuthorization(types);
      _authorized = ok;
      return ok;
    } catch (_) {
      return false;
    }
  }

  bool get isAuthorized => _authorized;

  Future<double?> _latestNumericSample(
    HealthDataType type,
    Duration window,
  ) async {
    if (kIsWeb) return null;
    await _ensureConfigured();
    if (!_health.isDataTypeAvailable(type)) return null;
    final end = DateTime.now();
    final start = end.subtract(window);
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [type],
        startTime: start,
        endTime: end,
      );
      if (points.isEmpty) return null;
      points.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      final v = points.first.value;
      if (v is NumericHealthValue) return v.numericValue.toDouble();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<double?> getCurrentHeartRate() async {
    return _latestNumericSample(
      HealthDataType.HEART_RATE,
      const Duration(hours: 1),
    );
  }

  Future<double?> getHRV() async {
    return _latestNumericSample(
      HealthDataType.HEART_RATE_VARIABILITY_SDNN,
      const Duration(hours: 1),
    );
  }

  Future<int> getStepsToday() async {
    if (kIsWeb) return 0;
    await _ensureConfigured();
    if (!_health.isDataTypeAvailable(HealthDataType.STEPS)) return 0;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    try {
      final steps = await _health.getTotalStepsInInterval(start, now);
      return steps ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<double?> getSleepHours() async {
    if (kIsWeb) return null;
    await _ensureConfigured();
    if (!_health.isDataTypeAvailable(HealthDataType.SLEEP_ASLEEP)) return null;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final windowStart = startOfToday.subtract(const Duration(hours: 18));
    final windowEnd = startOfToday.add(const Duration(hours: 14));
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP],
        startTime: windowStart,
        endTime: windowEnd,
      );
      if (points.isEmpty) return null;
      double minutes = 0;
      for (final p in points) {
        final v = p.value;
        if (v is NumericHealthValue) minutes += v.numericValue.toDouble();
      }
      if (minutes <= 0) return null;
      return minutes / 60.0;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> collectSnapshot() async {
    if (kIsWeb) {
      return {};
    }
    await _ensureConfigured();
    final heartRate = await getCurrentHeartRate();
    final hrv = await getHRV();
    final steps = await getStepsToday();
    final sleepHours = await getSleepHours();
    return {
      'heart_rate_bpm': heartRate,
      'hrv_sdnn_ms': hrv,
      'steps_today': steps,
      'sleep_hours_recent': sleepHours,
      'captured_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
