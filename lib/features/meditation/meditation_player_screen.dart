import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/audio/audio_service.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/core/config/env.dart';
import 'package:meditator/core/downloads/download_manager.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/core/health/health_service.dart';
import 'package:meditator/features/home/meditation_playback_cache.dart';
import 'package:meditator/shared/models/meditation.dart';
import 'package:meditator/shared/widgets/animated_number.dart';
import 'package:meditator/shared/widgets/celebration_overlay.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/custom_slider.dart';
import 'package:meditator/shared/widgets/drag_dismiss.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/particle_field.dart';
import 'package:meditator/shared/widgets/progress_arc.dart';
import 'package:meditator/features/sound_lab/binaural_engine.dart';

class MeditationPlayerScreen extends StatefulWidget {
  const MeditationPlayerScreen({super.key, this.meditationId});

  final String? meditationId;

  @override
  State<MeditationPlayerScreen> createState() =>
      _MeditationPlayerScreenState();
}

class _MeditationPlayerScreenState extends State<MeditationPlayerScreen>
    with TickerProviderStateMixin {
  static final _ambientUrls = <String, String?>{
    'Дождь': '${Env.apiUrl}/audio/ambient/rain.mp3',
    'Океан': '${Env.apiUrl}/audio/ambient/ocean.mp3',
    'Лес': '${Env.apiUrl}/audio/ambient/forest.mp3',
    'Костёр': '${Env.apiUrl}/audio/ambient/campfire.mp3',
    'Тишина': null,
  };

  static const _ambientMIcons = <String, MIconType>{
    'Дождь': MIconType.eco,
    'Океан': MIconType.air,
    'Лес': MIconType.park,
    'Костёр': MIconType.fire,
    'Тишина': MIconType.meditation,
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

  bool _immersive = false;
  Timer? _immersiveTimer;

  BinauralPreset? _binauralPreset;
  AudioPlayer? _binauralPlayer;
  double _binauralVolume = 0.2;
  bool _showBinaural = false;

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
        final localFile = DownloadManager.instance.localPath(m.id);
        if (localFile != null) {
          await AudioService.instance.playFile(localFile);
        } else {
          await AudioService.instance.playUrl(m.audioUrl!);
        }
        await AudioService.instance.setVolume(_volume);
        if (mounted) setState(() => _playing = true);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось воспроизвести аудио')),
          );
        }
      }
    } else if (m != null) {
      _startTextTimer(m.durationMinutes);
    }
  }

  Timer? _textTimer;
  final ValueNotifier<Duration> _textPos = ValueNotifier(Duration.zero);

  void _startTextTimer(int minutes) {
    _textTimer?.cancel();
    _textPos.value = Duration.zero;
    setState(() => _playing = true);
    _textTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      _textPos.value += const Duration(seconds: 1);
      final total = Duration(minutes: minutes);
      if (_textPos.value >= total) {
        t.cancel();
        _onPlayerState(PlayerState(true, ProcessingState.completed));
      }
    });
    _scheduleImmersive();
  }

  void _toggleTextTimer() {
    final m = _meditation;
    if (m == null) return;
    if (_playing) {
      _textTimer?.cancel();
      _immersiveTimer?.cancel();
      if (mounted) setState(() { _immersive = false; _playing = false; });
    } else {
      _startTextTimer(m.durationMinutes);
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
    _recordSession();
    final minutes = _meditation?.durationMinutes ?? 0;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: Anim.dramatic,
      pageBuilder: (ctx, _, _) => _CompletionOverlay(
        minutes: minutes,
        onClose: () {
          Navigator.pop(ctx);
          context.pop();
        },
        onGarden: () {
          Navigator.pop(ctx);
          context.pop();
          context.push('/garden');
        },
      ),
    );
  }

  Future<void> _recordSession() async {
    final uid = AuthService.instance.userId;
    if (uid == null) return;
    final m = _meditation;
    final durationSec = (m?.durationMinutes ?? 0) * 60;
    if (durationSec <= 0) return;
    try {
      await Db.instance.insertSession({
        'user_id': uid,
        'meditation_id': m?.id,
        'duration_seconds': durationSec,
        'completed': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      _waterRandomPlant(uid);
      final snapshot = await HealthService.instance.collectSnapshot();
      await Db.instance.submitBiometrics({
        ...snapshot,
        'user_id': uid,
        'meditation_id': m?.id,
        'duration_seconds': durationSec,
        'context': 'post_meditation',
      });
    } catch (_) {}
  }

  Future<void> _waterRandomPlant(String uid) async {
    try {
      final plants = await Db.instance.getGarden(uid);
      if (plants.isEmpty) return;
      plants.shuffle();
      final plant = plants.first;
      final id = plant['id'] as String?;
      if (id == null) return;
      final wc = ((plant['water_count'] ?? plant['waterCount'] ?? 0) as num).toInt();
      await Db.instance.updatePlant(id, {'water_count': wc + 1});
    } catch (_) {}
  }

  Duration get _fallbackTotal {
    final m = _meditation;
    if (m == null) return Duration.zero;
    return Duration(minutes: m.durationMinutes);
  }

  void _scheduleImmersive() {
    _immersiveTimer?.cancel();
    _immersiveTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _playing) setState(() => _immersive = true);
    });
  }

  void _exitImmersive() {
    _immersiveTimer?.cancel();
    if (_immersive && mounted) setState(() => _immersive = false);
    if (_playing) _scheduleImmersive();
  }

  bool get _hasAudio => _meditation?.audioUrl != null && _meditation!.audioUrl!.isNotEmpty;

  Future<void> _togglePlay() async {
    final m = _meditation;
    if (m == null) return;
    HapticFeedback.mediumImpact();
    if (_hasAudio) {
      if (_playing) {
        await AudioService.instance.pause();
        _immersiveTimer?.cancel();
        if (mounted) setState(() => _immersive = false);
      } else {
        await AudioService.instance.resume();
        _scheduleImmersive();
      }
      if (mounted) setState(() => _playing = !_playing);
    } else {
      _toggleTextTimer();
    }
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
      backgroundColor: context.cSurface,
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
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: S.m),
              for (final speed in options)
                ListTile(
                  onTap: () {
                    Navigator.pop(ctx);
                    _setSpeed(speed);
                  },
                  leading: MIcon(
                    (_speed - speed).abs() < 0.001
                        ? MIconType.check
                        : MIconType.meditation,
                    size: 22,
                    color: (_speed - speed).abs() < 0.001 ? C.accent : ctx.cTextDim,
                  ),
                  title: Text(
                    '${speed.toStringAsFixed(speed % 1 == 0 ? 0 : 2)}x',
                    style: TextStyle(color: ctx.cText),
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
    _immersiveTimer?.cancel();
    _textTimer?.cancel();
    _textPos.dispose();
    _glowCtrl.dispose();
    _stateSub?.cancel();
    _binauralPlayer?.dispose();
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
      backgroundColor: context.cSurface,
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
                  color: ctx.cTextDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: S.l),
              Text(
                'Завершить медитацию?',
                style: t.titleLarge,
              ),
              const SizedBox(height: S.s),
              Text(
                'Прогресс текущей сессии будет потерян',
                style: t.bodyMedium,
              ),
              const SizedBox(height: S.l),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        foregroundColor: ctx.cTextSec,
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

    return DragDismiss(
      onDismiss: () {
        AudioService.instance.stop();
        AudioService.instance.stopAmbient();
        if (mounted) context.pop();
      },
      enabled: true,
      child: Scaffold(
        backgroundColor: C.bgDeep,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: C.bgDeep),
            Positioned.fill(
              child: _CosmicBackground(
                playing: _playing,
                glowAnimation: _glowCtrl,
                color1: c1,
                color2: c2,
              ),
            ),
            const Positioned.fill(
              child: ParticleField(count: 60, twinkle: true),
            ),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: C.accent))
          else if (_error != null)
            _buildError(t)
            else
              _buildPlayer(t, m),
          ],
        ),
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
            const MIcon(MIconType.meditation, size: 48, color: C.primary),
            const SizedBox(height: S.m),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: t.bodyLarge?.copyWith(color: context.cTextSec),
            ),
            const SizedBox(height: S.l),
            GlowButton(
              onPressed: () => context.pop(),
              width: 200,
              child: const Text('Назад'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer(TextTheme t, Meditation? m) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _immersive ? _exitImmersive : null,
      child: SafeArea(
        child: Column(
          children: [
            AnimatedOpacity(
              opacity: _immersive ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(S.s, S.s, S.s, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _immersive ? null : () => context.pop(),
                      tooltip: 'Закрыть плеер',
                      icon: MIcon(MIconType.close, size: 24, color: context.cText),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _immersive ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 600),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: S.l),
                child: Column(
                  children: [
                    Hero(
                      tag: 'med_title_${widget.meditationId ?? ''}',
                      flightShuttleBuilder: (_, anim, __, ___, ____) =>
                          DefaultTextStyle(
                        style: t.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700) ??
                            const TextStyle(),
                        child: Text(
                          m?.title ?? '',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      child: Text(
                        m?.title ?? '',
                        textAlign: TextAlign.center,
                        style: t.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: S.xs),
                    Text(
                      m != null ? m.category.label : '',
                      style: t.bodyMedium,
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 450.ms)
                  .slideY(begin: 0.04, duration: 450.ms),
            ),
            Expanded(
              child: Center(
                child: _buildProgressSection(t, m)
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 500.ms)
                    .scale(
                      delay: 100.ms,
                      duration: 500.ms,
                      begin: const Offset(0.92, 0.92),
                    ),
              ),
            ),
            AnimatedOpacity(
              opacity: _immersive ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 600),
              child: _buildControls(m),
            ),
            AnimatedOpacity(
              opacity: _immersive ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 600),
              child: Column(
                children: [
                  const SizedBox(height: S.s),
                  _buildVolume(),
                  const SizedBox(height: S.s),
                  _buildAmbientPills(t),
                  const SizedBox(height: S.s),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextProgress(TextTheme t, Meditation? m) {
    final total = Duration(minutes: m?.durationMinutes ?? 10);
    return ValueListenableBuilder<Duration>(
      valueListenable: _textPos,
      builder: (context, pos, _) {
        final safeTotalMs = total.inMilliseconds > 0 ? total.inMilliseconds : 1;
        final p = (pos.inMilliseconds / safeTotalMs).clamp(0.0, 1.0);
        return Column(
          children: [
            ProgressArc(
              progress: p,
              size: 220,
              strokeWidth: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fmt(pos),
                    style: TextStyle(
                      fontSize: 32,
                      color: context.cText,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: S.xs),
                  Text('${(p * 100).toInt()}%', style: t.bodySmall),
                ],
              ),
            ),
            if (m?.description != null && m!.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(S.l, S.m, S.l, 0),
                child: Text(
                  m.description,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(
                    color: context.cTextSec,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildProgressSection(TextTheme t, Meditation? m) {
    if (!_hasAudio) return _buildTextProgress(t, m);
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
                        style: TextStyle(
                          fontSize: 36,
                          color: context.cText,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: S.xs),
                      Text(
                        '${(p.clamp(0.0, 1.0) * 100).toInt()}%',
                        style: t.bodySmall,
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
                        style: t.bodySmall?.copyWith(color: context.cTextSec),
                      ),
                      const Spacer(),
                      Text(
                        _fmt(total),
                        style: t.bodySmall?.copyWith(color: context.cTextSec),
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
                    onChangeStart: _hasAudio
                        ? (v) {
                            setState(() {
                              _isSeeking = true;
                              _seekPreview =
                                  Duration(milliseconds: (v * safeTotalMs).round());
                            });
                          }
                        : null,
                    onChanged: _hasAudio
                        ? (v) {
                            setState(() {
                              _isSeeking = true;
                              _seekPreview =
                                  Duration(milliseconds: (v * safeTotalMs).round());
                            });
                          }
                        : null,
                    onChangeEnd: _hasAudio
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
    final hasAudio = _hasAudio;
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
                onTap: _togglePlay,
                child: Semantics(
                  button: true,
                  enabled: true,
                  label: _playing ? 'Пауза' : 'Воспроизвести',
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: C.gradientPrimary,
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
              icon: MIcon(MIconType.rewind, size: 24, color: context.cTextSec),
              label: const Text('−15с'),
            ),
            const SizedBox(width: S.m),
            TextButton.icon(
              onPressed: hasAudio ? () => _seekRelativeSeconds(15) : null,
              icon: MIcon(MIconType.forward, size: 24, color: context.cTextSec),
              label: const Text('+15с'),
            ),
            const SizedBox(width: S.m),
            TextButton.icon(
              onPressed: hasAudio ? _openSpeedPicker : null,
              icon: MIcon(MIconType.speed, size: 24, color: context.cTextSec),
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
          MIcon(MIconType.volumeDown, size: 22, color: context.cTextDim),
          Expanded(
            child: GlowSlider(
              value: _volume,
              onChanged: _setVolume,
              activeColor: C.accent,
              showGlow: true,
              semanticLabel: 'Громкость',
            ),
          ),
          MIcon(MIconType.volumeUp, size: 22, color: context.cTextDim),
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
            style: t.titleSmall?.copyWith(color: context.cTextSec),
          ),
        ),
        const SizedBox(height: S.s),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: S.l),
          child: Row(
            children: _ambientUrls.keys.map((label) {
              final selected = _ambientKey == label;
              final mIcon = _ambientMIcons[label];
              return Padding(
                padding: const EdgeInsets.only(right: S.s),
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: 'Фоновый звук: $label',
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _pickAmbient(label);
                    },
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
                          color: selected ? C.primary : context.cSurfaceBorder,
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
                          if (mIcon != null)
                            MIcon(mIcon, size: 16, color: selected ? Colors.white : context.cTextSec),
                          if (mIcon != null)
                            const SizedBox(width: S.xs + 2),
                          Text(
                            label,
                            style: TextStyle(
                              color: selected ? Colors.white : context.cTextSec,
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
        const SizedBox(height: S.m),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.l),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showBinaural = !_showBinaural);
            },
            child: Row(
              children: [
                MIcon(MIconType.meditation, size: 18, color: context.cTextSec),
                const SizedBox(width: S.xs),
                Text(
                  'Бинауральные ритмы',
                  style: t.titleSmall?.copyWith(color: context.cTextSec),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _showBinaural ? 0.25 : 0,
                  duration: Anim.fast,
                  child: MIcon(MIconType.chevronRight, size: 18, color: context.cTextDim),
                ),
              ],
            ),
          ),
        ),
        if (_showBinaural) ...[
          const SizedBox(height: S.s),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: S.l),
              itemCount: binauralPresets.length,
              separatorBuilder: (_, __) => const SizedBox(width: S.s),
              itemBuilder: (_, i) {
                final preset = binauralPresets[i];
                final sel = _binauralPreset?.name == preset.name;
                return GestureDetector(
                  onTap: () => _pickBinaural(preset),
                  child: AnimatedContainer(
                    duration: Anim.fast,
                    width: 130,
                    padding: const EdgeInsets.all(S.s),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(R.m),
                      gradient: sel ? C.gradientPrimary : null,
                      color: sel ? null : Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: sel ? C.primary : context.cSurfaceBorder,
                        width: sel ? 1.5 : 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          preset.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: sel ? Colors.white : context.cText,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preset.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: sel ? Colors.white70 : context.cTextDim,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_binauralPreset != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(S.l, S.s, S.l, 0),
              child: Row(
                children: [
                  Text('Громкость', style: TextStyle(fontSize: 12, color: context.cTextDim)),
                  Expanded(
                    child: Slider(
                      value: _binauralVolume,
                      onChanged: (v) {
                        setState(() => _binauralVolume = v);
                        _binauralPlayer?.setVolume(v);
                      },
                      activeColor: C.primary,
                      inactiveColor: context.cSurfaceLight,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _pickBinaural(BinauralPreset preset) async {
    HapticFeedback.mediumImpact();
    if (_binauralPreset?.name == preset.name) {
      _binauralPlayer?.stop();
      setState(() => _binauralPreset = null);
      return;
    }
    setState(() => _binauralPreset = preset);
    _binauralPlayer ??= AudioPlayer();
    final wav = BinauralEngine.generateWav(
      baseFrequency: preset.baseFrequency,
      beatFrequency: preset.beatFrequency,
      volume: _binauralVolume,
    );
    await _binauralPlayer!.setAudioSource(BinauralAudioSource(wav));
    await _binauralPlayer!.setLoopMode(LoopMode.one);
    await _binauralPlayer!.setVolume(_binauralVolume);
    await _binauralPlayer!.play();
  }
}

// -----------------------------------------------------------------------------
// Cosmic background -- deep space nebula with reactive glow
// -----------------------------------------------------------------------------

class _CosmicBackground extends StatelessWidget {
  const _CosmicBackground({
    required this.playing,
    required this.glowAnimation,
    required this.color1,
    required this.color2,
  });

  final bool playing;
  final Animation<double> glowAnimation;
  final Color color1;
  final Color color2;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, _) {
        final t = reduceMotion ? 0.5 : glowAnimation.value;
        return RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _CosmicPainter(
              pulseT: t,
              playing: playing,
              color1: color1,
              color2: color2,
            ),
          ),
        );
      },
    );
  }
}

class _CosmicPainter extends CustomPainter {
  _CosmicPainter({
    required this.pulseT,
    required this.playing,
    required this.color1,
    required this.color2,
  });

  final double pulseT;
  final bool playing;
  final Color color1;
  final Color color2;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final breath = playing ? (0.5 + 0.5 * pulseT) : 0.3;
    final intensity = playing ? 0.12 : 0.06;

    _drawNebula(canvas, w, h,
        cx: w * 0.2, cy: h * 0.15,
        r: w * 0.7,
        color: color1.withValues(alpha: intensity * breath));

    _drawNebula(canvas, w, h,
        cx: w * 0.8, cy: h * 0.7,
        r: w * 0.6,
        color: color2.withValues(alpha: intensity * 0.8 * breath));

    _drawNebula(canvas, w, h,
        cx: w * 0.5, cy: h * 0.45,
        r: w * 0.5,
        color: Color.lerp(color1, color2, 0.5)!.withValues(alpha: intensity * 0.5 * breath));

    final centerGlowAlpha = playing ? 0.08 + 0.07 * pulseT : 0.03;
    _drawNebula(canvas, w, h,
        cx: w * 0.5, cy: h * 0.38,
        r: w * 0.35,
        color: Colors.white.withValues(alpha: centerGlowAlpha));

    if (playing) {
      final ringAlpha = 0.02 + 0.03 * pulseT;
      final ringR = w * (0.25 + 0.05 * pulseT);
      canvas.drawCircle(
        Offset(w * 0.5, h * 0.38),
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = color1.withValues(alpha: ringAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        Offset(w * 0.5, h * 0.38),
        ringR * 1.3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..color = color2.withValues(alpha: ringAlpha * 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
  }

  void _drawNebula(Canvas canvas, double w, double h,
      {required double cx, required double cy, required double r, required Color color}) {
    final center = Offset(cx, cy);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
  }

  @override
  bool shouldRepaint(covariant _CosmicPainter old) =>
      old.pulseT != pulseT || old.playing != playing ||
      old.color1 != color1 || old.color2 != color2;
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
  bool _showContent = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: Anim.dramatic)
      ..forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showContent = true;
          _displayMinutes = widget.minutes;
        });
      }
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
    final accentStyle = Theme.of(context).textTheme.displayLarge?.copyWith(color: C.accent);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final val = Curves.easeOut.transform(_ctrl.value);
        final scaleEntrance = Anim.curveGentle.transform(_ctrl.value);
        final contentScale = 0.38 + 0.62 * scaleEntrance;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14 * val, sigmaY: 14 * val),
          child: ColoredBox(
            color: C.bgDeep.withValues(alpha: 0.75 * val),
            child: Opacity(
              opacity: val,
              child: Transform.scale(
                scale: contentScale.clamp(0.0, 1.15),
                alignment: Alignment.center,
                child: child,
              ),
            ),
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_showContent) const CelebrationOverlay(),
          Material(
            color: Colors.transparent,
            child: Center(
              child: AnimatedOpacity(
                opacity: _showContent ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 800),
                curve: Anim.curveMeditative,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: S.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MIcon(MIconType.star, size: 56, color: C.gold),
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
                        style: t.bodyMedium,
                      ),
                      const SizedBox(height: S.xxl),
                      Text(
                        'Aura гордится тобой',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayMedium,
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
                          style: TextStyle(color: context.cTextSec),
                        ),
                      ),
                    ],
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
