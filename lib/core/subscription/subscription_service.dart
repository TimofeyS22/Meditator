import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:meditator/core/api/api_client.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  static const _kIsPremium = 'is_premium_cached';

  final ValueNotifier<bool> isPremium = ValueNotifier(false);

  Dio get _dio => ApiClient.instance.dio;
  Timer? _pollTimer;
  StreamSubscription<AuthUser?>? _authSub;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    isPremium.value = prefs.getBool(_kIsPremium) ?? false;

    if (AuthService.instance.userId != null) {
      await refresh();
    }

    _authSub?.cancel();
    _authSub = AuthService.instance.onAuthChange.listen((user) {
      if (user != null) {
        refresh();
      } else {
        _updatePremium(false);
        stopPolling();
      }
    });
  }

  Future<bool> refresh() async {
    try {
      final resp = await _dio.get('/subscriptions/me');
      if (resp.data == null) {
        _updatePremium(false);
        return false;
      }
      final data = resp.data as Map<String, dynamic>;
      final status = data['status'] as String?;
      final active = status == 'active';
      _updatePremium(active);
      return active;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) _updatePremium(false);
      return isPremium.value;
    }
  }

  /// Start polling every [interval] — use after returning from payment.
  void startPolling({Duration interval = const Duration(seconds: 5)}) {
    stopPolling();
    _pollTimer = Timer.periodic(interval, (_) => refresh());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<String?> createPayment(String plan) async {
    final resp = await _dio.post(
      '/subscriptions/create-payment',
      data: {'plan': plan},
    );
    final data = resp.data as Map<String, dynamic>;
    return data['payment_url'] as String?;
  }

  void _updatePremium(bool value) async {
    isPremium.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsPremium, value);
  }
}
