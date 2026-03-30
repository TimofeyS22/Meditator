import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/config/env.dart';

enum MeditationCategory {
  sleep,
  stress,
  focus,
  anxiety,
  morning,
  evening,
  gratitude,
  selfLove,
  bodyScan,
  breathing,
  visualization,
  emergency,
}

extension MeditationCategoryX on MeditationCategory {
  String get label => switch (this) {
        MeditationCategory.sleep => 'Сон',
        MeditationCategory.stress => 'Стресс',
        MeditationCategory.focus => 'Фокус',
        MeditationCategory.anxiety => 'Тревога',
        MeditationCategory.morning => 'Утро',
        MeditationCategory.evening => 'Вечер',
        MeditationCategory.gratitude => 'Благодарность',
        MeditationCategory.selfLove => 'Любовь к себе',
        MeditationCategory.bodyScan => 'Скан тела',
        MeditationCategory.breathing => 'Дыхание',
        MeditationCategory.visualization => 'Визуализация',
        MeditationCategory.emergency => 'SOS',
      };

  String get emoji => '';

  IconData get iconData => switch (this) {
        MeditationCategory.sleep => Icons.bedtime_rounded,
        MeditationCategory.stress => Icons.waves_rounded,
        MeditationCategory.focus => Icons.center_focus_strong_rounded,
        MeditationCategory.anxiety => Icons.cloud_rounded,
        MeditationCategory.morning => Icons.wb_sunny_rounded,
        MeditationCategory.evening => Icons.nights_stay_rounded,
        MeditationCategory.gratitude => Icons.volunteer_activism_rounded,
        MeditationCategory.selfLove => Icons.favorite_rounded,
        MeditationCategory.bodyScan => Icons.accessibility_new_rounded,
        MeditationCategory.breathing => Icons.air_rounded,
        MeditationCategory.visualization => Icons.auto_awesome_rounded,
        MeditationCategory.emergency => Icons.flash_on_rounded,
      };

  Color get color => switch (this) {
        MeditationCategory.sleep => C.calm,
        MeditationCategory.stress => C.primary,
        MeditationCategory.focus => C.accent,
        MeditationCategory.anxiety => C.anxious,
        MeditationCategory.morning => C.happy,
        MeditationCategory.evening => C.primaryMuted,
        MeditationCategory.gratitude => C.grateful,
        MeditationCategory.selfLove => C.rose,
        MeditationCategory.bodyScan => C.accentLight,
        MeditationCategory.breathing => C.calm,
        MeditationCategory.visualization => C.gold,
        MeditationCategory.emergency => C.error,
      };
}

MeditationCategory? _meditationCategoryFromJson(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  for (final c in MeditationCategory.values) {
    if (c.name == v) return c;
  }
  return null;
}

class Meditation extends Equatable {
  const Meditation({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.durationMinutes = 10,
    this.audioUrl,
    this.imageUrl,
    this.isGenerated = false,
    this.isPremium = false,
    this.voiceName,
    this.rating = 0,
    this.playCount = 0,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final MeditationCategory category;
  final int durationMinutes;
  final String? audioUrl;
  final String? imageUrl;
  final bool isGenerated;
  final bool isPremium;
  final String? voiceName;
  final double rating;
  final int playCount;
  final DateTime createdAt;

  factory Meditation.fromJson(Map<String, dynamic> json) {
    final cat = _meditationCategoryFromJson(json['category']) ?? MeditationCategory.breathing;
    return Meditation(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: cat,
      durationMinutes: (json['durationMinutes'] ?? json['duration_minutes']) as int? ?? 10,
      audioUrl: _resolveUrl(json['audioUrl'] as String? ?? json['audio_url'] as String?),
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
      isGenerated: json['isGenerated'] as bool? ?? json['is_generated'] as bool? ?? false,
      isPremium: json['isPremium'] as bool? ?? json['is_premium'] as bool? ?? false,
      voiceName: json['voiceName'] as String? ?? json['voice_name'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      playCount: (json['playCount'] ?? json['play_count']) as int? ?? 0,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static String? _resolveUrl(String? url) {
    if (url == null || url.isEmpty) return url;
    if (url.startsWith('/')) return '${Env.apiUrl}$url';
    return url;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category.name,
        'durationMinutes': durationMinutes,
        'audioUrl': audioUrl,
        'imageUrl': imageUrl,
        'isGenerated': isGenerated,
        'isPremium': isPremium,
        'voiceName': voiceName,
        'rating': rating,
        'playCount': playCount,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        category,
        durationMinutes,
        audioUrl,
        imageUrl,
        isGenerated,
        isPremium,
        voiceName,
        rating,
        playCount,
        createdAt,
      ];
}
