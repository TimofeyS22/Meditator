import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class Backend {
  Backend._();

  static final Backend instance = Backend._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<Map<String, dynamic>> generateMeditation({
    required String mood,
    required String goal,
    required int durationMinutes,
  }) async {
    final res = await _client.functions.invoke(
      'generate-meditation',
      body: {
        'mood': mood,
        'goal': goal,
        'durationMinutes': durationMinutes,
      },
    );
    _ensureOk(res);
    return _asJsonMap(res.data);
  }

  Future<Uint8List> textToSpeech({
    required String text,
    String? voiceId,
  }) async {
    final res = await _client.functions.invoke(
      'tts',
      body: {
        'text': text,
        'voiceId': ?voiceId,
      },
    );
    _ensureOk(res);
    return _asAudioBytes(res.data);
  }

  Future<Map<String, dynamic>> analyzeMood({
    required List<Map<String, dynamic>> entries,
    required List<String> userGoals,
  }) async {
    final res = await _client.functions.invoke(
      'analyze-mood',
      body: {
        'entries': entries,
        'userGoals': userGoals,
      },
    );
    _ensureOk(res);
    return _asJsonMap(res.data);
  }

  void _ensureOk(FunctionResponse res) {
    if (res.status >= 200 && res.status < 300) return;
    throw FunctionException(status: res.status, details: res.data);
  }

  Map<String, dynamic> _asJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw const FormatException('Ответ функции не является JSON-объектом');
  }

  Uint8List _asAudioBytes(dynamic data) {
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    if (data is Map) {
      final b64 = data['audio'] ?? data['data'];
      if (b64 is String) {
        return Uint8List.fromList(base64Decode(b64));
      }
    }
    throw const FormatException('Некорректный бинарный ответ TTS');
  }
}
