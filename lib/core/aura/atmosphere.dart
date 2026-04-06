import 'dart:ui';
import 'package:flutter/material.dart';

// ── User-facing check-in moods ──────────────────────────────────────────────

enum EmotionalState { anxiety, fatigue, overload, emptiness, calm }

enum DayPhase { lateNight, earlyMorning, morning, afternoon, evening, night }

// ── AI-determined visual states (superset of user moods) ────────────────────

enum UniverseMood { calm, anxiety, fatigue, overload, emptiness, focus, joy, sleepy }

// ── Visual config per mood — directly from spec table ───────────────────────

class UniverseVisualConfig {
  final Color bgA;
  final Color bgB;
  final Alignment gradBegin;
  final Alignment gradEnd;
  final bool radialGradient;

  final int particleCount;
  final double particleMinPx;
  final double particleMaxPx;
  final double particleSpeed;
  final double particleAlpha;
  final bool chaotic;

  final double breathAmplitude;
  final double breathPeriodSec;

  final Color bloomColor;
  final double bloomIntensity;
  final double vignetteStrength;

  final Color accentColor;

  const UniverseVisualConfig({
    required this.bgA,
    required this.bgB,
    this.gradBegin = Alignment.bottomLeft,
    this.gradEnd = Alignment.topRight,
    this.radialGradient = false,
    this.particleCount = 40,
    this.particleMinPx = 2,
    this.particleMaxPx = 5,
    this.particleSpeed = 1.0,
    this.particleAlpha = 0.6,
    this.chaotic = false,
    this.breathAmplitude = 0.05,
    this.breathPeriodSec = 6,
    this.bloomColor = const Color(0x00000000),
    this.bloomIntensity = 0.1,
    this.vignetteStrength = 0.5,
    this.accentColor = Colors.white,
  });

  static UniverseVisualConfig lerp(
    UniverseVisualConfig a, UniverseVisualConfig b, double t,
  ) {
    return UniverseVisualConfig(
      bgA: Color.lerp(a.bgA, b.bgA, t)!,
      bgB: Color.lerp(a.bgB, b.bgB, t)!,
      gradBegin: Alignment.lerp(a.gradBegin, b.gradBegin, t)!,
      gradEnd: Alignment.lerp(a.gradEnd, b.gradEnd, t)!,
      radialGradient: t < 0.5 ? a.radialGradient : b.radialGradient,
      particleCount: lerpDouble(a.particleCount.toDouble(), b.particleCount.toDouble(), t)!.round(),
      particleMinPx: lerpDouble(a.particleMinPx, b.particleMinPx, t)!,
      particleMaxPx: lerpDouble(a.particleMaxPx, b.particleMaxPx, t)!,
      particleSpeed: lerpDouble(a.particleSpeed, b.particleSpeed, t)!,
      particleAlpha: lerpDouble(a.particleAlpha, b.particleAlpha, t)!,
      chaotic: t < 0.5 ? a.chaotic : b.chaotic,
      breathAmplitude: lerpDouble(a.breathAmplitude, b.breathAmplitude, t)!,
      breathPeriodSec: lerpDouble(a.breathPeriodSec, b.breathPeriodSec, t)!,
      bloomColor: Color.lerp(a.bloomColor, b.bloomColor, t)!,
      bloomIntensity: lerpDouble(a.bloomIntensity, b.bloomIntensity, t)!,
      vignetteStrength: lerpDouble(a.vignetteStrength, b.vignetteStrength, t)!,
      accentColor: Color.lerp(a.accentColor, b.accentColor, t)!,
    );
  }

  static UniverseVisualConfig of(UniverseMood mood) =>
      _configs[mood] ?? _configs[UniverseMood.calm]!;

  static const _configs = <UniverseMood, UniverseVisualConfig>{
    // ── Anxiety ──────────────────────────────────────────────────────
    // Dark blue + slate, scarlet accent, chaotic fast particles
    UniverseMood.anxiety: UniverseVisualConfig(
      bgA: Color(0xFF0D1B2A),
      bgB: Color(0xFF1F2833),
      gradBegin: Alignment.bottomLeft,
      gradEnd: Alignment.topRight,
      particleCount: 60,
      particleMinPx: 1.5,
      particleMaxPx: 4,
      particleSpeed: 1.3,
      particleAlpha: 0.6,
      chaotic: true,
      breathAmplitude: 0.03,
      breathPeriodSec: 3.0,
      bloomColor: Color(0xFFFF5E5B),
      bloomIntensity: 0.12,
      vignetteStrength: 0.7,
      accentColor: Color(0xFFFF5E5B),
    ),

    // ── Calm ─────────────────────────────────────────────────────────
    // Navy to sky blue, radial, smooth slow particles, soft glow
    UniverseMood.calm: UniverseVisualConfig(
      bgA: Color(0xFF1A374D),
      bgB: Color(0xFF406882),
      radialGradient: true,
      particleCount: 35,
      particleMinPx: 2.5,
      particleMaxPx: 5,
      particleSpeed: 0.7,
      particleAlpha: 0.8,
      breathAmplitude: 0.08,
      breathPeriodSec: 7.0,
      bloomColor: Color(0xFF406882),
      bloomIntensity: 0.08,
      vignetteStrength: 0.4,
      accentColor: Color(0xFF5CE1E6),
    ),

    // ── Fatigue ──────────────────────────────────────────────────────
    // Foggy purple, very slow large particles, dim
    UniverseMood.fatigue: UniverseVisualConfig(
      bgA: Color(0xFF4B4453),
      bgB: Color(0xFF3A2731),
      gradBegin: Alignment.centerLeft,
      gradEnd: Alignment.centerRight,
      particleCount: 25,
      particleMinPx: 4,
      particleMaxPx: 7,
      particleSpeed: 0.5,
      particleAlpha: 0.5,
      breathAmplitude: 0.04,
      breathPeriodSec: 10.0,
      bloomColor: Color(0xFF7B68EE),
      bloomIntensity: 0.06,
      vignetteStrength: 0.5,
      accentColor: Color(0xFF7B68EE),
    ),

    // ── Overload ─────────────────────────────────────────────────────
    // Intense purple, very fast tiny particles, bright flashes
    UniverseMood.overload: UniverseVisualConfig(
      bgA: Color(0xFF2F1B3D),
      bgB: Color(0xFF451A75),
      gradBegin: Alignment.bottomCenter,
      gradEnd: Alignment.topCenter,
      particleCount: 90,
      particleMinPx: 1,
      particleMaxPx: 3,
      particleSpeed: 1.6,
      particleAlpha: 0.55,
      chaotic: true,
      breathAmplitude: 0.05,
      breathPeriodSec: 3.5,
      bloomColor: Color(0xFF9B59B6),
      bloomIntensity: 0.2,
      vignetteStrength: 0.5,
      accentColor: Color(0xFF9B59B6),
    ),

    // ── Emptiness ────────────────────────────────────────────────────
    // Near black, barely any particles, near-total darkness
    UniverseMood.emptiness: UniverseVisualConfig(
      bgA: Color(0xFF0B0C10),
      bgB: Color(0xFF1F2833),
      radialGradient: true,
      particleCount: 7,
      particleMinPx: 1,
      particleMaxPx: 2,
      particleSpeed: 0.05,
      particleAlpha: 0.3,
      breathAmplitude: 0.01,
      breathPeriodSec: 12.0,
      bloomColor: Color(0xFF406882),
      bloomIntensity: 0.04,
      vignetteStrength: 0.2,
      accentColor: Color(0xFF406882),
    ),

    // ── Focus ────────────────────────────────────────────────────────
    // Dark azure + amber, clear light source, crisp
    UniverseMood.focus: UniverseVisualConfig(
      bgA: Color(0xFF14213D),
      bgB: Color(0xFFFCA311),
      gradBegin: Alignment.topLeft,
      gradEnd: Alignment.bottomRight,
      particleCount: 50,
      particleMinPx: 2.5,
      particleMaxPx: 5,
      particleSpeed: 1.0,
      particleAlpha: 0.7,
      breathAmplitude: 0.07,
      breathPeriodSec: 5.0,
      bloomColor: Color(0xFFFCA311),
      bloomIntensity: 0.15,
      vignetteStrength: 0.3,
      accentColor: Color(0xFFFCA311),
    ),

    // ── Joy ──────────────────────────────────────────────────────────
    // Gold to red, radial, rhythmic bouncy particles, bright
    UniverseMood.joy: UniverseVisualConfig(
      bgA: Color(0xFFFFCA3A),
      bgB: Color(0xFFFF595E),
      radialGradient: true,
      particleCount: 60,
      particleMinPx: 2,
      particleMaxPx: 6,
      particleSpeed: 1.1,
      particleAlpha: 0.75,
      breathAmplitude: 0.10,
      breathPeriodSec: 4.0,
      bloomColor: Color(0xFFFFCA3A),
      bloomIntensity: 0.18,
      vignetteStrength: 0.35,
      accentColor: Color(0xFFFFCA3A),
    ),

    // ── Sleepy ───────────────────────────────────────────────────────
    // Deep blue, fading particles, heavy vignette
    UniverseMood.sleepy: UniverseVisualConfig(
      bgA: Color(0xFF0A2342),
      bgB: Color(0xFF1A508B),
      gradBegin: Alignment.bottomCenter,
      gradEnd: Alignment.topCenter,
      particleCount: 20,
      particleMinPx: 5,
      particleMaxPx: 9,
      particleSpeed: 0.3,
      particleAlpha: 0.35,
      breathAmplitude: 0.02,
      breathPeriodSec: 9.0,
      bloomColor: Color(0xFF7B68EE),
      bloomIntensity: 0.06,
      vignetteStrength: 0.8,
      accentColor: Color(0xFF1A508B),
    ),
  };
}

// ── Action data ─────────────────────────────────────────────────────────────

class ImmediateAction {
  final String label;
  final String shortPrompt;
  final String sessionType;
  final int durationSeconds;
  final Color color;

  const ImmediateAction({
    required this.label,
    required this.shortPrompt,
    required this.sessionType,
    required this.durationSeconds,
    required this.color,
  });
}

class UniverseState {
  final double brightness;
  final double starDensity;
  final double nebulaIntensity;
  final double particleSpeed;
  final Color dominantColor;
  final Color accentColor;

  const UniverseState({
    required this.brightness,
    required this.starDensity,
    required this.nebulaIntensity,
    required this.particleSpeed,
    required this.dominantColor,
    required this.accentColor,
  });
}

// ── Atmosphere ──────────────────────────────────────────────────────────────

class Atmosphere {
  final EmotionalState state;
  final UniverseMood universeMood;
  final DayPhase dayPhase;
  final String auraPresence;
  final ImmediateAction action;
  final UniverseState universe;
  final double orbBreathSpeed;
  final String responseMode;
  final String? insight;

  const Atmosphere({
    required this.state,
    required this.universeMood,
    required this.dayPhase,
    required this.auraPresence,
    required this.action,
    required this.universe,
    required this.orbBreathSpeed,
    this.responseMode = 'minimal_verbal',
    this.insight,
  });

  UniverseVisualConfig get visualConfig => UniverseVisualConfig.of(universeMood);

  /// Local-only computation (offline fallback).
  static Atmosphere compute({
    EmotionalState state = EmotionalState.calm,
    int totalCalmEntries = 0,
    int streak = 0,
  }) {
    final dayPhase = _dayPhase();
    final uniMood = _defaultUniverseMood(state, dayPhase, streak);
    final presence = _auraPresence(state, dayPhase);
    final action = _immediateAction(state, dayPhase);
    final universe = _universe(state, totalCalmEntries, streak);

    return Atmosphere(
      state: state,
      universeMood: uniMood,
      dayPhase: dayPhase,
      auraPresence: presence,
      action: action,
      universe: universe,
      orbBreathSpeed: _breathSpeed(state),
      responseMode: state == EmotionalState.calm ? 'silent' : 'minimal_verbal',
    );
  }

  /// Build from server companion response (GPT-personalized).
  static Atmosphere fromServer(
    Map<String, dynamic> data,
    EmotionalState currentState,
  ) {
    final uniMoodStr = data['universe_mood'] as String? ?? currentState.name;
    final uniMood = UniverseMood.values.firstWhere(
      (m) => m.name == uniMoodStr,
      orElse: () => UniverseMood.calm,
    );

    final actionData = data['action'] as Map<String, dynamic>?;
    final uData = data['universe'] as Map<String, dynamic>;

    return Atmosphere(
      state: currentState,
      universeMood: uniMood,
      dayPhase: _dayPhase(),
      auraPresence: data['presence'] as String? ?? '',
      responseMode: data['response_mode'] as String? ?? 'minimal_verbal',
      insight: data['insight'] as String?,
      action: actionData != null
          ? ImmediateAction(
              label: actionData['label'] as String? ?? '',
              shortPrompt: actionData['short_prompt'] as String? ?? '',
              sessionType: actionData['session_type'] as String? ?? 'deepen',
              durationSeconds: actionData['duration_seconds'] as int? ?? 60,
              color: _hex(actionData['color_hex'] as String? ?? '#8B7FFF'),
            )
          : _immediateAction(currentState, _dayPhase()),
      universe: UniverseState(
        brightness: (uData['brightness'] as num).toDouble(),
        starDensity: (uData['star_density'] as num).toDouble(),
        nebulaIntensity: (uData['nebula_intensity'] as num).toDouble(),
        particleSpeed: (uData['particle_speed'] as num).toDouble(),
        dominantColor: _hex(uData['dominant_color_hex'] as String),
        accentColor: _hex(uData['accent_color_hex'] as String),
      ),
      orbBreathSpeed: (data['orb_breath_speed'] as num).toDouble(),
    );
  }

  static Color _hex(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  static DayPhase _dayPhase() {
    final h = DateTime.now().hour;
    if (h < 5) return DayPhase.lateNight;
    if (h < 7) return DayPhase.earlyMorning;
    if (h < 12) return DayPhase.morning;
    if (h < 17) return DayPhase.afternoon;
    if (h < 22) return DayPhase.evening;
    return DayPhase.night;
  }

  static UniverseMood _defaultUniverseMood(
    EmotionalState state, DayPhase phase, int streak,
  ) {
    if (phase == DayPhase.lateNight || phase == DayPhase.night) {
      return UniverseMood.sleepy;
    }
    if (state == EmotionalState.calm && streak >= 10) {
      return UniverseMood.joy;
    }
    return UniverseMood.values.firstWhere(
      (m) => m.name == state.name,
      orElse: () => UniverseMood.calm,
    );
  }

  static String _auraPresence(EmotionalState state, DayPhase phase) {
    if (phase == DayPhase.lateNight) return '';
    return switch (state) {
      EmotionalState.anxiety => 'Давай замедлимся.',
      EmotionalState.fatigue => 'Тебе нужна пауза.',
      EmotionalState.overload => 'Просто дыши.',
      EmotionalState.emptiness => 'Я здесь.',
      EmotionalState.calm => '',
    };
  }

  static ImmediateAction _immediateAction(EmotionalState state, DayPhase phase) {
    if (phase == DayPhase.lateNight || phase == DayPhase.night) {
      return const ImmediateAction(
        label: 'Уснуть', shortPrompt: 'Дыши и отпусти день',
        sessionType: 'sleep_reset', durationSeconds: 90, color: Color(0xFF1A508B),
      );
    }
    return switch (state) {
      EmotionalState.anxiety => const ImmediateAction(
          label: 'Сбросить за 1 мин', shortPrompt: 'Дыхание замедлит всё',
          sessionType: 'anxiety_relief', durationSeconds: 60, color: Color(0xFFFF5E5B)),
      EmotionalState.fatigue => const ImmediateAction(
          label: 'Перезагрузка', shortPrompt: 'Мягкий ресет для тела',
          sessionType: 'energy_reset', durationSeconds: 90, color: Color(0xFF7B68EE)),
      EmotionalState.overload => const ImmediateAction(
          label: 'Стоп. Тишина.', shortPrompt: 'Просто дыши',
          sessionType: 'overload_relief', durationSeconds: 60, color: Color(0xFF9B59B6)),
      EmotionalState.emptiness => const ImmediateAction(
          label: 'Почувствовать', shortPrompt: 'Мягкое возвращение к себе',
          sessionType: 'grounding', durationSeconds: 90, color: Color(0xFF406882)),
      EmotionalState.calm => const ImmediateAction(
          label: 'Углубиться', shortPrompt: 'Хороший момент',
          sessionType: 'deepen', durationSeconds: 90, color: Color(0xFF406882)),
    };
  }

  static UniverseState _universe(
    EmotionalState state, int totalCalmEntries, int streak,
  ) {
    final evo = (totalCalmEntries * 0.02 + streak * 0.05).clamp(0.0, 1.0);
    final cfg = UniverseVisualConfig.of(
      UniverseMood.values.firstWhere(
        (m) => m.name == state.name,
        orElse: () => UniverseMood.calm,
      ),
    );
    return UniverseState(
      brightness: cfg.bloomIntensity + evo * 0.3,
      starDensity: cfg.particleCount / 50.0 + evo * 0.4,
      nebulaIntensity: 0.5 + evo * 0.2,
      particleSpeed: cfg.particleSpeed,
      dominantColor: cfg.bgB,
      accentColor: cfg.accentColor,
    );
  }

  static double _breathSpeed(EmotionalState state) => switch (state) {
        EmotionalState.anxiety => 0.5,
        EmotionalState.overload => 0.4,
        EmotionalState.fatigue => 0.7,
        EmotionalState.emptiness => 0.8,
        EmotionalState.calm => 1.0,
      };
}
