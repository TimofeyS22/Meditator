import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sp async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── Onboarding ─────────────────────────────────────────────────────────

  Future<bool> get hasOnboarded async =>
      (await _sp).getBool('has_onboarded') ?? false;

  Future<void> setOnboarded() async =>
      (await _sp).setBool('has_onboarded', true);

  // ── Stats cache ────────────────────────────────────────────────────────

  Future<void> saveStats({
    required int totalSessions,
    required int streak,
    required int totalCalmEntries,
    required int totalMinutes,
    String? lastSessionDate,
  }) async {
    final p = await _sp;
    await p.setInt('total_sessions', totalSessions);
    await p.setInt('streak', streak);
    await p.setInt('total_calm_entries', totalCalmEntries);
    await p.setInt('total_minutes', totalMinutes);
    if (lastSessionDate != null) {
      await p.setString('last_session_date', lastSessionDate);
    }
  }

  Future<Map<String, dynamic>> loadStats() async {
    final p = await _sp;
    return {
      'total_sessions': p.getInt('total_sessions') ?? 0,
      'streak': p.getInt('streak') ?? 0,
      'total_calm_entries': p.getInt('total_calm_entries') ?? 0,
      'total_minutes': p.getInt('total_minutes') ?? 0,
      'last_session_date': p.getString('last_session_date'),
    };
  }

  // ── Mood history cache ─────────────────────────────────────────────────

  Future<void> saveMoodHistory(List<Map<String, dynamic>> entries) async {
    final p = await _sp;
    await p.setString('mood_history', jsonEncode(entries));
  }

  Future<List<Map<String, dynamic>>> loadMoodHistory() async {
    final p = await _sp;
    final raw = p.getString('mood_history');
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  // ── Companion state cache ──────────────────────────────────────────────

  Future<void> saveCompanionState(Map<String, dynamic> state) async {
    final p = await _sp;
    await p.setString('companion_state', jsonEncode(state));
  }

  Future<Map<String, dynamic>?> loadCompanionState() async {
    final p = await _sp;
    final raw = p.getString('companion_state');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // ── Last emotional state (continuity across launches) ─────────────────

  Future<void> saveLastEmotion(String emotion) async =>
      (await _sp).setString('last_emotion', emotion);

  Future<String?> loadLastEmotion() async =>
      (await _sp).getString('last_emotion');

  // ── Personal cosmos seed (unique star field per user) ─────────────────

  Future<int> getPersonalSeed() async {
    final p = await _sp;
    var seed = p.getInt('cosmos_seed');
    if (seed == null) {
      seed = DateTime.now().microsecondsSinceEpoch;
      await p.setInt('cosmos_seed', seed);
    }
    return seed;
  }

  Future<void> clear() async => (await _sp).clear();
}

final localStorageProvider = Provider<LocalStorage>((_) => LocalStorage());
