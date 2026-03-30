import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

T? _enumByName<T extends Enum>(List<T> values, String? name) {
  if (name == null || name.isEmpty) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

enum MeditationGoal {
  sleep,
  stress,
  focus,
  anxiety,
  selfGrowth,
  happiness,
  relationships,
}

extension MeditationGoalX on MeditationGoal {
  String get label => switch (this) {
        MeditationGoal.sleep => 'Сон',
        MeditationGoal.stress => 'Стресс',
        MeditationGoal.focus => 'Фокус',
        MeditationGoal.anxiety => 'Тревога',
        MeditationGoal.selfGrowth => 'Рост',
        MeditationGoal.happiness => 'Счастье',
        MeditationGoal.relationships => 'Отношения',
      };

  String get emoji => '';

  IconData get iconData => switch (this) {
        MeditationGoal.sleep => Icons.bedtime_rounded,
        MeditationGoal.stress => Icons.self_improvement_rounded,
        MeditationGoal.focus => Icons.center_focus_strong_rounded,
        MeditationGoal.anxiety => Icons.cloud_rounded,
        MeditationGoal.selfGrowth => Icons.eco_rounded,
        MeditationGoal.happiness => Icons.auto_awesome_rounded,
        MeditationGoal.relationships => Icons.people_rounded,
      };
}

enum StressLevel { low, moderate, high, veryHigh }

extension StressLevelX on StressLevel {
  String get label => switch (this) {
        StressLevel.low => 'Низкий',
        StressLevel.moderate => 'Умеренный',
        StressLevel.high => 'Высокий',
        StressLevel.veryHigh => 'Очень высокий',
      };
}

enum PreferredDuration { min3, min5, min10, min15, min20 }

extension PreferredDurationX on PreferredDuration {
  String get label => switch (this) {
        PreferredDuration.min3 => '3 мин',
        PreferredDuration.min5 => '5 мин',
        PreferredDuration.min10 => '10 мин',
        PreferredDuration.min15 => '15 мин',
        PreferredDuration.min20 => '20 мин',
      };

  int get minutes => switch (this) {
        PreferredDuration.min3 => 3,
        PreferredDuration.min5 => 5,
        PreferredDuration.min10 => 10,
        PreferredDuration.min15 => 15,
        PreferredDuration.min20 => 20,
      };
}

enum PreferredVoice { male, female, any }

extension PreferredVoiceX on PreferredVoice {
  static PreferredVoice fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'male':
      case 'мужской':
        return PreferredVoice.male;
      case 'female':
      case 'женский':
        return PreferredVoice.female;
      default:
        return PreferredVoice.any;
    }
  }

  String get jsonName => switch (this) {
        PreferredVoice.male => 'male',
        PreferredVoice.female => 'female',
        PreferredVoice.any => 'any',
      };
}

class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.goals = const [],
    this.stressLevel = StressLevel.moderate,
    this.preferredDuration = PreferredDuration.min10,
    this.preferredVoice = PreferredVoice.any,
    this.preferredTimeHour,
    this.isPremium = false,
    this.totalSessions = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalMinutes = 0,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final List<MeditationGoal> goals;
  final StressLevel stressLevel;
  final PreferredDuration preferredDuration;
  final PreferredVoice preferredVoice;
  final int? preferredTimeHour;
  final bool isPremium;
  final int totalSessions;
  final int currentStreak;
  final int longestStreak;
  final int totalMinutes;
  final DateTime createdAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final goalsRaw = json['goals'];
    final goals = <MeditationGoal>[];
    if (goalsRaw is List) {
      for (final e in goalsRaw) {
        if (e is String) {
          final g = _enumByName(MeditationGoal.values, e);
          if (g != null) goals.add(g);
        }
      }
    }

    final stressKey = json['stressLevel'] ?? json['stress_level'];
    final durationKey = json['preferredDuration'] ?? json['preferred_duration'];

    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['display_name'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      goals: goals,
      stressLevel: _enumByName(StressLevel.values, stressKey as String?) ?? StressLevel.moderate,
      preferredDuration:
          _enumByName(PreferredDuration.values, durationKey as String?) ?? PreferredDuration.min10,
      preferredVoice: PreferredVoiceX.fromString(
        json['preferredVoice'] as String? ?? json['preferred_voice'] as String?,
      ),
      preferredTimeHour: _parseOptionalHour(json['preferredTimeHour'] ?? json['preferred_time_hour']),
      isPremium: json['isPremium'] as bool? ?? json['is_premium'] as bool? ?? false,
      totalSessions: (json['totalSessions'] ?? json['total_sessions']) as int? ?? 0,
      currentStreak: (json['currentStreak'] ?? json['current_streak']) as int? ?? 0,
      longestStreak: (json['longestStreak'] ?? json['longest_streak']) as int? ?? 0,
      totalMinutes: (json['totalMinutes'] ?? json['total_minutes']) as int? ?? 0,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static int? _parseOptionalHour(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'goals': goals.map((e) => e.name).toList(),
        'stressLevel': stressLevel.name,
        'preferredDuration': preferredDuration.name,
        'preferredVoice': preferredVoice.jsonName,
        'preferredTimeHour': preferredTimeHour,
        'isPremium': isPremium,
        'totalSessions': totalSessions,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'totalMinutes': totalMinutes,
        'createdAt': createdAt.toIso8601String(),
      };

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    List<MeditationGoal>? goals,
    StressLevel? stressLevel,
    PreferredDuration? preferredDuration,
    PreferredVoice? preferredVoice,
    int? preferredTimeHour,
    bool? isPremium,
    int? totalSessions,
    int? currentStreak,
    int? longestStreak,
    int? totalMinutes,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      goals: goals ?? this.goals,
      stressLevel: stressLevel ?? this.stressLevel,
      preferredDuration: preferredDuration ?? this.preferredDuration,
      preferredVoice: preferredVoice ?? this.preferredVoice,
      preferredTimeHour: preferredTimeHour ?? this.preferredTimeHour,
      isPremium: isPremium ?? this.isPremium,
      totalSessions: totalSessions ?? this.totalSessions,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        avatarUrl,
        goals,
        stressLevel,
        preferredDuration,
        preferredVoice,
        preferredTimeHour,
        isPremium,
        totalSessions,
        currentStreak,
        longestStreak,
        totalMinutes,
        createdAt,
      ];
}
