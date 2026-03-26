import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:meditator/app/theme.dart';

enum Emotion {
  joy,
  gratitude,
  peace,
  love,
  hope,
  pride,
  excitement,
  serenity,
  curiosity,
  inspiration,
  playfulness,
  confidence,
  anxiety,
  sadness,
  anger,
  fear,
  loneliness,
  overwhelm,
  guilt,
  shame,
  frustration,
  boredom,
  jealousy,
  fatigue,
}

extension EmotionX on Emotion {
  String get label => switch (this) {
        Emotion.joy => 'Радость',
        Emotion.gratitude => 'Благодарность',
        Emotion.peace => 'Покой',
        Emotion.love => 'Любовь',
        Emotion.hope => 'Надежда',
        Emotion.pride => 'Гордость',
        Emotion.excitement => 'Восторг',
        Emotion.serenity => 'Безмятежность',
        Emotion.curiosity => 'Любопытство',
        Emotion.inspiration => 'Вдохновение',
        Emotion.playfulness => 'Игривость',
        Emotion.confidence => 'Уверенность',
        Emotion.anxiety => 'Тревога',
        Emotion.sadness => 'Грусть',
        Emotion.anger => 'Злость',
        Emotion.fear => 'Страх',
        Emotion.loneliness => 'Одиночество',
        Emotion.overwhelm => 'Перегруз',
        Emotion.guilt => 'Вина',
        Emotion.shame => 'Стыд',
        Emotion.frustration => 'Фрустрация',
        Emotion.boredom => 'Скука',
        Emotion.jealousy => 'Ревность',
        Emotion.fatigue => 'Усталость',
      };

  String get emoji => switch (this) {
        Emotion.joy => '😄',
        Emotion.gratitude => '🙏',
        Emotion.peace => '🕊️',
        Emotion.love => '💕',
        Emotion.hope => '🌈',
        Emotion.pride => '🌟',
        Emotion.excitement => '🤩',
        Emotion.serenity => '😌',
        Emotion.curiosity => '🧐',
        Emotion.inspiration => '💡',
        Emotion.playfulness => '🎈',
        Emotion.confidence => '💪',
        Emotion.anxiety => '😰',
        Emotion.sadness => '😢',
        Emotion.anger => '😤',
        Emotion.fear => '😨',
        Emotion.loneliness => '🥺',
        Emotion.overwhelm => '😵',
        Emotion.guilt => '😔',
        Emotion.shame => '🫣',
        Emotion.frustration => '😣',
        Emotion.boredom => '😑',
        Emotion.jealousy => '😒',
        Emotion.fatigue => '😪',
      };

  bool get isPositive => switch (this) {
        Emotion.joy => true,
        Emotion.gratitude => true,
        Emotion.peace => true,
        Emotion.love => true,
        Emotion.hope => true,
        Emotion.pride => true,
        Emotion.excitement => true,
        Emotion.serenity => true,
        Emotion.curiosity => true,
        Emotion.inspiration => true,
        Emotion.playfulness => true,
        Emotion.confidence => true,
        _ => false,
      };

  Color get color => switch (this) {
        Emotion.joy => C.happy,
        Emotion.gratitude => C.grateful,
        Emotion.peace => C.calm,
        Emotion.love => C.rose,
        Emotion.hope => C.accent,
        Emotion.pride => C.gold,
        Emotion.excitement => C.energy,
        Emotion.serenity => C.accentLight,
        Emotion.curiosity => C.primary,
        Emotion.inspiration => C.primaryMuted,
        Emotion.playfulness => C.happy,
        Emotion.confidence => C.ok,
        Emotion.anxiety => C.anxious,
        Emotion.sadness => C.sad,
        Emotion.anger => C.error,
        Emotion.fear => C.anxious,
        Emotion.loneliness => C.sad,
        Emotion.overwhelm => C.error,
        Emotion.guilt => C.textSec,
        Emotion.shame => C.textDim,
        Emotion.frustration => C.energy,
        Emotion.boredom => C.textDim,
        Emotion.jealousy => C.anxious,
        Emotion.fatigue => C.sad,
      };
}

Emotion? _emotionFromJson(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  for (final e in Emotion.values) {
    if (e.name == v) return e;
  }
  return null;
}

class MoodEntry extends Equatable {
  const MoodEntry({
    required this.id,
    required this.userId,
    required this.primary,
    this.secondary = const [],
    this.intensity = 3,
    this.note,
    this.aiInsight,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final Emotion primary;
  final List<Emotion> secondary;
  final int intensity;
  final String? note;
  final String? aiInsight;
  final DateTime createdAt;

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    final secRaw = json['secondary'];
    final secondary = <Emotion>[];
    if (secRaw is List) {
      for (final e in secRaw) {
        if (e is String) {
          final em = _emotionFromJson(e);
          if (em != null) secondary.add(em);
        }
      }
    }

    final ir = json['intensity'];
    var intensity = ir is num ? ir.round() : 3;
    if (intensity < 1) intensity = 1;
    if (intensity > 5) intensity = 5;

    return MoodEntry(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      primary: _emotionFromJson(json['primary']) ?? Emotion.peace,
      secondary: secondary,
      intensity: intensity,
      note: json['note'] as String?,
      aiInsight: json['aiInsight'] as String? ?? json['ai_insight'] as String?,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'primary': primary.name,
        'secondary': secondary.map((e) => e.name).toList(),
        'intensity': intensity,
        'note': note,
        'aiInsight': aiInsight,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, userId, primary, secondary, intensity, note, aiInsight, createdAt];
}
