import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meditator/core/api/api_client.dart';

class AuthUser {
  AuthUser({required this.id, this.email, this.displayName});
  final String id;
  final String? email;
  final String? displayName;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _ctrl = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  AuthUser? get currentUser => _currentUser;
  String? get userId => _currentUser?.id;
  Stream<AuthUser?> get onAuthChange => _ctrl.stream;

  Future<AuthUser> signUp(String email, String password, {String? displayName}) async {
    try {
      final resp = await ApiClient.instance.dio.post('/auth/signup', data: {
        'email': email,
        'password': password,
        if (displayName != null) 'display_name': displayName,
      });
      return await _handleAuthResponse(resp.data as Map<String, dynamic>);
    } on DioException {
      rethrow;
    }
  }

  Future<AuthUser> signIn(String email, String password) async {
    try {
      final resp = await ApiClient.instance.dio.post('/auth/signin', data: {
        'email': email,
        'password': password,
      });
      return await _handleAuthResponse(resp.data as Map<String, dynamic>);
    } on DioException {
      rethrow;
    }
  }

  /// Always succeeds with HTTP 200 when the server follows the standard
  /// "do not reveal if email exists" contract.
  Future<void> requestPasswordReset(String email) async {
    await ApiClient.instance.dio.post('/auth/forgot-password', data: {
      'email': email,
    });
  }

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> signOut() async {
    try {
      final refresh = await _secureStorage.read(key: 'auth_refresh_token');
      if (refresh != null && refresh.isNotEmpty) {
        await ApiClient.instance.dio.post('/auth/logout', data: {'refresh_token': refresh});
      }
    } catch (_) {}
    await ApiClient.instance.clearTokens();
    _currentUser = null;
    _ctrl.add(null);
  }

  Future<AuthUser?> tryRestoreSession() async {
    if (!await ApiClient.instance.hasToken) {
      _ctrl.add(null);
      return null;
    }
    try {
      final resp = await ApiClient.instance.dio.get('/auth/me');
      final data = resp.data as Map<String, dynamic>;
      _currentUser = AuthUser(
        id: data['id'] as String,
        email: data['email'] as String?,
        displayName: data['display_name'] as String?,
      );
      _ctrl.add(_currentUser);
      return _currentUser;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        await ApiClient.instance.clearTokens();
        _currentUser = null;
        _ctrl.add(null);
      }
      // On network errors (timeout, connection error) — keep tokens, work offline
      return _currentUser;
    }
  }

  Future<AuthUser> _handleAuthResponse(Map<String, dynamic> data) async {
    final access = data['access_token'] as String;
    final refresh = data['refresh_token'] as String;
    await ApiClient.instance.saveTokens(access, refresh);

    final userMap = data['user'] as Map<String, dynamic>;
    _currentUser = AuthUser(
      id: userMap['id'] as String,
      email: userMap['email'] as String?,
      displayName: userMap['display_name'] as String?,
    );
    _ctrl.add(_currentUser);
    return _currentUser!;
  }
}
