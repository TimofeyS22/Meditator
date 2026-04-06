import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meditator/core/aura/atmosphere.dart';
import 'package:meditator/core/aura/aura_engine.dart';
import 'package:meditator/core/storage/local_storage.dart';

// ─── Evolution stages with emotional meaning ─────────────────────────────────

class EvolutionStage {
  final String key;
  final String label;
  final int minLevel;

  const EvolutionStage({
    required this.key, required this.label, required this.minLevel,
  });
}

const evolutionStages = [
  EvolutionStage(key: 'birth',       label: 'Рождение',      minLevel: 0),
  EvolutionStage(key: 'first_step',  label: 'Первый шаг',    minLevel: 1),
  EvolutionStage(key: 'returning',   label: 'Возвращение',   minLevel: 3),
  EvolutionStage(key: 'awakening',   label: 'Пробуждение',   minLevel: 5),
  EvolutionStage(key: 'trust',       label: 'Доверие',       minLevel: 8),
  EvolutionStage(key: 'stability',   label: 'Стабильность',  minLevel: 12),
  EvolutionStage(key: 'resilience',  label: 'Устойчивость',  minLevel: 16),
  EvolutionStage(key: 'openness',    label: 'Открытость',    minLevel: 20),
  EvolutionStage(key: 'grounding',   label: 'Укоренение',    minLevel: 25),
  EvolutionStage(key: 'depth',       label: 'Глубина',       minLevel: 30),
  EvolutionStage(key: 'expansion',   label: 'Простор',       minLevel: 35),
  EvolutionStage(key: 'warmth',      label: 'Тепло',         minLevel: 40),
  EvolutionStage(key: 'wisdom',      label: 'Мудрость',      minLevel: 45),
  EvolutionStage(key: 'radiance',    label: 'Сияние',        minLevel: 48),
  EvolutionStage(key: 'presence',    label: 'Присутствие',   minLevel: 50),
];

EvolutionStage currentStage(int level) {
  var result = evolutionStages.first;
  for (final stage in evolutionStages) {
    if (level >= stage.minLevel) result = stage;
  }
  return result;
}

// ─── Cosmos state ────────────────────────────────────────────────────────────

class CosmosState {
  final UniverseMood mood;
  final double intensity;
  final bool silentMode;
  final int evolutionLevel;
  final int personalSeed;
  final bool hasCheckedIn;
  final int daysSinceLastUse;
  final double postSessionGlow;
  final bool lastSessionImproved;

  const CosmosState({
    this.mood = UniverseMood.calm,
    this.intensity = 1.0,
    this.silentMode = false,
    this.evolutionLevel = 0,
    this.personalSeed = 42,
    this.hasCheckedIn = false,
    this.daysSinceLastUse = 0,
    this.postSessionGlow = 0.0,
    this.lastSessionImproved = false,
  });

  EvolutionStage get stage => currentStage(evolutionLevel);

  int get starCount => (50 + evolutionLevel * 2).clamp(50, 90);

  double get nebulaBoost => (evolutionLevel * 0.005).clamp(0.0, 0.15);

  double get bloomBoost {
    final base = (evolutionLevel * 0.003).clamp(0.0, 0.1);
    final absenceDecay = daysSinceLastUse > 7
        ? (daysSinceLastUse - 7) * 0.01
        : 0.0;
    final sessionWarmth = postSessionGlow * 0.06;
    return (base - absenceDecay + sessionWarmth).clamp(0.0, 0.16);
  }

  /// Particle speed reduction during post-session glow (10% slower at peak).
  double get particleSpeedMod => 1.0 - postSessionGlow * 0.1;

  /// As glow fades, micro-chaos creeps in — coherence decreasing subconsciously.
  /// At glow 1.0: no chaos added. At glow 0.3: slight drift. At 0.0: normal.
  bool get glowChaosOverride {
    if (postSessionGlow <= 0 || postSessionGlow >= 0.7) return false;
    return postSessionGlow < 0.3;
  }

  /// Vignette softens during high glow — space feels more open after practice.
  double get vignetteReduction => postSessionGlow * 0.08;

  /// Bloom dims subtly after 7+ days of inactivity (capped at 15% reduction).
  double get absenceBloomReduction =>
      daysSinceLastUse > 7 ? ((daysSinceLastUse - 7) * 0.02).clamp(0.0, 0.15) : 0.0;

  // ─── Subconscious linking ──────────────────────────────────────────────

  /// Memory echo: at glow ~0.5 (15 min mark), bloom briefly over-saturates
  /// by 2% then returns. Creates a subliminal "remember the calm" moment.
  /// Returns true in a narrow 60-second window around the 15-minute mark.
  bool get isMemoryEchoActive {
    if (postSessionGlow <= 0) return false;
    return postSessionGlow > 0.48 && postSessionGlow < 0.52;
  }

  /// Extra bloom during memory echo — a brief warmth that mirrors the
  /// post-session state, then fades. Not enough to notice consciously,
  /// but enough for the body to register "I felt this before."
  double get memoryEchoBloom => isMemoryEchoActive ? 0.02 : 0.0;

  /// Contrast sharpness: when glow crosses below 0.2 (about 24 min),
  /// particles become slightly MORE visible (alpha +5%) to make the
  /// "normal" state feel noticeably different from the calm state.
  /// The user feels the absence of calm, which links to the session.
  double get contrastAlphaBoost => postSessionGlow > 0 && postSessionGlow < 0.2 ? 0.05 : 0.0;
}

int _computeEvolution(int totalSessions, int streak) {
  final base = totalSessions;
  final streakBonus = (streak * 0.5).round();
  return (base + streakBonus).clamp(0, 50);
}

int _daysSinceLastSession(DateTime? lastSessionDate) {
  if (lastSessionDate == null) return 0;
  return DateTime.now().difference(lastSessionDate).inDays;
}

final _personalSeedProvider = FutureProvider<int>((ref) async {
  final storage = ref.read(localStorageProvider);
  return storage.getPersonalSeed();
});

final cosmosStateProvider = Provider<CosmosState>((ref) {
  final aura = ref.watch(auraProvider);
  final seedAsync = ref.watch(_personalSeedProvider);
  final seed = seedAsync.valueOrNull ?? 42;

  final atm = aura.atmosphere;
  final mode = atm.responseMode;

  return CosmosState(
    mood: atm.universeMood,
    intensity: 1.0,
    silentMode: mode == 'silent' && aura.hasCheckedIn,
    evolutionLevel: _computeEvolution(aura.totalSessions, aura.streak),
    personalSeed: seed,
    hasCheckedIn: aura.hasCheckedIn,
    daysSinceLastUse: _daysSinceLastSession(aura.lastSessionDate),
    postSessionGlow: aura.postSessionGlow,
    lastSessionImproved: aura.lastSessionImproved,
  );
});
