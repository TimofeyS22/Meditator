import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _accessKey = 'access_token';
const _refreshKey = 'refresh_token';

class ApiClient {
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiClient() {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final token = await _storage.read(key: _accessKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        } catch (_) {}
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          try {
            final ok = await _tryRefresh();
            if (ok) {
              final token = await _storage.read(key: _accessKey);
              error.requestOptions.headers['Authorization'] = 'Bearer $token';
              final resp = await _dio.fetch(error.requestOptions);
              return handler.resolve(resp);
            }
          } catch (_) {}
        }
        handler.next(error);
      },
    ));
  }

  Future<bool> _tryRefresh() async {
    final refresh = await _storage.read(key: _refreshKey);
    if (refresh == null) return false;
    try {
      final resp = await Dio(BaseOptions(
        baseUrl: _dio.options.baseUrl,
        headers: {'Content-Type': 'application/json'},
      )).post('/api/auth/refresh', data: {'refresh_token': refresh});
      await saveTokens(
        resp.data['access_token'] as String,
        resp.data['refresh_token'] as String,
      );
      return true;
    } catch (_) {
      await clearTokens();
      return false;
    }
  }

  Future<void> saveTokens(String access, String refresh) async {
    try {
      await _storage.write(key: _accessKey, value: access);
      await _storage.write(key: _refreshKey, value: refresh);
    } catch (_) {}
  }

  Future<void> clearTokens() async {
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } catch (_) {}
  }

  Future<bool> get hasTokens async {
    try {
      final t = await _storage.read(key: _accessKey);
      return t != null;
    } catch (_) {
      return false;
    }
  }

  // ── Auth ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register(
    String email, String password, {String? name}
  ) async {
    final resp = await _dio.post('/api/auth/register', data: {
      'email': email,
      'password': password,
      if (name != null) 'display_name': name,
    });
    final data = resp.data as Map<String, dynamic>;
    await saveTokens(data['access_token'] as String, data['refresh_token'] as String);
    return data;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final resp = await _dio.post('/api/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = resp.data as Map<String, dynamic>;
    await saveTokens(data['access_token'] as String, data['refresh_token'] as String);
    return data;
  }

  Future<void> logout() async => clearTokens();

  // ── Profile ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfile() async {
    final resp = await _dio.get('/api/profile');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final resp = await _dio.put('/api/profile', data: data);
    return resp.data as Map<String, dynamic>;
  }

  // ── Mood ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createMood({
    required String emotion,
    int intensity = 3,
    String? note,
    String? context,
  }) async {
    final resp = await _dio.post('/api/mood', data: {
      'emotion': emotion,
      'intensity': intensity,
      if (note != null) 'note': note,
      if (context != null) 'context': context,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMoodHistory({
    int limit = 50, int offset = 0,
  }) async {
    final resp = await _dio.get('/api/mood/history', queryParameters: {
      'limit': limit,
      'offset': offset,
    });
    return resp.data as Map<String, dynamic>;
  }

  // ── Sessions ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createSession({
    required String sessionType,
    required int durationSeconds,
    required bool completed,
    String? moodBefore,
    String? moodAfter,
    String? audioTrack,
  }) async {
    final resp = await _dio.post('/api/sessions', data: {
      'session_type': sessionType,
      'duration_seconds': durationSeconds,
      'completed': completed,
      if (moodBefore != null) 'mood_before': moodBefore,
      if (moodAfter != null) 'mood_after': moodAfter,
      if (audioTrack != null) 'audio_track': audioTrack,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStats() async {
    final resp = await _dio.get('/api/sessions/stats');
    return resp.data as Map<String, dynamic>;
  }

  // ── Companion ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getCompanion({
    required String currentMood,
    required int hour,
    int intensity = 3,
    int? secondsSinceLastCheckin,
  }) async {
    final resp = await _dio.post('/api/companion', data: {
      'current_mood': currentMood,
      'hour': hour,
      'intensity': intensity,
      if (secondsSinceLastCheckin != null)
        'seconds_since_last_checkin': secondsSinceLastCheckin,
    });
    return resp.data as Map<String, dynamic>;
  }
}

final apiClientProvider = Provider<ApiClient>((_) => ApiClient());
