import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meditator/core/config/env.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _kAccessToken = 'auth_access_token';
  static const _kRefreshToken = 'auth_refresh_token';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _accessToken;
  String? _refreshToken;
  bool _loaded = false;

  Completer<bool>? _refreshLock;

  late final Dio dio = Dio(BaseOptions(
    baseUrl: Env.apiUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
    headers: {'Content-Type': 'application/json'},
  ))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        await _ensureLoaded();
        if (_accessToken != null && _accessToken!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 &&
            error.requestOptions.extra['_retried'] != true) {
          final refreshed = await _tryRefreshSafe();
          if (refreshed) {
            error.requestOptions.extra['_retried'] = true;
            error.requestOptions.headers['Authorization'] =
                'Bearer $_accessToken';
            try {
              final resp = await dio.fetch(error.requestOptions);
              return handler.resolve(resp);
            } catch (e) {
              return handler.reject(error);
            }
          }
        }
        handler.next(error);
      },
    ));

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _accessToken = await _storage.read(key: _kAccessToken);
    _refreshToken = await _storage.read(key: _kRefreshToken);
    _loaded = true;
  }

  Future<bool> _tryRefreshSafe() async {
    if (_refreshLock != null) {
      return _refreshLock!.future;
    }
    _refreshLock = Completer<bool>();
    try {
      final result = await _tryRefresh();
      _refreshLock!.complete(result);
      return result;
    } catch (e) {
      _refreshLock!.complete(false);
      return false;
    } finally {
      _refreshLock = null;
    }
  }

  Future<bool> _tryRefresh() async {
    await _ensureLoaded();
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;
    try {
      final resp = await Dio(BaseOptions(baseUrl: Env.apiUrl)).post(
        '/auth/refresh',
        data: {'refresh_token': _refreshToken},
      );
      if (resp.statusCode == 200) {
        await saveTokens(
          resp.data['access_token'] as String,
          resp.data['refresh_token'] as String,
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    await _storage.write(key: _kAccessToken, value: access);
    await _storage.write(key: _kRefreshToken, value: refresh);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }

  Future<bool> get hasToken async {
    await _ensureLoaded();
    return _accessToken != null && _accessToken!.isNotEmpty;
  }
}
