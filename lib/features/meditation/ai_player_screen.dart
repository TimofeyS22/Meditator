import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/audio/audio_service.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/core/config/env.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/features/meditation/biometric_overlay.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';

enum _AiPlayerState { idle, generating, ready, playing, paused, completed, error }

class AiPlayerScreen extends StatefulWidget {
  const AiPlayerScreen({
    super.key,
    this.durationMinutes = 10,
    this.moodOverride,
  });

  final int durationMinutes;
  final String? moodOverride;

  @override
  State<AiPlayerScreen> createState() => _AiPlayerScreenState();
}

class _AiPlayerScreenState extends State<AiPlayerScreen>
    with SingleTickerProviderStateMixin {
  _AiPlayerState _state = _AiPlayerState.idle;
  String _title = '';
  String _description = '';
  String _contextSummary = '';
  String? _audioUrl;
  String? _errorMsg;
  StreamSubscription<PlayerState>? _stateSub;
  late final AnimationController _pulseCtrl;
  late final BiometricMonitor _bioMonitor;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _stateSub = AudioService.instance.playerStateStream.listen(_onPlayerState);
    _bioMonitor = BiometricMonitor();
    _startGeneration();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _stateSub?.cancel();
    _bioMonitor.dispose();
    super.dispose();
  }

  void _onPlayerState(PlayerState state) {
    if (!mounted) return;
    if (state.processingState == ProcessingState.completed) {
      setState(() => _state = _AiPlayerState.completed);
      HapticFeedback.heavyImpact();
      _recordSession();
    }
  }

  Future<void> _startGeneration() async {
    setState(() => _state = _AiPlayerState.generating);
    try {
      final result = await ApiService.instance.generatePersonalMeditation(
        durationMinutes: widget.durationMinutes,
        moodOverride: widget.moodOverride,
      );
      if (result == null) {
        setState(() {
          _state = _AiPlayerState.error;
          _errorMsg = 'Не удалось сгенерировать медитацию';
        });
        return;
      }
      final rawUrl = result['audio_url'] as String? ?? '';
      final url = rawUrl.startsWith('/') ? '${Env.apiUrl}$rawUrl' : rawUrl;

      setState(() {
        _title = result['title'] as String? ?? 'Персональная медитация';
        _description = result['description'] as String? ?? '';
        _contextSummary = result['context_summary'] as String? ?? '';
        _audioUrl = url;
        _state = _AiPlayerState.ready;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _AiPlayerState.error;
          _errorMsg = 'Ошибка: $e';
        });
      }
    }
  }

  Future<void> _play() async {
    if (_audioUrl == null) return;
    try {
      await AudioService.instance.playUrl(_audioUrl!);
      setState(() => _state = _AiPlayerState.playing);
    } catch (_) {
      setState(() {
        _state = _AiPlayerState.error;
        _errorMsg = 'Не удалось воспроизвести аудио';
      });
    }
  }

  Future<void> _pause() async {
    await AudioService.instance.pause();
    setState(() => _state = _AiPlayerState.paused);
  }

  Future<void> _resume() async {
    await AudioService.instance.resume();
    setState(() => _state = _AiPlayerState.playing);
  }

  Future<void> _recordSession() async {
    final uid = AuthService.instance.userId;
    if (uid == null) return;
    try {
      await ApiService.instance.insertSession({
        'user_id': uid,
        'duration_seconds': widget.durationMinutes * 60,
        'completed': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBg(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: S.s, vertical: S.xs),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close, color: context.cText),
                      onPressed: () {
                        AudioService.instance.stop();
                        context.pop();
                      },
                    ),
                    const Spacer(),
                    Text(
                      'AI-Медитация',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(child: _buildBody(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    switch (_state) {
      case _AiPlayerState.idle:
      case _AiPlayerState.generating:
        return _buildGenerating(theme);
      case _AiPlayerState.ready:
        return _buildReady(theme);
      case _AiPlayerState.playing:
      case _AiPlayerState.paused:
        return _buildPlaying(theme);
      case _AiPlayerState.completed:
        return _buildCompleted(theme);
      case _AiPlayerState.error:
        return _buildError(theme);
    }
  }

  Widget _buildGenerating(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) => Transform.scale(
              scale: 1.0 + _pulseCtrl.value * 0.15,
              child: child,
            ),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    C.accent.withValues(alpha: 0.3),
                    C.accent.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: const Icon(Icons.auto_awesome, size: 48, color: C.accent),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(
                duration: 2000.ms,
                color: C.accent.withValues(alpha: 0.2),
              ),
          const SizedBox(height: S.l),
          Text(
            'Создаю медитацию для тебя...',
            style: theme.textTheme.titleLarge,
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: S.s),
          Text(
            'AI анализирует твоё настроение,\nцели и историю практик',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: context.cTextDim),
          ).animate().fadeIn(delay: 300.ms, duration: 600.ms),
          const SizedBox(height: S.xl),
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: C.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReady(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(S.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Icon(Icons.self_improvement, size: 64, color: C.accent)
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.8, 0.8)),
          const SizedBox(height: S.l),
          Text(
            _title,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
          const SizedBox(height: S.s),
          Text(
            _description,
            style: theme.textTheme.bodyMedium?.copyWith(color: context.cTextDim),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
          if (_contextSummary.isNotEmpty) ...[
            const SizedBox(height: S.m),
            GlassCard(
              padding: const EdgeInsets.all(S.m),
              child: Text(
                _contextSummary,
                style: theme.textTheme.bodySmall?.copyWith(color: context.cTextSec),
                textAlign: TextAlign.center,
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
          ],
          const SizedBox(height: S.xl),
          GlowButton(
            onPressed: _play,
            width: 200,
            showGlow: true,
            semanticLabel: 'Начать медитацию',
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow_rounded, size: 28),
                SizedBox(width: S.xs),
                Text('Начать'),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
        ],
      ),
      ),
    );
  }

  Widget _buildPlaying(ThemeData theme) {
    final isPlaying = _state == _AiPlayerState.playing;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(S.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) => Transform.scale(
              scale: isPlaying ? (1.0 + _pulseCtrl.value * 0.08) : 1.0,
              child: child,
            ),
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    C.accent.withValues(alpha: 0.25),
                    C.accent.withValues(alpha: 0.02),
                  ],
                ),
              ),
              child: Icon(
                isPlaying ? Icons.self_improvement : Icons.pause_circle_outline,
                size: 64,
                color: C.accent,
              ),
            ),
          ),
          const SizedBox(height: S.s),
          BiometricOverlay(monitor: _bioMonitor),
          const SizedBox(height: S.s),
          Text(
            _title,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: S.l),
          StreamBuilder<Duration>(
            stream: AudioService.instance.positionStream,
            builder: (_, snap) {
              final pos = snap.data ?? Duration.zero;
              final total = Duration(minutes: widget.durationMinutes);
              return Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: C.accent,
                      inactiveTrackColor: context.cSurfaceLight,
                      thumbColor: C.accent,
                      overlayColor: C.accent.withValues(alpha: 0.1),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      min: 0,
                      max: total.inSeconds.toDouble().clamp(1, double.infinity),
                      value: pos.inSeconds.toDouble().clamp(0, total.inSeconds.toDouble()),
                      onChanged: (v) {
                        AudioService.instance.seek(Duration(seconds: v.toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: S.l),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(pos), style: theme.textTheme.bodySmall),
                        Text(_fmt(total), style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: S.l),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 64,
                  color: C.accent,
                ),
                onPressed: isPlaying ? _pause : _resume,
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCompleted(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 80, color: C.accent)
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(begin: const Offset(0.6, 0.6)),
          const SizedBox(height: S.l),
          Text(
            'Медитация завершена',
            style: theme.textTheme.headlineSmall,
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: S.s),
          Text(
            '${widget.durationMinutes} мин осознанности',
            style: theme.textTheme.bodyMedium?.copyWith(color: context.cTextDim),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: S.xl),
          GlowButton(
            onPressed: () {
              AudioService.instance.stop();
              context.go('/practice');
            },
            width: 200,
            showGlow: true,
            semanticLabel: 'На главную',
            child: const Text('На главную'),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(S.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: C.error),
            const SizedBox(height: S.m),
            Text(
              _errorMsg ?? 'Произошла ошибка',
              style: theme.textTheme.bodyLarge?.copyWith(color: context.cText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: S.l),
            GlowButton(
              onPressed: _startGeneration,
              width: 200,
              semanticLabel: 'Попробовать снова',
              child: const Text('Попробовать снова'),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
