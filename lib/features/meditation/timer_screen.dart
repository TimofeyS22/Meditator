import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/shared/widgets/celebration_overlay.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/drag_dismiss.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/shared/widgets/particle_field.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with TickerProviderStateMixin {
  static const _durations = [3, 5, 10, 15, 20, 30];
  int _selectedMinutes = 10;
  bool _intervalBell = false;
  int _intervalMinutes = 5;

  bool _running = false;
  bool _paused = false;
  bool _done = false;
  bool _showConfetti = false;
  int _remainingSeconds = 0;
  Timer? _ticker;

  late final AnimationController _breatheCtrl;
  late final AnimationController _progressCtrl;

  @override
  void initState() {
    super.initState();
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _progressCtrl = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _breatheCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  void _start() {
    HapticFeedback.mediumImpact();
    setState(() {
      _running = true;
      _paused = false;
      _done = false;
      _remainingSeconds = _selectedMinutes * 60;
    });
    _progressCtrl.duration = Duration(minutes: _selectedMinutes);
    _progressCtrl.forward(from: 0);
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remainingSeconds--);
      if (_intervalBell &&
          _remainingSeconds > 0 &&
          _remainingSeconds % (_intervalMinutes * 60) == 0) {
        HapticFeedback.heavyImpact();
      }
      if (_remainingSeconds <= 0) {
        _finish();
      }
    });
  }

  void _togglePause() {
    HapticFeedback.lightImpact();
    if (_paused) {
      _progressCtrl.forward();
      _startTicker();
    } else {
      _progressCtrl.stop();
      _ticker?.cancel();
    }
    setState(() => _paused = !_paused);
  }

  void _finish() {
    _ticker?.cancel();
    _progressCtrl.stop();
    HapticFeedback.heavyImpact();
    setState(() {
      _done = true;
      _showConfetti = true;
    });
    _saveSession();
  }

  void _reset() {
    _ticker?.cancel();
    _progressCtrl.reset();
    setState(() {
      _running = false;
      _paused = false;
      _done = false;
      _remainingSeconds = 0;
    });
  }

  Future<void> _saveSession() async {
    final uid = AuthService.instance.userId;
    if (uid == null || uid.isEmpty) return;
    try {
      await Db.instance.createSession({
        'user_id': uid,
        'meditation_id': null,
        'duration_seconds': _selectedMinutes * 60,
        'completed': true,
      });
    } catch (_) {}
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: DragDismiss(
        enabled: !_running || _done,
        onDismiss: () => context.pop(),
        child: GradientBg(
          showStars: true,
          intensity: 0.5,
          child: Stack(
            children: [
              if (_running && !_done)
                const Positioned.fill(
                  child: ParticleField(count: 30, drift: true),
                ),
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(t),
                    Expanded(
                      child: _running ? _buildRunning(t) : _buildPicker(t),
                    ),
                  ],
                ),
              ),
              if (_showConfetti)
                CelebrationOverlay(
                  onComplete: () {
                    if (mounted) setState(() => _showConfetti = false);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(TextTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.s, S.s, S.s, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            tooltip: 'Назад',
            icon: MIcon(MIconType.arrowBack, size: 24, color: context.cText),
          ),
          Expanded(
            child: Text(
              'Таймер',
              textAlign: TextAlign.center,
              style: t.headlineMedium,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    ).animate().fadeIn(duration: Anim.normal);
  }

  Widget _buildPicker(TextTheme t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: S.l),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Выбери длительность', style: t.titleMedium),
          const SizedBox(height: S.l),
          Wrap(
            spacing: S.m,
            runSpacing: S.m,
            alignment: WrapAlignment.center,
            children: _durations.map((d) {
              final sel = d == _selectedMinutes;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedMinutes = d);
                },
                child: AnimatedContainer(
                  duration: Anim.fast,
                  curve: Anim.curve,
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: sel ? C.gradientPrimary : null,
                    color: sel ? null : context.cSurfaceLight,
                    border: Border.all(
                      color: sel ? Colors.transparent : context.cSurfaceBorder,
                    ),
                    boxShadow: sel
                        ? [BoxShadow(color: C.glowPrimary, blurRadius: 12, spreadRadius: -2)]
                        : null,
                  ),
                  child: Text(
                    '$d',
                    style: t.titleLarge?.copyWith(
                      color: sel ? Colors.white : context.cTextSec,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: S.xs),
          Text('минут', style: t.bodySmall?.copyWith(color: context.cTextSec)),
          const SizedBox(height: S.xl),
          SwitchListTile.adaptive(
            title: Text('Интервальный звонок', style: t.bodyMedium),
            subtitle: _intervalBell
                ? Text('Каждые $_intervalMinutes мин', style: t.bodySmall)
                : null,
            value: _intervalBell,
            activeColor: C.primary,
            onChanged: (v) => setState(() => _intervalBell = v),
            contentPadding: EdgeInsets.zero,
          ),
          if (_intervalBell) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [3, 5, 10].map((m) {
                final sel = m == _intervalMinutes;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: S.xs),
                  child: ChoiceChip(
                    label: Text('$m мин'),
                    selected: sel,
                    onSelected: (_) => setState(() => _intervalMinutes = m),
                    selectedColor: C.primary.withValues(alpha: 0.2),
                    labelStyle: TextStyle(color: sel ? C.primary : context.cTextSec),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: S.xl),
          GlowButton(
            onPressed: _start,
            showGlow: true,
            width: 200,
            semanticLabel: 'Начать медитацию $_selectedMinutes минут',
            child: const Text('Начать'),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
        ],
      ),
    );
  }

  Widget _buildRunning(TextTheme t) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([_breatheCtrl, _progressCtrl]),
          builder: (context, _) {
            final breathe = 0.8 + 0.2 * math.sin(_breatheCtrl.value * 2 * math.pi);
            final progress = _progressCtrl.isAnimating || _progressCtrl.isCompleted
                ? _progressCtrl.value
                : 0.0;
            return SizedBox(
              width: 240,
              height: 240,
              child: CustomPaint(
                painter: _TimerRingPainter(
                  progress: progress,
                  breathe: breathe,
                  paused: _paused,
                  done: _done,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _done
                            ? 'Готово'
                            : _formatTime(_remainingSeconds),
                        style: t.displayLarge?.copyWith(
                          fontWeight: FontWeight.w300,
                          letterSpacing: 2,
                        ),
                      ),
                      if (!_done)
                        Text(
                          _paused ? 'Пауза' : 'Дыши...',
                          style: t.bodySmall?.copyWith(color: context.cTextSec),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: S.xxl),
        if (_done) ...[
          Text('Отличная практика!', style: t.titleMedium)
              .animate()
              .fadeIn()
              .slideY(begin: 0.1),
          const SizedBox(height: S.l),
          GlowButton(
            onPressed: () => context.pop(),
            showGlow: true,
            width: 200,
            child: const Text('Закончить'),
          ).animate().fadeIn(delay: 200.ms),
        ] else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CircleAction(
                icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                label: _paused ? 'Продолжить' : 'Пауза',
                onTap: _togglePause,
              ),
              const SizedBox(width: S.xl),
              _CircleAction(
                icon: Icons.stop_rounded,
                label: 'Стоп',
                onTap: _reset,
              ),
            ],
          ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.cSurfaceLight,
              border: Border.all(color: context.cSurfaceBorder),
            ),
            child: Icon(icon, color: context.cText, size: 28),
          ),
          const SizedBox(height: S.xs),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _TimerRingPainter extends CustomPainter {
  _TimerRingPainter({
    required this.progress,
    required this.breathe,
    required this.paused,
    required this.done,
  });

  final double progress;
  final double breathe;
  final bool paused;
  final bool done;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 12;

    canvas.drawCircle(
      center,
      r * breathe,
      Paint()
        ..color = (done ? C.accent : C.primary).withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = C.surfaceLight.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      final sweep = 2 * math.pi * progress;
      final gradient = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + sweep,
        colors: [C.primary, C.accent, C.calm],
        stops: const [0.0, 0.5, 1.0],
        tileMode: TileMode.clamp,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: r))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );

      final endAngle = -math.pi / 2 + sweep;
      final dotPos = Offset(
        center.dx + r * math.cos(endAngle),
        center.dy + r * math.sin(endAngle),
      );
      canvas.drawCircle(
        dotPos,
        5,
        Paint()
          ..color = C.accent
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(dotPos, 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter old) =>
      old.progress != progress || old.breathe != breathe || old.done != done;
}
