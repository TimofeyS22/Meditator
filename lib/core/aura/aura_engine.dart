import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meditator/core/aura/atmosphere.dart';
import 'package:meditator/core/api/api_client.dart';
import 'package:meditator/core/storage/local_storage.dart';

class MoodEntry {
  final EmotionalState state;
  final DateTime timestamp;
  const MoodEntry({required this.state, required this.timestamp});
}

class AuraState {
  final EmotionalState currentState;
  final Atmosphere atmosphere;
  final int streak;
  final int totalSessions;
  final int totalCalmEntries;
  final int totalMinutes;
  final List<MoodEntry> moodHistory;
  final bool hasCheckedIn;
  final DateTime? lastSessionDate;
  final DateTime? lastSessionCompletedAt;
  final bool lastSessionImproved;

  const AuraState({
    required this.currentState,
    required this.atmosphere,
    this.streak = 0,
    this.totalSessions = 0,
    this.totalCalmEntries = 0,
    this.totalMinutes = 0,
    this.moodHistory = const [],
    this.hasCheckedIn = false,
    this.lastSessionDate,
    this.lastSessionCompletedAt,
    this.lastSessionImproved = false,
  });

  /// Post-session glow intensity: 1.0 immediately after, decays to 0 over 30 minutes.
  double get postSessionGlow {
    if (lastSessionCompletedAt == null) return 0.0;
    final elapsed = DateTime.now().difference(lastSessionCompletedAt!).inSeconds;
    const decaySeconds = 30 * 60;
    if (elapsed >= decaySeconds) return 0.0;
    return (1.0 - elapsed / decaySeconds).clamp(0.0, 1.0);
  }

  AuraState copyWith({
    EmotionalState? currentState,
    Atmosphere? atmosphere,
    int? streak,
    int? totalSessions,
    int? totalCalmEntries,
    int? totalMinutes,
    List<MoodEntry>? moodHistory,
    bool? hasCheckedIn,
    DateTime? lastSessionDate,
    DateTime? lastSessionCompletedAt,
    bool? lastSessionImproved,
  }) {
    return AuraState(
      currentState: currentState ?? this.currentState,
      atmosphere: atmosphere ?? this.atmosphere,
      streak: streak ?? this.streak,
      totalSessions: totalSessions ?? this.totalSessions,
      totalCalmEntries: totalCalmEntries ?? this.totalCalmEntries,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      moodHistory: moodHistory ?? this.moodHistory,
      hasCheckedIn: hasCheckedIn ?? this.hasCheckedIn,
      lastSessionDate: lastSessionDate ?? this.lastSessionDate,
      lastSessionCompletedAt: lastSessionCompletedAt ?? this.lastSessionCompletedAt,
      lastSessionImproved: lastSessionImproved ?? this.lastSessionImproved,
    );
  }
}

class AuraEngine extends Notifier<AuraState> {
  @override
  AuraState build() {
    _loadLocal();
    return AuraState(
      currentState: EmotionalState.calm,
      atmosphere: Atmosphere.compute(),
    );
  }

  Future<void> _loadLocal() async {
    final storage = ref.read(localStorageProvider);
    final stats = await storage.loadStats();
    final historyRaw = await storage.loadMoodHistory();

    final history = historyRaw.map((h) {
      return MoodEntry(
        state: EmotionalState.values.firstWhere(
          (e) => e.name == (h['emotion'] as String? ?? 'calm'),
          orElse: () => EmotionalState.calm,
        ),
        timestamp: DateTime.tryParse(h['created_at'] as String? ?? '') ?? DateTime.now(),
      );
    }).toList();

    final sessions = stats['total_sessions'] as int? ?? 0;
    final streak = stats['streak'] as int? ?? 0;
    final calmEntries = stats['total_calm_entries'] as int? ?? 0;
    final minutes = stats['total_minutes'] as int? ?? 0;
    final lastDateStr = stats['last_session_date'] as String?;
    final lastDate = lastDateStr != null ? DateTime.tryParse(lastDateStr) : null;

    // Restore last emotional state instead of always defaulting to calm
    final lastEmotionStr = await storage.loadLastEmotion();
    final lastEmotion = lastEmotionStr != null
        ? EmotionalState.values.firstWhere(
            (e) => e.name == lastEmotionStr,
            orElse: () => EmotionalState.calm,
          )
        : EmotionalState.calm;

    // Try to restore cached companion atmosphere
    Atmosphere? restoredAtm;
    try {
      final companionCache = await storage.loadCompanionState();
      if (companionCache != null) {
        restoredAtm = Atmosphere.fromServer(companionCache, lastEmotion);
      }
    } catch (_) {}

    state = state.copyWith(
      currentState: lastEmotion,
      totalSessions: sessions,
      streak: streak,
      totalCalmEntries: calmEntries,
      totalMinutes: minutes,
      lastSessionDate: lastDate,
      moodHistory: history,
      atmosphere: restoredAtm ?? Atmosphere.compute(
        state: lastEmotion,
        totalCalmEntries: calmEntries,
        streak: streak,
      ),
    );
  }

  DateTime? _lastCheckInTime;

  void checkIn(EmotionalState emotionalState, {int intensity = 3}) {
    final entry = MoodEntry(state: emotionalState, timestamp: DateTime.now());
    final newHistory = [...state.moodHistory, entry];
    final calmEntries = state.totalCalmEntries +
        (emotionalState == EmotionalState.calm ? 1 : 0);

    final secondsSinceLast = _lastCheckInTime != null
        ? DateTime.now().difference(_lastCheckInTime!).inSeconds
        : null;
    _lastCheckInTime = DateTime.now();

    state = state.copyWith(
      currentState: emotionalState,
      hasCheckedIn: true,
      moodHistory: newHistory,
      totalCalmEntries: calmEntries,
      atmosphere: Atmosphere.compute(
        state: emotionalState,
        totalCalmEntries: calmEntries,
        streak: state.streak,
      ),
    );

    _persistAndSync(emotionalState, intensity: intensity, secondsSinceLast: secondsSinceLast);

    // Persist for continuity across launches
    ref.read(localStorageProvider).saveLastEmotion(emotionalState.name);
  }

  Future<void> _persistAndSync(
    EmotionalState emotionalState, {
    int intensity = 3,
    int? secondsSinceLast,
  }) async {
    final storage = ref.read(localStorageProvider);

    await storage.saveMoodHistory(
      state.moodHistory.map((e) => {
        'emotion': e.state.name,
        'created_at': e.timestamp.toIso8601String(),
      }).toList(),
    );
    await storage.saveStats(
      totalSessions: state.totalSessions,
      streak: state.streak,
      totalCalmEntries: state.totalCalmEntries,
      totalMinutes: state.totalMinutes,
    );

    try {
      final api = ref.read(apiClientProvider);
      if (await api.hasTokens) {
        await api.createMood(
          emotion: emotionalState.name,
          intensity: intensity,
          context: 'checkin',
        );

        final companion = await api.getCompanion(
          currentMood: emotionalState.name,
          hour: DateTime.now().hour,
          intensity: intensity,
          secondsSinceLastCheckin: secondsSinceLast,
        );

        state = state.copyWith(
          atmosphere: Atmosphere.fromServer(companion, emotionalState),
        );
        await storage.saveCompanionState(companion);
      }
    } catch (_) {
      // Offline — local atmosphere is fine
    }
  }

  void completeSession({String? moodAfter, String? sessionType, int? durationSeconds}) {
    final newSessions = state.totalSessions + 1;
    final newMinutes = state.totalMinutes + (durationSeconds ?? 0) ~/ 60;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    int newStreak = state.streak;

    if (state.lastSessionDate != null) {
      final lastDate = DateTime(
        state.lastSessionDate!.year,
        state.lastSessionDate!.month,
        state.lastSessionDate!.day,
      );
      final diff = todayDate.difference(lastDate).inDays;
      if (diff == 1) {
        newStreak += 1;
      } else if (diff > 1) {
        newStreak = 1;
      }
    } else {
      newStreak = 1;
    }

    final severityOrder = {'overload': 4, 'anxiety': 3, 'fatigue': 2, 'emptiness': 1, 'calm': 0};
    final improved = moodAfter != null &&
        (severityOrder[moodAfter] ?? 2) < (severityOrder[state.currentState.name] ?? 2);

    state = state.copyWith(
      totalSessions: newSessions,
      totalMinutes: newMinutes,
      streak: newStreak,
      lastSessionDate: todayDate,
      lastSessionCompletedAt: DateTime.now(),
      lastSessionImproved: improved,
      atmosphere: Atmosphere.compute(
        state: state.currentState,
        totalCalmEntries: state.totalCalmEntries,
        streak: newStreak,
      ),
    );

    _persistSession(
      sessionType: sessionType,
      durationSeconds: durationSeconds,
      moodBefore: state.currentState.name,
      moodAfter: moodAfter,
    );
  }

  Future<void> _persistSession({
    String? sessionType,
    int? durationSeconds,
    String? moodBefore,
    String? moodAfter,
  }) async {
    final storage = ref.read(localStorageProvider);
    await storage.saveStats(
      totalSessions: state.totalSessions,
      streak: state.streak,
      totalCalmEntries: state.totalCalmEntries,
      totalMinutes: state.totalMinutes,
      lastSessionDate: state.lastSessionDate?.toIso8601String(),
    );

    try {
      final api = ref.read(apiClientProvider);
      if (await api.hasTokens && sessionType != null && durationSeconds != null) {
        await api.createSession(
          sessionType: sessionType,
          durationSeconds: durationSeconds,
          completed: true,
          moodBefore: moodBefore,
          moodAfter: moodAfter,
        );
      }
    } catch (_) {}
  }

  void resetCheckIn() {
    state = state.copyWith(hasCheckedIn: false);
  }

  void realityBreakTriggered() {
    state = state.copyWith(
      currentState: EmotionalState.overload,
      atmosphere: Atmosphere.compute(
        state: EmotionalState.overload,
        totalCalmEntries: state.totalCalmEntries,
        streak: state.streak,
      ),
    );

    try {
      final api = ref.read(apiClientProvider);
      api.hasTokens.then((has) {
        if (has) {
          api.createMood(emotion: 'overload', context: 'reality_break');
        }
      });
    } catch (_) {}
  }
}

final auraProvider = NotifierProvider<AuraEngine, AuraState>(AuraEngine.new);
