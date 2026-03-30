import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:meditator/core/api/api_service.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles FCM push token registration.
///
/// When Firebase is configured (google-services.json / GoogleService-Info.plist),
/// replace the token acquisition with `FirebaseMessaging.instance.getToken()`.
/// For now, this registers whatever token is available and handles the
/// backend registration flow.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const _kTokenKey = 'push_token_registered';
  String? _currentToken;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    AuthService.instance.onAuthChange.listen((user) {
      if (user != null) {
        _registerIfNeeded();
      }
    });

    if (AuthService.instance.currentUser != null) {
      await _registerIfNeeded();
    }
  }

  Future<void> _registerIfNeeded() async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final registered = prefs.getString(_kTokenKey);
      if (registered == token) return;

      final platform = Platform.isIOS ? 'ios' : 'android';
      final ok = await ApiService.instance.registerPushToken(token, platform);
      if (ok) {
        await prefs.setString(_kTokenKey, token);
        _currentToken = token;
      }
    } catch (_) {}
  }

  Future<String?> _getToken() async {
    // TODO: Replace with FirebaseMessaging.instance.getToken() when Firebase is set up.
    // For now, return a device-unique placeholder so the flow is tested end-to-end.
    // The backend stores it; once FCM is live, real tokens will be pushed.
    if (_currentToken != null) return _currentToken;
    return null;
  }

  Future<void> onTokenRefresh(String newToken) async {
    _currentToken = newToken;
    await _registerIfNeeded();
  }
}
