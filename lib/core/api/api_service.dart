import 'package:dio/dio.dart';
import 'package:meditator/core/api/api_client.dart';
import 'package:meditator/core/cache/local_cache.dart';
import 'package:meditator/shared/utils/error_handler.dart';

@Deprecated('Use ApiService instead')
typedef Db = ApiService;

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  Dio get _dio => ApiClient.instance.dio;
  final _cache = LocalCache.instance;

  Future<T> _safe<T>(Future<T> Function() fn, T fallback) async {
    try {
      return await fn();
    } on DioException catch (e) {
      AppError.showDio(e);
      return fallback;
    }
  }

  Future<T> _cachedSafe<T>(
    String cacheKey,
    Future<T> Function() fn,
    T fallback,
  ) async {
    try {
      final result = await fn();
      if (result != fallback) {
        _cache.put(cacheKey, result as Object);
      }
      return result;
    } on DioException catch (e) {
      final cached = await _cache.getStale<T>(cacheKey);
      if (cached != null) return cached;
      AppError.showDio(e);
      return fallback;
    }
  }

  // ── Profiles ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getProfile(String userId) =>
      _cachedSafe(CacheKeys.profile, () async {
        final resp = await _dio.get('/profiles/me');
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  Future<Map<String, dynamic>?> upsertProfile(Map<String, dynamic> row) =>
      _safe(() async {
        final resp = await _dio.put('/profiles/me', data: row);
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  Future<Map<String, dynamic>?> updateProfileField(
    String userId,
    String field,
    Object? value,
  ) =>
      _safe(() async {
        final resp = await _dio.put('/profiles/me', data: {field: value});
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  // ── Meditations ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMeditations({String? category}) =>
      _cachedSafe('${CacheKeys.meditations}_${category ?? 'all'}', () async {
        final params = <String, dynamic>{};
        if (category != null && category.isNotEmpty) params['category'] = category;
        final resp = await _dio.get('/meditations', queryParameters: params);
        return _mapList(resp.data);
      }, []);

  Future<Map<String, dynamic>?> getMeditationById(String id) =>
      _safe(() async {
        final resp = await _dio.get('/meditations/$id');
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  // ── Sessions ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> insertSession(Map<String, dynamic> row) =>
      _safe(() async {
        final resp = await _dio.post('/sessions', data: row);
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  Future<Map<String, dynamic>?> createSession(Map<String, dynamic> row) =>
      insertSession(row);

  Future<List<Map<String, dynamic>>> getSessionsForUser(
    String userId, {
    int? limit,
  }) =>
      _safe(() async {
        final params = <String, dynamic>{};
        if (limit != null) params['limit'] = limit;
        final resp = await _dio.get('/sessions', queryParameters: params);
        return _mapList(resp.data);
      }, []);

  // ── Mood entries ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMoodEntries(
    String userId, {
    int? limit,
  }) =>
      _cachedSafe(CacheKeys.moodEntries, () async {
        final params = <String, dynamic>{};
        if (limit != null) params['limit'] = limit;
        final resp = await _dio.get('/mood-entries', queryParameters: params);
        return _mapList(resp.data);
      }, []);

  Future<Map<String, dynamic>?> insertMoodEntry(Map<String, dynamic> row) =>
      _safe(() async {
        final resp = await _dio.post('/mood-entries', data: row);
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  Future<bool> deleteMoodEntry(String id) =>
      _safe(() async {
        await _dio.delete('/mood-entries/$id');
        return true;
      }, false);

  Future<bool> deleteAccount() =>
      _safe(() async {
        await _dio.delete('/profiles/me');
        return true;
      }, false);

  Future<Map<String, dynamic>?> updateMoodInsight(String id, String insight) =>
      _safe(() async {
        final resp = await _dio.patch('/mood-entries/$id/insight', data: {'ai_insight': insight});
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  // ── Garden plants ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getGarden(String userId) =>
      _cachedSafe(CacheKeys.gardenPlants, () async {
        final resp = await _dio.get('/garden-plants');
        return _mapList(resp.data);
      }, []);

  Future<Map<String, dynamic>?> insertPlant(Map<String, dynamic> row) =>
      _safe(() async {
        final resp = await _dio.post('/garden-plants', data: row);
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  Future<Map<String, dynamic>?> updatePlant(String id, Map<String, dynamic> patch) =>
      _safe(() async {
        final resp = await _dio.patch('/garden-plants/$id', data: patch);
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  // ── Partnerships ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getPartnership(String userId) =>
      _safe(() async {
        final resp = await _dio.get('/partnerships');
        if (resp.data == null) return null;
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  Future<Map<String, dynamic>?> insertPartnership(Map<String, dynamic> row) =>
      _safe(() async {
        final resp = await _dio.post('/partnerships', data: row);
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  Future<Map<String, dynamic>?> updatePartnership(String id, Map<String, dynamic> patch) =>
      _safe(() async {
        final resp = await _dio.patch('/partnerships/$id', data: patch);
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  // ── Pair messages ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPairMessages(
    String pairId, {
    int? limit,
  }) =>
      _safe(() async {
        final params = <String, dynamic>{'pair_id': pairId};
        if (limit != null) params['limit'] = limit;
        final resp = await _dio.get('/pair-messages', queryParameters: params);
        return _mapList(resp.data);
      }, []);

  Future<Map<String, dynamic>?> insertPairMessage(Map<String, dynamic> row) =>
      _safe(() async {
        final resp = await _dio.post('/pair-messages', data: row);
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  // ── AI Personal Meditation ─────────────────────────────────────────────────

  Future<Map<String, dynamic>?> generatePersonalMeditation({
    int durationMinutes = 10,
    String? moodOverride,
    String voice = 'nova',
  }) =>
      _safe(() async {
        final resp = await _dio.post('/ai/personal-meditation', data: {
          'duration_minutes': durationMinutes,
          if (moodOverride != null) 'mood_override': moodOverride,
          'voice': voice,
        });
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  Future<Map<String, dynamic>?> transcribeAudio(String filePath) =>
      _safe(() async {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(filePath, filename: 'recording.m4a'),
        });
        final resp = await _dio.post('/ai/transcribe', data: formData);
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  Future<Map<String, dynamic>?> voiceCheckin(String filePath) =>
      _safe(() async {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(filePath, filename: 'checkin.m4a'),
        });
        final resp = await _dio.post('/ai/voice-checkin', data: formData);
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  // ── Biometrics (HealthKit / Health Connect) ───────────────────────────────

  Future<Map<String, dynamic>?> submitBiometrics(Map<String, dynamic> data) =>
      _safe(() async {
        final resp = await _dio.post('/biometrics', data: data);
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  Future<Map<String, dynamic>?> getSessionContext(Map<String, dynamic> biometrics) =>
      _safe(() async {
        final resp = await _dio.post('/biometrics/session-context', data: biometrics);
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  // ── Notifications (polling + future push token registration) ────────────

  Future<List<Map<String, dynamic>>> getPendingNotifications() =>
      _safe(() async {
        final resp = await _dio.get('/notifications/pending');
        return _mapList(resp.data);
      }, []);

  Future<bool> registerPushToken(String token, String platform) =>
      _safe(() async {
        await _dio.post('/notifications/token', data: {'token': token, 'platform': platform});
        return true;
      }, false);

  Future<Map<String, dynamic>?> triggerNotificationAnalysis() =>
      _safe(() async {
        final resp = await _dio.post('/notifications/analyze');
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  Future<Map<String, dynamic>?> getMonthlyDigest() =>
      _safe(() async {
        final resp = await _dio.post('/ai/monthly-digest');
        return Map<String, dynamic>.from(resp.data as Map);
      }, null);

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _mapList(dynamic data) {
    if (data is! List) return [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
