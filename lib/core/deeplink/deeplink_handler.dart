import 'package:flutter/services.dart';
import 'package:meditator/app/router.dart';

class DeeplinkHandler {
  DeeplinkHandler._();
  static final DeeplinkHandler instance = DeeplinkHandler._();

  static const _channel = MethodChannel('com.meditatorapp.meditator/deeplink');
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'navigate') {
      final route = call.arguments as String?;
      if (route != null && route.isNotEmpty) {
        _navigateTo(route);
      }
    }
  }

  void handleUri(Uri uri) {
    final path = uri.path.isEmpty ? '/${uri.host}' : uri.path;
    final query = uri.query.isNotEmpty ? '?${uri.query}' : '';
    _navigateTo('$path$query');
  }

  void _navigateTo(String route) {
    try {
      appRouter.go(route);
    } catch (_) {
      appRouter.go('/practice');
    }
  }
}
