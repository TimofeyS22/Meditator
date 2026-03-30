import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class AppError {
  static String messageFromDio(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Сервер не отвечает. Проверьте подключение к интернету.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Нет подключения к интернету.';
    }
    final status = e.response?.statusCode;
    if (status == null) return 'Произошла ошибка. Попробуйте позже.';

    final body = e.response?.data;
    if (body is Map<String, dynamic> && body.containsKey('detail')) {
      return body['detail'] as String;
    }

    return switch (status) {
      401 => 'Сессия истекла. Войдите заново.',
      403 => 'Недостаточно прав.',
      404 => 'Ресурс не найден.',
      409 => 'Конфликт данных.',
      429 => 'Слишком много запросов. Подождите.',
      >= 500 => 'Ошибка сервера. Мы уже работаем над этим.',
      _ => 'Произошла ошибка ($status).',
    };
  }

  static void show(String message) {
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void showDio(DioException e) => show(messageFromDio(e));
}
