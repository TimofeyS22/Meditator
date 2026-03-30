import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:meditator/core/api/api_client.dart';

class ChatSource {
  ChatSource({required this.content, required this.source, required this.category});
  final String content;
  final String source;
  final String category;

  factory ChatSource.fromJson(Map<String, dynamic> json) => ChatSource(
        content: json['content'] as String? ?? '',
        source: json['source'] as String? ?? '',
        category: json['category'] as String? ?? '',
      );
}

class ChatResponse {
  ChatResponse({required this.reply, this.sources = const []});
  final String reply;
  final List<ChatSource> sources;
}

class Backend {
  Backend._();
  static final Backend instance = Backend._();

  Dio get _dio => ApiClient.instance.dio;

  Future<Map<String, dynamic>> generateMeditation({
    required String mood,
    required String goal,
    required int durationMinutes,
    String? userContext,
  }) async {
    final body = <String, dynamic>{
      'mood': mood,
      'goal': goal,
      'duration_minutes': durationMinutes,
    };
    if (userContext != null && userContext.isNotEmpty) {
      body['user_context'] = userContext;
    }
    final resp = await _dio.post('/ai/generate-meditation', data: body);
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Uint8List> textToSpeech({
    required String text,
    String? voiceId,
    String? modelId,
  }) async {
    final body = <String, dynamic>{'text': text};
    if (voiceId != null && voiceId.isNotEmpty) body['voice_id'] = voiceId;
    if (modelId != null && modelId.isNotEmpty) body['model_id'] = modelId;
    final resp = await _dio.post(
      '/ai/tts',
      data: body,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(resp.data as List<int>);
  }

  Future<ChatResponse> chat({
    required List<Map<String, String>> messages,
    String? userContext,
    bool stream = false,
  }) async {
    final body = <String, dynamic>{
      'messages': messages,
      'stream': stream,
    };
    if (userContext != null && userContext.isNotEmpty) {
      body['user_context'] = userContext;
    }
    final resp = await _dio.post('/ai/chat', data: body);
    final data = Map<String, dynamic>.from(resp.data as Map);
    final sources = (data['sources'] as List?)
            ?.map((s) => ChatSource.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList() ??
        [];
    return ChatResponse(reply: data['reply'] as String? ?? '', sources: sources);
  }

  Stream<String> chatStream({
    required List<Map<String, String>> messages,
    String? userContext,
  }) async* {
    final body = <String, dynamic>{
      'messages': messages,
      'stream': true,
    };
    if (userContext != null && userContext.isNotEmpty) {
      body['user_context'] = userContext;
    }
    final resp = await _dio.post(
      '/ai/chat',
      data: body,
      options: Options(responseType: ResponseType.stream),
    );
    final stream = resp.data.stream as Stream<List<int>>;
    String buffer = '';
    await for (final chunk in stream) {
      buffer += utf8.decode(chunk);
      while (buffer.contains('\n')) {
        final idx = buffer.indexOf('\n');
        final line = buffer.substring(0, idx).trim();
        buffer = buffer.substring(idx + 1);
        if (line.startsWith('data:')) {
          final payload = line.substring(5).trim();
          if (payload == '{}' || payload.isEmpty) continue;
          try {
            final json = jsonDecode(payload) as Map<String, dynamic>;
            final content = json['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          } catch (_) {}
        }
      }
    }
  }

  Future<Map<String, dynamic>> analyzeMood({
    required List<Map<String, dynamic>> entries,
    required List<String> userGoals,
  }) async {
    final mapped = entries.map((e) => {
      'emotion': e['primary_emotion'] ?? e['primary'] ?? e['emotion'] ?? '',
      'intensity': e['intensity'] ?? 3,
      if (e['note'] != null) 'note': e['note'],
      'created_at': e['created_at'] ?? e['createdAt'] ?? DateTime.now().toIso8601String(),
    }).toList();

    final resp = await _dio.post('/ai/analyze-mood', data: {
      'entries': mapped,
      'user_goals': userGoals,
    });
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>?> getSubscription() async {
    try {
      final resp = await _dio.get('/subscriptions/me');
      if (resp.data == null) return null;
      return Map<String, dynamic>.from(resp.data as Map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      rethrow;
    }
  }
}
