import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  LocalCache._();
  static final LocalCache instance = LocalCache._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  static const _prefix = 'lcache_';
  static const _tsPrefix = 'lcache_ts_';

  static const Duration defaultTTL = Duration(minutes: 30);

  Future<void> put(String key, Object data, {Duration? ttl}) async {
    final prefs = await _p;
    await prefs.setString('$_prefix$key', jsonEncode(data));
    await prefs.setInt(
      '$_tsPrefix$key',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<T?> get<T>(String key, {Duration ttl = defaultTTL}) async {
    final prefs = await _p;
    final ts = prefs.getInt('$_tsPrefix$key');
    if (ts != null) {
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > ttl.inMilliseconds) return null;
    }
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded as T;
    } catch (_) {
      return null;
    }
  }

  Future<T?> getStale<T>(String key) async {
    final prefs = await _p;
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as T;
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    final prefs = await _p;
    await prefs.remove('$_prefix$key');
    await prefs.remove('$_tsPrefix$key');
  }

  Future<void> clear() async {
    final prefs = await _p;
    final keys = prefs.getKeys().where(
        (k) => k.startsWith(_prefix) || k.startsWith(_tsPrefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}

abstract class CacheKeys {
  static const profile = 'profile';
  static const meditations = 'meditations';
  static const moodEntries = 'mood_entries';
  static const gardenPlants = 'garden_plants';
}
