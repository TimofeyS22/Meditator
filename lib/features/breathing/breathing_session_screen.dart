import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/models/breathing.dart' as m;
import 'package:meditator/shared/widgets/animated_number.dart';
import 'package:meditator/shared/widgets/breathing_ring.dart';
import 'package:meditator/shared/widgets/celebration_overlay.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/shared/widgets/particle_field.dart';

class BreathingSessionScreen extends StatefulWidget {
  const BreathingSessionScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  State<BreathingSessionScreen> createState() => _BreathingSessionScreenState();
}

class _BreathingSessionScreenState extends State<BreathingSessionScreen> {
  late final m.BreathingExercise _ex;
  late final BreathingRingController _ctrl;
  bool _done = false;
  bool _showConfetti = false;
  int _cycleDisplay = 1;

  @override
  void initState() {
    super.initState();
    m.BreathingExercise? found;
    for (final e in m.BreathingExercise.presets) {
      if (e.id == widget.exerciseId) {
        found = e;
        break;
      }
    }
    _ex = found ?? m.BreathingExercise.presets.first;

    final phases = _ex.phases
        .map(
          (p) => BreathingPhase(
            label: p.label,
            seconds: p.seconds,
            targetScale: p.targetScale,
          ),
        )
        .toList();

    _ctrl = BreathingRingController(
      phases: phases,
      cycles: _ex.cycles,
      onCycleComplete: () {
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        setState(() {
          _cycleDisplay = (_cycleDisplay + 1).clamp(1, _ex.cycles);
        });
      },
      onFinished: () {
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        setState(() {
          _done = true;
          _showConfetti = true;
        });
      },
    );
    _ctrl.addListener(_onTick);
  }

  void _onTick() {
    if (_ctrl.isFinished && !_done) setState(() => _done = true);
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTick);
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleRun() {
    if (_done) return;
    if (_ctrl.isRunning) {
      _ctrl.pause();
    } else {
      _ctrl.start();
    }
    setState(() {});
  }

  int get _totalSeconds {
    final phaseSec = _ex.phases.fold<int>(0, (a, p) => a + p.seconds);
    return phaseSec * _ex.cycles;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBg(
        showStars: true,
        showAurora: true,
        intensity: 0.5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: ParticleField(count: 40, twinkle: true),
            ),
            if (_showConfetti) const CelebrationOverlay(),
            _done ? _buildDone(context) : _buildSession(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSession(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final completed = _done ? _ex.cycles : _cycleDisplay - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(S.s, S.s, S.m, 0),
          child: Row(
            children: [
              IconButton(
                icon: const MIcon(MIconType.close, size: 24, color: C.text),
                tooltip: 'Закрыть сессию',
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.l),
          child: Text(_ex.name, style: tt.headlineMedium)
              .animate()
              .fadeIn(duration: Anim.normal),
        ),
        const Spacer(),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_ex.cycles, (i) {
              final isFilled = i < completed;
              final isCurrent = i == completed && !_done;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedContainer(
                  duration: Anim.normal,
                  curve: Anim.curve,
                  width: isCurrent ? 10 : 8,
                  height: isCurrent ? 10 : 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isFilled ? C.gradientPrimary : null,
                    color: isFilled ? null : Colors.transparent,
                    border: isFilled
                        ? null
                        : Border.all(
                            color: isCurrent
                                ? _ex.color.withValues(alpha: 0.8)
                                : C.textDim.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                    boxShadow: isFilled
                        ? [
                            BoxShadow(
                              color: C.primary.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: S.l),
        Center(
          child: BreathingRing(
            phases: _ctrl.phases,
            cycles: _ex.cycles,
            size: 280,
            controller: _ctrl,
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(S.l, S.m, S.l, S.xl),
          child: GlowButton(
            onPressed: _toggleRun,
            width: double.infinity,
            showGlow: true,
            glowColor: _ctrl.isRunning ? C.glowPrimary : C.glowAccent,
            semanticLabel: _ctrl.isRunning
                ? 'Поставить дыхание на паузу'
                : 'Запустить дыхательную сессию',
            child: Text(_ctrl.isRunning ? 'Пауза' : 'Старт'),
          ),
        ),
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final totalMin = (_totalSeconds / 60).ceil().clamp(1, 999);

    return Padding(
      padding: const EdgeInsets.all(S.l),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: C.gradientPrimary,
            ),
            child: const MIcon(MIconType.check, size: 32, color: Colors.white),
          )
              .animate()
              .scale(
                begin: const Offset(0, 0),
                end: const Offset(1, 1),
                duration: Anim.dramatic,
                curve: Anim.curveSpring,
              )
              .fadeIn(duration: Anim.slow),
          const SizedBox(height: S.l),
          Text(
            'Ты сделал это',
            textAlign: TextAlign.center,
            style: tt.displayMedium,
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: Anim.slow)
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1, 1),
                delay: 200.ms,
                duration: Anim.dramatic,
                curve: Anim.curve,
              ),
          const SizedBox(height: S.s),
          Text(
            'Несколько циклов осознанного дыхания — уже победа',
            textAlign: TextAlign.center,
            style: tt.bodyLarge?.copyWith(color: C.textSec, height: 1.5),
          ).animate().fadeIn(delay: 350.ms, duration: Anim.slow),
          const SizedBox(height: S.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatTile(
                value: totalMin,
                suffix: ' мин',
                label: 'Время',
              ),
              const SizedBox(width: S.xxl),
              _StatTile(
                value: _ex.cycles,
                label: 'Циклов',
              ),
            ],
          ).animate().fadeIn(delay: 500.ms, duration: Anim.slow),
          const SizedBox(height: S.xxl),
          GlowButton(
            onPressed: () => context.pop(),
            width: double.infinity,
            showGlow: true,
            glowColor: C.glowAccent,
            semanticLabel: 'Завершить дыхательную сессию',
            child: const Text('Готово'),
          ).animate().fadeIn(delay: 600.ms, duration: Anim.normal),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    this.suffix,
  });

  final int value;
  final String label;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        AnimatedNumber(
          value: value,
          style: tt.headlineLarge?.copyWith(color: C.text),
          suffix: suffix,
        ),
        const SizedBox(height: S.xs),
        Text(label, style: tt.bodySmall?.copyWith(color: C.textSec)),
      ],
    );
  }
}
