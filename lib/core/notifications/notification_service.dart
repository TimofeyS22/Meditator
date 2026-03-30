import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:meditator/app/router.dart';
import 'package:meditator/core/api/api_service.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'meditator_micro';
  static const _channelName = 'Micro interventions';
  static const _channelDescription = 'Gentle reminders and short practices';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  int _localId = 0;
  Timer? _periodicTimer;

  Future<void> init() async {
    if (kIsWeb) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );
      await Permission.notification.request();
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    }

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final payload = launch?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        _navigateForPayload(payload);
      }
    }

    _startPeriodicCheck();
  }

  void _startPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => checkPendingNotifications(),
    );
  }

  void dispose() {
    _periodicTimer?.cancel();
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _navigateForPayload(payload);
  }

  void _navigateForPayload(String payload) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final path = routeForPayload(payload);
      if (path == null) return;
      appRouter.go(path);
    });
  }

  static String? routeForPayload(String payload) {
    final p = payload.trim();
    if (p.isEmpty) return '/practice';

    if (p.startsWith('/')) return p;

    return routeForActionType(p);
  }

  static String? routeForActionType(String actionType) {
    final a = actionType.toLowerCase().trim();
    if (a.isEmpty) return '/micro?type=breathing';

    const map = {
      'breathe': '/breathe?id=box',
      'breathing': '/breathe?id=box',
      'breath': '/breathe?id=box',
      'breathing_reset': '/breathe?id=box',
      'morning_check_in': '/journal/new',
      'stress_day_prep': '/breathe?id=box',
      'gentle_return': '/insights',
      'late_night': '/ai-play?duration=10&mood=sleep',
      'streak_encourage': '/practice',
      'streak_reminder': '/breathing',
      'weekly_reflection': '/journal/new',
      'ai-play': '/ai-play',
      'ai_play': '/ai-play',
      'meditation': '/ai-play',
      'ai_meditation': '/ai-play',
      'ai': '/ai-play',
      'body_scan': '/micro?type=body_scan',
      'gratitude': '/micro?type=gratitude',
      'grounding': '/micro?type=grounding',
    };

    if (map.containsKey(a)) return map[a];

    if (a.startsWith('micro:')) {
      final t = a.substring(6);
      if (t.isEmpty) return '/micro?type=breathing';
      return '/micro?type=${Uri.encodeQueryComponent(t)}';
    }

    return '/micro?type=breathing';
  }

  Future<void> showMicroIntervention(
    String title,
    String body,
    String actionType, {
    String? route,
  }) async {
    if (kIsWeb) return;

    final payload = route ?? actionType.trim();
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    _localId = (_localId + 1) & 0x7fffffff;
    await _plugin.show(_localId, title, body, details, payload: payload);
  }

  Future<void> triggerAnalysis() async {
    if (kIsWeb) return;
    try {
      await ApiService.instance.triggerNotificationAnalysis();
    } catch (_) {}
  }

  Future<void> checkPendingNotifications() async {
    if (kIsWeb) return;

    final list = await ApiService.instance.getPendingNotifications();
    for (final n in list) {
      final title = n['title'] as String? ?? 'Meditator';
      final body = n['body'] as String? ?? '';
      final actionType = (n['action_type'] as String?) ?? 'micro:breathing';
      final actionData = n['action_data'] as Map<String, dynamic>?;
      final route = actionData?['route'] as String?;
      await showMicroIntervention(title, body, actionType, route: route);
    }
  }
}
