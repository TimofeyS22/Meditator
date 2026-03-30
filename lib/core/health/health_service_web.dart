class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  Future<bool> requestAuthorization() async => false;

  bool get isAuthorized => false;

  Future<double?> getCurrentHeartRate() async => null;

  Future<double?> getHRV() async => null;

  Future<int> getStepsToday() async => 0;

  Future<double?> getSleepHours() async => null;

  Future<Map<String, dynamic>> collectSnapshot() async => {};
}
