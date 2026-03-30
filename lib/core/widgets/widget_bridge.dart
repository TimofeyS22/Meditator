import 'dart:io';
import 'package:flutter/services.dart';

class WidgetBridge {
  WidgetBridge._();
  static final WidgetBridge instance = WidgetBridge._();

  static const _channel = MethodChannel('com.meditatorapp.meditator/widget');

  Future<void> updateWidgetData({
    required int streakCount,
    required String dailyQuote,
    required int totalMinutes,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('updateWidgetData', {
          'streak_count': streakCount,
          'daily_quote': dailyQuote,
          'total_minutes': totalMinutes,
        });
      } else if (Platform.isIOS) {
        await _channel.invokeMethod('updateWidgetData', {
          'streak_count': streakCount,
          'daily_quote': dailyQuote,
          'total_minutes': totalMinutes,
        });
      }
    } on MissingPluginException {
      // Widget channel not available on this platform build
    } catch (_) {}
  }

  static const _quotes = [
    'Каждый вдох — это новое начало.',
    'Тишина внутри тебя — бесконечна.',
    'Будь здесь и сейчас.',
    'Осознанность — путь к свободе.',
    'Даже минута тишины меняет день.',
    'Ты — не твои мысли.',
    'Дыши глубже, живи спокойнее.',
    'Момент тишины — лучший подарок себе.',
    'Покой начинается с одного вдоха.',
    'Каждый момент осознанности — победа.',
  ];

  String get dailyQuote {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return _quotes[dayOfYear % _quotes.length];
  }
}
