import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/core/aura/atmosphere.dart';
import 'package:meditator/core/aura/aura_engine.dart';
import 'package:meditator/core/audio/audio_service.dart';
import 'package:meditator/core/cosmos/cosmos_state.dart';
import 'package:meditator/shared/theme/cosmic.dart';
import 'package:meditator/shared/widgets/cosmic_background.dart';
import 'package:meditator/shared/widgets/particle_field.dart';
import 'package:meditator/shared/widgets/aura_presence.dart';

class RealityBreakScreen extends ConsumerStatefulWidget {
  const RealityBreakScreen({super.key});

  @override
  ConsumerState<RealityBreakScreen> createState() =>
      _RealityBreakScreenState();
}

class _RealityBreakScreenState extends ConsumerState<RealityBreakScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _calmTransCtrl;
  late final AnimationController _exitCtrl;

  Timer? _timer;
  int _remaining = 45;
  int _phase = 0;
  bool _done = false;

  static const _phrases = [
    'Ты в безопасности.',
    'Дыши.',
    'Медленнее.',
    'Всё пройдёт.',
    '',
  ];

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    )..forward();

    _textCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    );

    // 45-second transition: overload → calm cosmos
    _calmTransCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 45),
    );

    _exitCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _textCtrl.forward();
      _calmTransCtrl.forward();
      _startAudio();
      _startTimer();
    });
  }

  Future<void> _startAudio() async {
    try {
      final audio = ref.read(audioServiceProvider);
      await audio.playEmergency();
    } catch (_) {}
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= 0) {
        _timer?.cancel();
        _finish();
        return;
      }
      setState(() {
        _remaining--;
        final newPhase = ((_phrases.length - 1) * (1 - _remaining / 45))
            .floor()
            .clamp(0, _phrases.length - 1);
        if (newPhase != _phase) {
          _phase = newPhase;
          _textCtrl.forward(from: 0);
        }
      });
    });
  }

  Future<void> _finish() async {
    HapticFeedback.lightImpact();

    final audio = ref.read(audioServiceProvider);
    await audio.fadeOut(duration: const Duration(milliseconds: 1500));

    ref.read(auraProvider.notifier).completeSession(
      sessionType: 'emergency',
      durationSeconds: 45,
    );
    setState(() => _done = true);
    _exitCtrl.forward();
  }

  // Interpolated universe mood for cosmos transition
  UniverseMood get _currentMood {
    final t = _calmTransCtrl.value;
    if (t < 0.3) return UniverseMood.overload;
    if (t < 0.6) return UniverseMood.anxiety;
    if (t < 0.85) return UniverseMood.fatigue;
    return UniverseMood.calm;
  }

  // Interpolated particle config
  double get _particleSpeed => lerpDouble(1.6, 0.7, _calmTransCtrl.value)!;
  int get _particleCount => lerpDouble(80, 30, _calmTransCtrl.value)!.round();
  bool get _chaotic => _calmTransCtrl.value < 0.4;

  PresenceState get _presenceState {
    if (_done) return PresenceState.calming;
    final t = _calmTransCtrl.value;
    if (t < 0.3) return PresenceState.responding;
    if (t < 0.7) return PresenceState.supporting;
    return PresenceState.calming;
  }

  @override
  void dispose() {
    _timer?.cancel();
    try {
      final audio = ref.read(audioServiceProvider);
      if (audio.isPlaying) audio.stop();
    } catch (_) {}
    _enterCtrl.dispose();
    _textCtrl.dispose();
    _calmTransCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _enterCtrl, _textCtrl, _calmTransCtrl, _exitCtrl,
        ]),
        builder: (_, __) {
          final enter = Curves.easeOut.transform(_enterCtrl.value);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Living cosmos — transitions from overload to calm
              Builder(builder: (context) {
                final cosmos = ref.watch(cosmosStateProvider);
                return CosmicBackground(
                  mood: _currentMood,
                  intensity: 1.0 + 0.3 * (1 - _calmTransCtrl.value),
                  seed: cosmos.personalSeed,
                  extraStars: cosmos.starCount - 50,
                  bloomBoost: cosmos.bloomBoost,
                  child: const SizedBox.expand(),
                );
              }),

              // Particles — slow down and thin out
              Positioned.fill(
                child: ParticleField(
                  count: _particleCount,
                  color: Cosmic.accent.withValues(alpha: 0.4),
                  maxRadius: 1.5,
                  speed: _particleSpeed,
                  chaotic: _chaotic,
                ),
              ),

              // Content
              SafeArea(
                child: _done ? _buildComplete(t) : _buildSession(t, enter),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSession(TextTheme t, double enter) {
    final textFade = Curves.easeOutCubic.transform(_textCtrl.value);

    return Opacity(
      opacity: enter,
      child: Column(
        children: [
          const Spacer(flex: 2),

          // AuraPresence — calming orb that transitions with the cosmos
          AuraPresence(
            size: 100,
            color: Cosmic.accent,
            glowColor: Cosmic.glowAccent,
            state: _presenceState,
          ),
          const SizedBox(height: Space.xl),

          // Phase text
          Opacity(
            opacity: textFade,
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - textFade)),
              child: Text(
                _phrases[_phase],
                style: t.displayMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w200,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildComplete(TextTheme t) {
    final exit = Curves.easeOutCubic.transform(_exitCtrl.value);

    return Opacity(
      opacity: exit,
      child: Column(
        children: [
          const Spacer(flex: 2),

          AuraPresence(
            size: 100,
            color: Cosmic.green,
            glowColor: Cosmic.green.withValues(alpha: 0.4),
            state: PresenceState.calming,
          ),
          const SizedBox(height: Space.xl),

          Text(
            'Лучше.',
            style: t.displayMedium?.copyWith(
              color: Cosmic.green,
              fontWeight: FontWeight.w300,
            ),
          ),

          const Spacer(flex: 2),

          Padding(
            padding: const EdgeInsets.only(bottom: Space.xxl),
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.xl, vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.full),
                  border: Border.all(
                    color: Cosmic.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Вернуться',
                  style: t.labelLarge?.copyWith(
                    color: Cosmic.green.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
