import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/audio/audio_service.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/features/home/meditation_playback_cache.dart';
import 'package:meditator/shared/models/meditation.dart';
import 'package:meditator/shared/widgets/animated_number.dart';
import 'package:meditator/shared/widgets/aurora_shader_bg.dart';
import 'package:meditator/shared/widgets/celebration_overlay.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/custom_slider.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/particle_field.dart';
import 'package:meditator/shared/widgets/progress_arc.dart';

class MeditationPlayerScreen extends StatefulWidget {
  const MeditationPlayerScreen({super.key, this.meditationId});

  final String? meditationId;

  @override
  State<MeditationPlayerScreen> createState() =>
      _MeditationPlayerScreenState();
}

class _MeditationPlayerScreenState extends State<MeditationPlayerScreen>
    with TickerProviderStateMixin {
  static const _ambientUrls = <String, String?>{
    'Дождь':
        'https://assets.mixkit.co/sfx/preview/mixkit-light-rain-loop-2395.mp3',
    'Океан':
        'https://assets.mixkit.co/sfx/preview/mixkit-sea-waves-loop-1186.mp3',
    'Лес':
        'https://assets.mixkit.co/sfx/preview/mixkit-forest-birds-loop-1224.mp3',
    'Костёр':
        'https://assets.mixkit.co/sfx/preview/mixkit-campfire-crackling-loop-1710.mp3',
    'Тишина': null,
  };

  static const _ambientEmojis = <String, String>{
    'Дождь': '🌧️',
    'Океан': '🌊',
    'Лес': '🌲',
    'Костёр': '🔥',
    'Тишина': '🤫',
  };

  Meditation? _meditation;
  bool _loading = true;
  String? _error;
  bool _playing = false;
  double _volume = 0.9;
  double _speed = 1.0;
  String? _ambientKey;
  StreamSubscription<PlayerState>? _stateSub;
  bool _completionHandled = false;
  bool _isSeeking = false;
  Duration _seekPreview = Duration.zero;

  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _load();
    _stateSub = AudioService.instance.playerStateStream.listen(_onPlayerState);
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  Future<void> _load() async {
    final rawId = widget.meditationId;
    if (rawId == null || rawId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Медитация не выбрана';
      });
      return;
    }
    final id = Uri.decodeComponent(rawId);
    Map<String, dynamic>? row;
    try {
      row = await Db.instance.getMeditationById(id);
    } catch (_) {}
    Meditation? m;
    if (row != null) {
      m = Meditation.fromJson(row);
    } else {
      m = MeditationPlaybackCache.byId[id];
    }
    if (!mounted) return;
    setState(() {
      _meditation = m;
      _loading = false;
      _error = m == null ? 'Не удалось загрузить медитацию' : null;
      _speed = AudioService.instance.speed;
    });
    if (m?.audioUrl != null && m!.audioUrl!.isNotEmpty) {
      try {
        await AudioService.instance.playUrl(m.audioUrl!);
        await AudioService.instance.setVolume(_volume);
        if (mounted) setState(() => _playing = true);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось воспроизвести аудио')),
          );
        }
      }
    }
  }

  void _onPlayerState(PlayerState state) {
    final playingNow =
        state.playing && state.processingState != ProcessingState.completed;
    if (mounted && _playing != playingNow) {
      setState(() => _playing = playingNow);
    }
    if (state.processingState != ProcessingState.completed) return;
    if (_completionHandled || !mounted) return;
    _completionHandled = true;
    HapticFeedback.heavyImpact();
    final minutes = _meditation?.durationMinutes ?? 0;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: Anim.dramatic,
      pageBuilder: (ctx, _, __) => _CompletionOverlay(
        minutes: minutes,
        onClose: () {
          Navigator.pop(ctx);
          context.pop();
        },
        onGarden: () {
          Navigator.pop(ctx);
          context.pop();
          context.go('/garden');
        },
      ),
    );
  }

  Duration get _fallbackTotal {
    final m = _meditation;
    if (m == null) return Duration.zero;
    return Duration(minutes: m.durationMinutes);
  }

  Future<void> _togglePlay() async {
    final m = _meditation;
    if (m?.audioUrl == null || m!.audioUrl!.isEmpty) return;
    HapticFeedback.mediumImpact();
    if (_playing) {
      await AudioService.instance.pause();
    } else {
      await AudioService.instance.resume();
    }
    if (mounted) setState(() => _playing = !_playing);
  }

  Future<void> _stop() async {
    await AudioService.instance.stop();
    await AudioService.instance.stopAmbient();
    if (mounted) {
      setState(() {
        _playing = false;
        _ambientKey = null;
      });
      context.pop();
    }
  }

  Future<void> _setVolume(double v) async {
    setState(() => _volume = v);
    await AudioService.instance.setVolume(v);
  }

  Future<void> _setSpeed(double speed) async {
    setState(() => _speed = speed);
    await AudioService.instance.setSpeed(speed);
  }

  Future<void> _seekRelativeSeconds(int deltaSeconds) async {
    final total = AudioService.instance.totalDuration ?? _fallbackTotal;
    if (total <= Duration.zero) return;
    final current = _isSeeking ? _seekPreview : AudioService.instance.position;
    final target = current + Duration(seconds: deltaSeconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > total ? total : target);
    await AudioService.instance.seek(clamped);
    if (mounted) {
      setState(() {
        _isSeeking = false;
        _seekPreview = clamped;
      });
    }
    HapticFeedback.selectionClick();
  }

  void _openSpeedPicker() {
    final options = <double>[0.8, 1.0, 1.25, 1.5];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(S.l, S.m, S.l, S.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Скорость воспроизведения',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(color: C.text),
              ),
              const SizedBox(height: S.m),
              for (final speed in options)
                ListTile(
                  onTap: () {
                    Navigator.pop(ctx);
                    _setSpeed(speed);
                  },
                  leading: Icon(
                    (_speed - speed).abs() < 0.001
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: (_speed - speed).abs() < 0.001 ? C.accent : C.textDim,
                  ),
                  title: Text(
                    '${speed.toStringAsFixed(speed % 1 == 0 ? 0 : 2)}x',
                    style: const TextStyle(color: C.text),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAmbient(String label) async {
    final url = _ambientUrls[label];
    setState(() => _ambientKey = label);
    if (url == null || url.isEmpty) {
      await AudioService.instance.stopAmbient();
      return;
    }
    try {
      await AudioService.instance.playAmbient(url);
      await AudioService.instance.setAmbientVolume(0.35);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось включить звук: $label')),
        );
      }
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _stateSub?.cancel();
    unawaited(AudioService.instance.stop());
    unawaited(AudioService.instance.stopAmbient());
    super.dispose();
  }

  String _fmt(Duration d) {
    final totalSec = d.inSeconds;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  (Color, Color) get _categoryColors {
    final cat = _meditation?.category;
    return switch (cat) {
      MeditationCategory.sleep || MeditationCategory.evening => (
        C.calm,
        C.primary,
      ),
      MeditationCategory.stress || MeditationCategory.anxiety => (
        C.primary,
        C.accent,
      ),
      MeditationCategory.morning || MeditationCategory.focus => (
        C.gold,
        C.energy,
      ),
      _ => (C.primary, C.accent),
    };
  }

  void _confirmStop() {
    final t = Theme.of(context).textTheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(S.l, S.m, S.l, S.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: C.textDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: S.l),
              Text(
                'Завершить медитацию?',
                style: t.titleLarge?.copyWith(color: C.text),
              ),
              const SizedBox(height: S.s),
              Text(
                'Прогресс текущей сессии будет потерян',
                style: t.bodyMedium?.copyWith(color: C.textSec),
              ),
              const SizedBox(height: S.l),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        foregroundColor: C.textSec,
                        padding: const EdgeInsets.symmetric(vertical: S.m),
                      ),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: S.m),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _stop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: C.rose,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: S.m),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(R.m),
                        ),
                      ),
                      child: const Text('Завершить'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final m = _meditation;
    final (c1, c2) = _categoryColors;

    return Scaffold(
      backgroundColor: C.bgDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: C.bgDeep),
          AuroraShaderBg(
            progress: _playing ? 0.5 : 0.0,
            color1: c1,
            color2: c2,
          ),
          const Positioned.fill(
            child: ParticleField(count: 30, twinkle: true),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: C.accent))
          else if (_error != null)
            _buildError(t)
          else
            _buildPlayer(t, m),
        ],
      ),
    );
  }

  Widget _buildError(TextTheme t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(S.l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: t.bodyLarge?.copyWith(color: C.textSec),
            ),
            const SizedBox(height: S.m),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Назад'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer(TextTheme t, Meditation? m) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(S.s, S.s, S.s, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  tooltip: 'Закрыть плеер',
                  icon: MIcon(MIconType.close, size: 24, color: C.text),
                ),
                const Spacer(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.l),
            child: Column(
              children: [
                Text(
                  m?.title ?? '',
                  textAlign: TextAlign.center,
                  style: t.headlineSmall?.copyWith(
                    color: C.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: S.s),
                Text(
                  m != null ? '${m.category.emoji} ${m.category.label}' : '',
                  style: t.bodyMedium?.copyWith(color: C.textSec),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 450.ms)
              .slideY(begin: 0.04, duration: 450.ms),
          const Spacer(),
          _buildProgressSection(t, m)
              .animate()
              .fadeIn(delay: 100.ms, duration: 500.ms)
              .scale(
                delay: 100.ms,
                duration: 500.ms,
                begin: const Offset(0.92, 0.92),
              ),
          const Spacer(),
          _buildControls(m),
          const SizedBox(height: S.l),
          _buildVolume(),
          const SizedBox(height: S.m),
          _buildAmbientPills(t),
          const SizedBox(height: S.m),
        ],
      ),
    );
  }

  Widget _buildProgressSection(TextTheme t, Meditation? m) {
    final hasAudio = m?.audioUrl != null && m!.audioUrl!.isNotEmpty;
    return StreamBuilder<Duration>(
      stream: AudioService.instance.positionStream,
      initialData: Duration.zero,
      builder: (context, positionSnap) {
        return StreamBuilder<Duration?>(
          stream: AudioService.instance.durationStream,
          initialData: AudioService.instance.totalDuration,
          builder: (context, totalSnap) {
            final currentPos = positionSnap.data ?? Duration.zero;
            final total = totalSnap.data ?? _fallbackTotal;
            final safeTotalMs = total.inMilliseconds > 0 ? total.inMilliseconds : 1;
            final shownPos = _isSeeking ? _seekPreview : currentPos;
            final clampedShownPos = shownPos < Duration.zero
                ? Duration.zero
                : (shownPos > total ? total : shownPos);
            final p = clampedShownPos.inMilliseconds / safeTotalMs;

            return Column(
              children: [
                ProgressArc(
                  progress: p.clamp(0.0, 1.0),
                  size: 290,
                  strokeWidth: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fmt(clampedShownPos),
                        style: const TextStyle(
                          fontSize: 36,
                          color: C.text,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: S.xs),
                      Text(
                        '${(p.clamp(0.0, 1.0) * 100).toInt()}%',
                        style: t.bodySmall?.copyWith(color: C.textDim),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: S.m),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: S.l),
                  child: Row(
                    children: [
                      Text(
                        _fmt(clampedShownPos),
                        style: t.bodySmall?.copyWith(color: C.textSec),
                      ),
                      const Spacer(),
                      Text(
                        _fmt(total),
                        style: t.bodySmall?.copyWith(color: C.textSec),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: S.l),
                  child: GlowSlider(
                    value: clampedShownPos.inMilliseconds
                            .toDouble()
                            .clamp(0.0, safeTotalMs.toDouble()) /
                        safeTotalMs.toDouble(),
                    onChangeStart: hasAudio
                        ? (v) {
                            setState(() {
                              _isSeeking = true;
                              _seekPreview =
                                  Duration(milliseconds: (v * safeTotalMs).round());
                            });
                          }
                        : null,
                    onChanged: hasAudio
                        ? (v) {
                            setState(() {
                              _isSeeking = true;
                              _seekPreview =
                                  Duration(milliseconds: (v * safeTotalMs).round());
                            });
                          }
                        : null,
                    onChangeEnd: hasAudio
                        ? (v) async {
                            final next =
                                Duration(milliseconds: (v * safeTotalMs).round());
                            await AudioService.instance.seek(next);
                            if (!mounted) return;
                            setState(() {
                              _isSeeking = false;
                              _seekPreview = next;
                            });
                            HapticFeedback.selectionClick();
                          }
                        : null,
                    activeColor: C.primary,
                    showGlow: _playing,
                    height: 5,
                    semanticLabel: 'Позиция воспроизведения',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Controls
  // ---------------------------------------------------------------------------

  Widget _buildControls(Meditation? m) {
    final hasAudio = m?.audioUrl != null && m!.audioUrl!.isNotEmpty;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _confirmStop,
              child: Semantics(
                button: true,
                label: 'Завершить медитацию',
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: C.rose.withValues(alpha: 0.2),
                  ),
                  child: MIcon(MIconType.stop, size: 26, color: C.rose),
                ),
              ),
            ),
            const SizedBox(width: S.xl),
            AnimatedBuilder(
              animation: _glowCtrl,
              builder: (context, child) {
                final glowT = _playing ? _glowCtrl.value : 0.0;
                return Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            C.glowPrimary.withValues(alpha: 0.3 + 0.35 * glowT),
                        blurRadius: 20 + 12 * glowT,
                        spreadRadius: -2 + 6 * glowT,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: hasAudio ? _togglePlay : null,
                child: Semantics(
                  button: true,
                  enabled: hasAudio,
                  label: _playing ? 'Пауза' : 'Воспроизвести',
                  child: AnimatedOpacity(
                    opacity: hasAudio ? 1.0 : 0.45,
                    duration: Anim.fast,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: hasAudio ? C.gradientPrimary : null,
                        color: hasAudio ? null : C.surfaceLight,
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: Anim.fast,
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: anim,
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: _playing
                              ? MIcon(
                                  MIconType.pause,
                                  key: const ValueKey(true),
                                  size: 36,
                                  color: Colors.white,
                                )
                              : MIcon(
                                  MIconType.play,
                                  key: const ValueKey(false),
                                  size: 36,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: S.xl),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: S.s),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: hasAudio ? () => _seekRelativeSeconds(-15) : null,
              icon: MIcon(MIconType.rewind, size: 24, color: C.textSec),
              label: const Text('−15с'),
            ),
            const SizedBox(width: S.m),
            TextButton.icon(
              onPressed: hasAudio ? () => _seekRelativeSeconds(15) : null,
              icon: MIcon(MIconType.forward, size: 24, color: C.textSec),
              label: const Text('+15с'),
            ),
            const SizedBox(width: S.m),
            TextButton.icon(
              onPressed: hasAudio ? _openSpeedPicker : null,
              icon: MIcon(MIconType.speed, size: 24, color: C.textSec),
              label: Text('${_speed.toStringAsFixed(_speed % 1 == 0 ? 0 : 2)}x'),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  // ---------------------------------------------------------------------------
  // Volume
  // ---------------------------------------------------------------------------

  Widget _buildVolume() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: S.l),
      child: Row(
        children: [
          MIcon(MIconType.volumeDown, size: 22, color: C.textDim),
          Expanded(
            child: GlowSlider(
              value: _volume,
              onChanged: _setVolume,
              activeColor: C.accent,
              showGlow: true,
              semanticLabel: 'Громкость',
            ),
          ),
          MIcon(MIconType.volumeUp, size: 22, color: C.textDim),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Ambient sound pills
  // ---------------------------------------------------------------------------

  Widget _buildAmbientPills(TextTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: S.l),
          child: Text(
            'Фоновый звук',
            style: t.titleSmall?.copyWith(color: C.textSec),
          ),
        ),
        const SizedBox(height: S.s),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: S.l),
          child: Row(
            children: _ambientUrls.keys.map((label) {
              final selected = _ambientKey == label;
              final emoji = _ambientEmojis[label] ?? '';
              return Padding(
                padding: const EdgeInsets.only(right: S.s),
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: 'Фоновый звук: $label',
                  child: GestureDetector(
                    onTap: () => _pickAmbient(label),
                    child: AnimatedContainer(
                      duration: Anim.fast,
                      padding: const EdgeInsets.symmetric(
                        horizontal: S.m,
                        vertical: S.s + 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(R.full),
                        gradient: selected ? C.gradientPrimary : null,
                        color:
                            selected ? null : Colors.white.withValues(alpha: 0.08),
                        border: Border.all(
                          color: selected ? C.primary : C.surfaceBorder,
                          width: selected ? 1.5 : 0.5,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: C.glowPrimary,
                                  blurRadius: 12,
                                  spreadRadius: -4,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: S.xs + 2),
                          Text(
                            label,
                            style: TextStyle(
                              color: selected ? Colors.white : C.textSec,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Completion overlay — full-screen blur with animated counter
// =============================================================================

class _CompletionOverlay extends StatefulWidget {
  const _CompletionOverlay({
    required this.minutes,
    required this.onClose,
    required this.onGarden,
  });

  final int minutes;
  final VoidCallback onClose;
  final VoidCallback onGarden;

  @override
  State<_CompletionOverlay> createState() => _CompletionOverlayState();
}

class _CompletionOverlayState extends State<_CompletionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _displayMinutes = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: Anim.dramatic)
      ..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _displayMinutes = widget.minutes);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accentStyle = t.displayLarge?.copyWith(color: C.accent);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final val = Curves.easeOut.transform(_ctrl.value);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14 * val, sigmaY: 14 * val),
          child: ColoredBox(
            color: C.bgDeep.withValues(alpha: 0.75 * val),
            child: Opacity(opacity: val, child: child),
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CelebrationOverlay(),
          Material(
            color: Colors.transparent,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: S.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: S.l),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('+', style: accentStyle),
                        AnimatedNumber(
                          value: _displayMinutes,
                          style: accentStyle,
                          duration: const Duration(milliseconds: 1200),
                          suffix: ' минут',
                        ),
                      ],
                    ),
                    const SizedBox(height: S.s),
                    Text(
                      'добавлено к практике',
                      style: t.bodyMedium?.copyWith(color: C.textSec),
                    ),
                    const SizedBox(height: S.xxl),
                    Text(
                      'Aura гордится тобой',
                      textAlign: TextAlign.center,
                      style: t.displayMedium,
                    ),
                    const SizedBox(height: S.xxl),
                    GlowButton(
                      onPressed: widget.onGarden,
                      showGlow: true,
                      glowColor: C.glowAccent,
                      width: double.infinity,
                      semanticLabel: 'Перейти в сад',
                      child: const Text('К саду'),
                    ),
                    const SizedBox(height: S.m),
                    TextButton(
                      onPressed: widget.onClose,
                      child: Text(
                        'Закрыть',
                        style: TextStyle(color: C.textSec),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
