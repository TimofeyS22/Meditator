import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/shared/models/breathing.dart' as m;
import 'package:meditator/shared/widgets/animated_number.dart';
import 'package:meditator/shared/widgets/breathing_ring.dart';
import 'package:meditator/shared/widgets/celebration_overlay.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/drag_dismiss.dart';
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
        _recordBreathingSession();
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

  Future<void> _recordBreathingSession() async {
    final uid = AuthService.instance.userId;
    if (uid == null) return;
    final totalSec = _ex.phases.fold<int>(0, (s, p) => s + p.seconds) * _ex.cycles;
    if (totalSec <= 0) return;
    try {
      await Db.instance.insertSession({
        'user_id': uid,
        'duration_seconds': totalSec,
        'completed': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
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
    return DragDismiss(
      onDismiss: () {
        _ctrl.pause();
        if (mounted) context.pop();
      },
      enabled: !_done,
      child: Scaffold(
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
      ),
    );
  }

  Widget _buildSession(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final completed = _done ? _ex.cycles : _cycleDisplay - 1;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(S.s, S.s, S.m, 0),
            child: Row(
              children: [
                IconButton(
                  icon: MIcon(MIconType.close, size: 24, color: context.cText),
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
          const SizedBox(height: S.m),
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
                                  : context.cTextDim.withValues(alpha: 0.4),
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
          const SizedBox(height: S.s),
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ringSize = (constraints.maxHeight * 0.85).clamp(120.0, 240.0);
                  return BreathingRing(
                    phases: _ctrl.phases,
                    cycles: _ex.cycles,
                    size: ringSize,
                    controller: _ctrl,
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(S.l, S.m, S.l, S.l),
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
      ),
    );
  }

  Widget _buildDone(BuildContext context) {
    final totalMin = (_totalSeconds / 60).ceil().clamp(1, 999);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(S.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                IgnorePointer(
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                      boxShadow: [
                        BoxShadow(
                          color: C.primary.withValues(alpha: 0.58),
                          blurRadius: 48,
                          spreadRadius: 8,
                        ),
                        BoxShadow(
                          color: C.accent.withValues(alpha: 0.42),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(0.78, 0.78),
                        end: const Offset(1.22, 1.22),
                        duration: 1700.ms,
                        curve: Curves.easeInOutCubic,
                      ),
                ),
                IgnorePointer(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          C.accent.withValues(alpha: 0.45),
                          C.primary.withValues(alpha: 0.22),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.42, 1.0],
                      ),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(1.08, 1.08),
                        end: const Offset(0.86, 0.86),
                        duration: 1300.ms,
                        curve: Curves.easeInOut,
                      ),
                ),
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
                      curve: Anim.curveGentle,
                    )
                    .fadeIn(duration: Anim.slow),
              ],
            ),
          ),
          const SizedBox(height: S.l),
          Text(
            'Ты сделал это',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium,
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
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: context.cTextSec, height: 1.5),
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
        ),
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
          style: tt.headlineLarge,
          suffix: suffix,
        ),
        const SizedBox(height: S.xs),
        Text(label, style: tt.bodySmall?.copyWith(color: context.cTextSec)),
      ],
    );
  }
}
