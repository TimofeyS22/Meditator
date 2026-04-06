import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/core/aura/aura_engine.dart';
import 'package:meditator/core/aura/atmosphere.dart';
import 'package:meditator/core/audio/audio_service.dart';
import 'package:meditator/core/cosmos/cosmos_state.dart';
import 'package:meditator/shared/theme/cosmic.dart';
import 'package:meditator/shared/widgets/cosmic_background.dart';
import 'package:meditator/shared/widgets/particle_field.dart';
import 'package:meditator/shared/widgets/cosmic_button.dart';

class SessionScreen extends ConsumerStatefulWidget {
  final String type;
  final int durationSeconds;

  const SessionScreen({
    super.key,
    required this.type,
    required this.durationSeconds,
  });

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final AnimationController _breathCtrl;
  late final AnimationController _progressCtrl;

  // Afterglow phase controllers
  late final AnimationController _agBreathEchoCtrl;
  late final AnimationController _agMicroPeakCtrl;
  late final AnimationController _agTextCtrl;
  late final AnimationController _agMoodDelayCtrl;
  late final AnimationController _agContrastCtrl;
  late final AnimationController _agEffortCtrl;
  late final AnimationController _agActionCtrl;
  late final AnimationController _agClosureCtrl;

  Timer? _timer;
  late int _remaining;
  int _afterglowPhase = 0; // 0=session, 1=somatic pause, 2+=phases
  bool get _showingAfterglow => _afterglowPhase > 0;
  String? _moodAfter;
  bool _moodImproved = false;

  // Phase-based breathing
  String _breathPhase = 'Вдох';
  int _cycleCount = 0;
  int _guidanceIndex = 0;
  bool _preTension = false;

  String get _moodBefore => ref.read(auraProvider).currentState.name;

  @override
  void initState() {
    super.initState();
    _remaining = widget.durationSeconds;

    _enterCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500),
    )..forward();

    _breathCtrl = AnimationController(vsync: this, duration: _currentPhaseDuration)
      ..addStatusListener(_onBreathPhaseComplete);

    _progressCtrl = AnimationController(
      vsync: this, duration: Duration(seconds: widget.durationSeconds),
    )..forward();

    _agBreathEchoCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 5000),
    );
    _agMicroPeakCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 120),
    );
    _agTextCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
    _agMoodDelayCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
    _agContrastCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    );
    _agEffortCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    );
    _agActionCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _agClosureCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300),
    );

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _startAudio();
      _startTimer();
      _breathCtrl.forward();
    });
  }

  Future<void> _startAudio() async {
    try {
      final audio = ref.read(audioServiceProvider);
      await audio.playSession(widget.type);
    } catch (_) {}
  }

  // Evidence-based breath patterns per session type
  _BreathPattern get _pattern => switch (widget.type) {
        'anxiety_relief' => _BreathPattern.fourSevenEight,
        'overload_relief' => _BreathPattern.progressive,
        'energy_reset' => _BreathPattern.boxBreathing,
        'sleep_reset' => _BreathPattern.extendedExhale,
        'grounding' => _BreathPattern.boxBreathing,
        _ => _BreathPattern.balanced,
      };

  Duration get _currentPhaseDuration {
    final p = _pattern;
    return switch (_breathPhase) {
      'Вдох' => Duration(milliseconds: (p.inhaleMs * _progressiveScale).round()),
      'Задержка' => Duration(milliseconds: (p.holdMs * _progressiveScale).round()),
      'Выдох' => Duration(milliseconds: (p.exhaleMs * _progressiveScale).round()),
      _ => Duration(milliseconds: p.inhaleMs),
    };
  }

  // For progressive pattern (overload): starts fast, slows down
  double get _progressiveScale {
    if (_pattern != _BreathPattern.progressive) return 1.0;
    final progress = 1.0 - (_remaining / widget.durationSeconds);
    return 0.5 + 0.5 * progress; // 50% speed at start → 100% at end
  }

  void _onBreathPhaseComplete(AnimationStatus status) {
    if (!mounted || _showingAfterglow) return;

    // Inhale completes at value=1.0 (forward complete)
    // Hold keeps value at 1.0 (forward complete, no animation)
    // Exhale completes at value=0.0 (reverse complete)
    final isForwardDone = status == AnimationStatus.completed;
    final isReverseDone = status == AnimationStatus.dismissed;

    if (!isForwardDone && !isReverseDone) return;

    final p = _pattern;
    setState(() {
      if (_breathPhase == 'Вдох' && isForwardDone) {
        if (p.holdMs > 0) {
          _breathPhase = 'Задержка';
        } else {
          _breathPhase = 'Выдох';
        }
      } else if (_breathPhase == 'Задержка' && isForwardDone) {
        _breathPhase = 'Выдох';
      } else if (_breathPhase == 'Выдох' && isReverseDone) {
        _breathPhase = 'Вдох';
        _cycleCount++;
        if (_cycleCount % 3 == 0) {
          _guidanceIndex = (_guidanceIndex + 1) % _guidanceCues.length;
        }
      } else {
        return;
      }
    });

    _breathCtrl.duration = _currentPhaseDuration;

    if (_breathPhase == 'Вдох') {
      _breathCtrl.forward(from: 0);
    } else if (_breathPhase == 'Задержка') {
      // Stay expanded — trigger completion after hold duration
      Future.delayed(_currentPhaseDuration, () {
        if (mounted && !_showingAfterglow && _breathPhase == 'Задержка') {
          _onBreathPhaseComplete(AnimationStatus.completed);
        }
      });
    } else if (_breathPhase == 'Выдох') {
      _breathCtrl.reverse(from: 1.0);
    }
  }

  // Guidance cues that rotate every 3 breath cycles
  List<String> get _guidanceCues => switch (widget.type) {
        'anxiety_relief' => const [
          'Каждый выдох уносит напряжение',
          'Расслабь плечи',
          'Отпусти напряжение в челюсти',
          'Ты в безопасности',
        ],
        'energy_reset' => const [
          'Мягко возвращай внимание к телу',
          'Почувствуй стопы на полу',
          'Расслабь лицо',
          'Энергия возвращается',
        ],
        'overload_relief' => const [
          'Просто дыши',
          'Ничего не нужно решать',
          'Замедляемся',
          'Тишина внутри',
        ],
        'grounding' => const [
          'Почувствуй пространство вокруг',
          'Ты здесь. Сейчас.',
          'Заметь тело',
          'Вернись к дыханию',
        ],
        'sleep_reset' => const [
          'Отпусти день',
          'Тело тяжелеет',
          'Мысли замедляются',
          'Всё может подождать',
        ],
        _ => const ['Побудь здесь', 'Дыши', 'Замечай'],
      };

  String get _currentGuidance => _guidanceCues[_guidanceIndex % _guidanceCues.length];

  Color get _sessionColor => switch (widget.type) {
        'anxiety_relief' => Cosmic.accent,
        'energy_reset' => Cosmic.warm,
        'overload_relief' => Cosmic.green,
        'grounding' => Cosmic.primary,
        'sleep_reset' => const Color(0xFF7B68EE),
        'deepen' => Cosmic.primary,
        _ => Cosmic.primary,
      };

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= 1) {
        _timer?.cancel();
        _complete();
        return;
      }
      setState(() => _remaining--);
    });
  }

  Future<void> _complete() async {
    final audio = ref.read(audioServiceProvider);
    await audio.fadeOut();
    HapticFeedback.mediumImpact();

    // Phase 1: Somatic pause (0-2s) — absolutely nothing. Body feels the shift.
    setState(() => _afterglowPhase = 1);
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    // Phase 2: Breath echo (2-5s) — one deep amplified breath
    setState(() => _afterglowPhase = 2);
    _agBreathEchoCtrl.forward();

    // Pre-tension at 3.6s: subtle glow reduction creates compress feeling
    await Future.delayed(const Duration(milliseconds: 3600));
    if (!mounted) return;
    setState(() => _preTension = true);

    // Micro-peak at 3.8s: release after the compress
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _preTension = false);
    HapticFeedback.selectionClick();
    _agMicroPeakCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    // Phase 3: Minimal realization (5-8s)
    setState(() => _afterglowPhase = 3);
    _agTextCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    // Phase 4: Mood capture (user-driven)
    setState(() => _afterglowPhase = 4);
  }

  static const _severityOrder = {
    'overload': 4, 'anxiety': 3, 'fatigue': 2, 'emptiness': 1, 'calm': 0,
  };

  void _selectPostMood(EmotionalState mood) {
    HapticFeedback.lightImpact();
    final beforeSeverity = _severityOrder[_moodBefore] ?? 2;
    final afterSeverity = _severityOrder[mood.name] ?? 2;
    final improved = afterSeverity < beforeSeverity;

    // Don't react instantly — let the cosmos sense the selection
    setState(() => _moodAfter = mood.name);
    _agMoodDelayCtrl.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _moodImproved = improved);
      ref.read(auraProvider.notifier).completeSession(
        sessionType: widget.type,
        durationSeconds: widget.durationSeconds,
        moodAfter: mood.name,
      );
      _runPostMoodSequence();
    });
  }

  Future<void> _runPostMoodSequence() async {
    // Phase 5: Visual contrast transition
    setState(() => _afterglowPhase = 5);
    _agContrastCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // Phase 6: Effort anchor
    setState(() => _afterglowPhase = 6);
    _agEffortCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    // Phase 7: Action button emerges
    setState(() => _afterglowPhase = 7);
    _agActionCtrl.forward();
  }

  void _skipPostMood() {
    ref.read(auraProvider.notifier).completeSession(
      sessionType: widget.type,
      durationSeconds: widget.durationSeconds,
    );
    context.pop();
  }

  Future<void> _close() async {
    final audio = ref.read(audioServiceProvider);
    if (audio.isPlaying) await audio.stop();
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _enterCtrl.dispose();
    _breathCtrl.dispose();
    _progressCtrl.dispose();
    _agBreathEchoCtrl.dispose();
    _agMicroPeakCtrl.dispose();
    _agTextCtrl.dispose();
    _agMoodDelayCtrl.dispose();
    _agContrastCtrl.dispose();
    _agEffortCtrl.dispose();
    _agActionCtrl.dispose();
    _agClosureCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showingAfterglow) return _buildAfterglow(context);
    return _buildSession(context);
  }

  Widget _buildSession(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cosmos = ref.watch(cosmosStateProvider);

    return Scaffold(
      backgroundColor: Cosmic.bg,
      body: CosmicBackground(
        mood: cosmos.mood,
        intensity: 1.3,
        seed: cosmos.personalSeed,
        extraStars: cosmos.starCount - 50,
        bloomBoost: cosmos.bloomBoost,
        child: Stack(
          children: [
            Positioned.fill(
              child: ParticleField(
                count: 55,
                maxRadius: 1.2,
                color: _sessionColor.withValues(alpha: 0.4),
              ),
            ),
            SafeArea(
              child: AnimatedBuilder(
                animation: Listenable.merge([_enterCtrl, _breathCtrl]),
                builder: (_, __) {
                  final enter =
                      CurvedAnimation(parent: _enterCtrl, curve: Anim.curve)
                          .value;
                  final breath =
                      Curves.easeInOut.transform(_breathCtrl.value);

                  return Opacity(
                    opacity: enter,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(Space.sm),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Opacity(
                              opacity: 0.4,
                              child: IconButton(
                                onPressed: _close,
                                icon: const Icon(Icons.close_rounded,
                                    color: Cosmic.textDim, size: 22),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(flex: 3),
                        _BreathCircle(
                          breath: breath,
                          color: _sessionColor,
                          label: _breathPhase,
                        ),
                        const Spacer(flex: 1),
                        Opacity(
                          opacity: (enter - 0.5).clamp(0, 1) * 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: Space.xxl),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                              child: Text(
                                _currentGuidance,
                                key: ValueKey(_guidanceIndex),
                                style: t.bodyLarge?.copyWith(
                                  color: Cosmic.textMuted,
                                  fontWeight: FontWeight.w300,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(flex: 3),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Space.xxxl),
                          child: AnimatedBuilder(
                            animation: _progressCtrl,
                            builder: (_, __) => ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: _progressCtrl.value,
                                minHeight: 4,
                                backgroundColor:
                                    Cosmic.surfaceLight.withValues(alpha: 0.2),
                                color: _sessionColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: Space.xxl),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAfterglow(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cosmos = ref.watch(cosmosStateProvider);

    final improved = _moodImproved && _moodAfter != null;
    final cosmosBloom = improved ? cosmos.bloomBoost + 0.08 : cosmos.bloomBoost;
    final cosmosMood = improved ? UniverseMood.calm : cosmos.mood;
    final accentColor = improved ? Cosmic.green : Cosmic.warm;
    final beforeColor = _moodColor(_moodBefore);

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _agClosureCtrl,
        builder: (_, child) {
          final closureT = _agClosureCtrl.value;
          final closureCurve = Curves.easeInOut.transform(
              closureT < 0.5 ? closureT * 2 : 2.0 - closureT * 2);
          final closureScale = closureT > 0 ? 1.0 - 0.03 * closureCurve : 1.0;
          final closureDim = closureT > 0 ? 0.08 * closureCurve : 0.0;

          return Transform.scale(
            scale: closureScale,
            child: Stack(
              children: [
                child!,
                if (closureDim > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: closureDim),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        child: CosmicBackground(
          mood: cosmosMood,
          intensity: improved ? 1.0 : 0.7,
          seed: cosmos.personalSeed,
          extraStars: cosmos.starCount - 50,
          bloomBoost: cosmosBloom,
          silentMode: _afterglowPhase < 4,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _agBreathEchoCtrl, _agMicroPeakCtrl, _agTextCtrl,
                _agMoodDelayCtrl, _agContrastCtrl, _agEffortCtrl, _agActionCtrl,
              ]),
              builder: (_, __) {
                // Breath echo: slow sine wave
                final echoT = _agBreathEchoCtrl.value;
                final echoSine = Curves.easeInOut.transform(
                  echoT < 0.5 ? echoT * 2 : 2 - echoT * 2,
                );

                // Micro-peak: brief spike at 3.8s
                final peakT = _agMicroPeakCtrl.value;
                final peakSpike = peakT > 0
                    ? 0.04 * Curves.easeOut.transform(
                        peakT < 0.4 ? peakT / 0.4 : 1.0 - (peakT - 0.4) / 0.6)
                    : 0.0;

                // Pre-tension: glow dips before spike (compress → release)
                final tensionDim = _preTension ? -0.06 : 0.0;
                final echoScale = 1.0 + 0.08 * echoSine + peakSpike;
                final echoGlow = 0.2 + 0.2 * echoSine + peakSpike * 2 + tensionDim;

                final textT = Curves.easeOutCubic.transform(_agTextCtrl.value);
                final delayT = _agMoodDelayCtrl.value;
                final contrastT = Curves.easeOutCubic.transform(_agContrastCtrl.value);
                final effortT = Curves.easeOutCubic.transform(_agEffortCtrl.value);
                final actionT = Curves.easeOutCubic.transform(_agActionCtrl.value);

                final particleSpeed = peakT > 0 ? 0.05 : (_preTension ? 0.25 : 0.35);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: ParticleField(
                        count: improved ? 65 : 40,
                        maxRadius: 2.0,
                        speed: particleSpeed,
                        color: accentColor.withValues(alpha: 0.2),
                      ),
                    ),

                    // Ghost layer: previous mood dissolves as particles disperse
                    if (_afterglowPhase >= 5 && improved) ...[
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                radius: 0.6 + 0.4 * contrastT,
                                colors: [
                                  beforeColor.withValues(alpha: 0.07 * (1 - contrastT)),
                                  beforeColor.withValues(alpha: 0.02 * (1 - contrastT)),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Ghost particles: old color dispersing outward
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: (1 - contrastT).clamp(0, 1),
                            child: ParticleField(
                              count: (12 * (1 - contrastT)).round().clamp(0, 12),
                              maxRadius: 1.5 + 2.0 * contrastT,
                              speed: 0.8 + contrastT * 1.5,
                              alpha: 0.3 * (1 - contrastT),
                              color: beforeColor,
                            ),
                          ),
                        ),
                      ),
                    ],

                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                        child: Column(
                          children: [
                            const Spacer(flex: 3),

                            // Orb — present from phase 1, breathing with echo
                            if (_afterglowPhase >= 1)
                              Transform.scale(
                                scale: echoScale,
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withValues(alpha: echoGlow),
                                        blurRadius: 50 + 10 * echoSine,
                                        spreadRadius: 6,
                                      ),
                                      BoxShadow(
                                        color: Colors.white.withValues(alpha: echoGlow * 0.25),
                                        blurRadius: 80,
                                      ),
                                    ],
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.3 + 0.1 * echoSine),
                                        accentColor.withValues(alpha: 0.12),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            const SizedBox(height: Space.xl),

                            // Phase 3+: realization text
                            if (_afterglowPhase >= 3)
                              Opacity(
                                opacity: _moodAfter != null && delayT < 1 ? delayT : textT,
                                child: Text(
                                  _moodAfter != null ? _realizationText() : _questionText(),
                                  style: t.titleLarge?.copyWith(
                                    color: _moodAfter != null
                                        ? accentColor.withValues(alpha: 0.85)
                                        : Cosmic.textMuted,
                                    fontWeight: FontWeight.w300,
                                    fontSize: 22,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            // Phase 4: mood chips
                            if (_afterglowPhase == 4 && _moodAfter == null) ...[
                              const SizedBox(height: Space.lg),
                              _PostSessionMoodSelector(onSelect: _selectPostMood),
                              const SizedBox(height: Space.lg),
                              GestureDetector(
                                onTap: _skipPostMood,
                                child: Text('Пропустить',
                                  style: t.bodySmall?.copyWith(
                                    color: Cosmic.textDim,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Cosmic.textDim.withValues(alpha: 0.25),
                                  ),
                                ),
                              ),
                            ],

                            // Phase 5: contrast (subtle lowercase journey)
                            if (_afterglowPhase >= 5 && improved)
                              Opacity(
                                opacity: contrastT * 0.5,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: Space.md),
                                  child: Text(
                                    '${_moodRu(_moodBefore)} → ${_moodRu(_moodAfter!)}',
                                    style: t.bodySmall?.copyWith(
                                      color: Cosmic.textDim,
                                      letterSpacing: 1.5,
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),

                            // Phase 6: breath count + orb ripple
                            if (_afterglowPhase >= 6 && _cycleCount > 0) ...[
                              // Glow ripple from orb synced with effort reveal
                              if (effortT > 0 && effortT < 0.8)
                                IgnorePointer(
                                  child: Container(
                                    width: 56 + 80 * effortT,
                                    height: 56 + 80 * effortT,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: accentColor.withValues(alpha: 0.08 * (1 - effortT)),
                                      ),
                                    ),
                                  ),
                                ),
                              Opacity(
                                opacity: effortT,
                                child: Transform.scale(
                                  scale: 0.95 + 0.05 * effortT,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: Space.md),
                                    child: Text(
                                      '$_cycleCount ${_cycleCount == 1 ? "дыхание" : "дыханий"}',
                                      style: t.bodySmall?.copyWith(color: Cosmic.textDim),
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            const Spacer(flex: 4),

                            // Phase 7: return button
                            if (_afterglowPhase >= 7)
                              Opacity(
                                opacity: actionT,
                                child: Transform.translate(
                                  offset: Offset(0, 8 * (1 - actionT)),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: Space.xxl),
                                    child: CosmicButton(
                                      onPressed: _onReturn,
                                      width: double.infinity,
                                      gradient: improved
                                          ? const LinearGradient(colors: [Cosmic.green, Cosmic.accent])
                                          : Cosmic.gradientWarm,
                                      child: const Text('Вернуться'),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Phase 8: Closure compression on return tap
  void _onReturn() {
    HapticFeedback.lightImpact();
    _agClosureCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) context.pop();
    });
  }

  static const _questionVariants = [
    'Как ты сейчас?',
    'Что изменилось?',
    'Как внутри?',
  ];

  String _questionText() {
    return _questionVariants[_cycleCount % _questionVariants.length];
  }

  String _realizationText() {
    if (_moodImproved) {
      return switch (_moodAfter) {
        'calm' => 'Стало спокойнее',
        'fatigue' => 'Немного легче',
        'emptiness' => 'Что-то сдвинулось',
        _ => 'Легче',
      };
    }
    return switch (_moodAfter) {
      'calm' => 'Спокойно',
      'anxiety' => 'Тревога ещё здесь',
      'fatigue' => 'Усталость',
      'overload' => 'Тяжело',
      'emptiness' => 'Пусто',
      _ => '',
    };
  }

  static String _moodRu(String mood) => switch (mood) {
        'anxiety' => 'тревога',
        'fatigue' => 'усталость',
        'overload' => 'перегрузка',
        'emptiness' => 'пустота',
        'calm' => 'спокойствие',
        _ => mood,
      };

  Color _moodColor(String mood) => switch (mood) {
        'anxiety' => Cosmic.accent,
        'fatigue' => Cosmic.warm,
        'overload' => Cosmic.rose,
        'emptiness' => Cosmic.primary,
        'calm' => Cosmic.green,
        _ => Cosmic.primary,
      };
}

class _PostSessionMoodSelector extends StatelessWidget {
  final ValueChanged<EmotionalState> onSelect;
  const _PostSessionMoodSelector({required this.onSelect});

  static const _moods = [
    (EmotionalState.calm, 'Спокойно', Icons.spa_rounded, Cosmic.green),
    (EmotionalState.anxiety, 'Тревога', Icons.air_rounded, Cosmic.accent),
    (EmotionalState.fatigue, 'Усталость', Icons.bedtime_rounded, Cosmic.warm),
    (EmotionalState.overload, 'Перегрузка', Icons.flash_on_rounded, Cosmic.rose),
    (EmotionalState.emptiness, 'Пустота', Icons.blur_on_rounded, Cosmic.primary),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      alignment: WrapAlignment.center,
      children: _moods.map((item) {
        final (state, label, icon, color) = item;
        return GestureDetector(
          onTap: () => onSelect(state),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.full),
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 13, color: color)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// Evidence-based breathing patterns
enum _BreathPattern {
  fourSevenEight,  // 4s inhale, 7s hold, 8s exhale (anxiety)
  boxBreathing,    // 4s each phase (general calming)
  progressive,     // starts 2/0/2, gradually slows to 4/0/5 (overload)
  extendedExhale,  // 4s inhale, 0 hold, 7s exhale (sleep)
  balanced,        // 4s inhale, 0 hold, 4s exhale (default)
}

extension _BreathPatternExt on _BreathPattern {
  int get inhaleMs => switch (this) {
        _BreathPattern.fourSevenEight => 4000,
        _BreathPattern.boxBreathing => 4000,
        _BreathPattern.progressive => 4000,
        _BreathPattern.extendedExhale => 4000,
        _BreathPattern.balanced => 4000,
      };

  int get holdMs => switch (this) {
        _BreathPattern.fourSevenEight => 7000,
        _BreathPattern.boxBreathing => 4000,
        _BreathPattern.progressive => 0,
        _BreathPattern.extendedExhale => 0,
        _BreathPattern.balanced => 0,
      };

  int get exhaleMs => switch (this) {
        _BreathPattern.fourSevenEight => 8000,
        _BreathPattern.boxBreathing => 4000,
        _BreathPattern.progressive => 5000,
        _BreathPattern.extendedExhale => 7000,
        _BreathPattern.balanced => 4000,
      };
}

class _BreathCircle extends StatelessWidget {
  final double breath;
  final Color color;
  final String label;

  const _BreathCircle({
    required this.breath,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final size = 160.0 + 80.0 * breath;

    return SizedBox(
      width: 280,
      height: 280,
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.06 + 0.04 * breath),
                color.withValues(alpha: 0.02),
                Colors.transparent,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
            border: Border.all(
              color: color.withValues(alpha: 0.2 + 0.4 * breath),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1 + 0.15 * breath),
                blurRadius: 40 * breath,
                spreadRadius: 8 * breath,
              ),
            ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: Anim.normal,
              child: Text(
                label,
                key: ValueKey(label),
                style: t.titleLarge?.copyWith(
                  color: color.withValues(alpha: 0.7 + 0.2 * breath),
                  fontWeight: FontWeight.w300,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
