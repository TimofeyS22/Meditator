import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MeditationCache {
  MeditationCache._();
  static final MeditationCache instance = MeditationCache._();

  static const _key = 'cached_meditations';
  static const _tsKey = 'cached_meditations_ts';

  Future<void> save(List<Map<String, dynamic>> meditations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(meditations));
    await prefs.setInt(_tsKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<Map<String, dynamic>>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<bool> get hasCachedData async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }
}
