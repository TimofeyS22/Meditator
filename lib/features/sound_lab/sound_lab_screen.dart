import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/api/backend.dart';
import 'package:meditator/features/sound_lab/binaural_engine.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';

class SoundLabScreen extends StatefulWidget {
  const SoundLabScreen({super.key});

  @override
  State<SoundLabScreen> createState() => _SoundLabScreenState();
}

class _SoundLabScreenState extends State<SoundLabScreen>
    with TickerProviderStateMixin {
  final AudioPlayer _binauralPlayer = AudioPlayer();
  final Map<String, AudioPlayer> _ambientPlayers = {};
  final Map<String, double> _ambientVolumes = {};

  BinauralPreset? _activePreset;
  double _binauralVolume = 0.3;
  bool _playing = false;
  String _selectedCategory = 'meditation';
  String? _aiRecommendation;
  bool _loadingAi = false;

  late final AnimationController _pulseCtrl;

  static const _ambientSounds = {
    'Дождь': 'https://assets.mixkit.co/sfx/preview/mixkit-light-rain-loop-2395.mp3',
    'Океан': 'https://assets.mixkit.co/sfx/preview/mixkit-sea-waves-loop-1186.mp3',
    'Лес': 'https://assets.mixkit.co/sfx/preview/mixkit-forest-birds-loop-1224.mp3',
    'Костёр': 'https://assets.mixkit.co/sfx/preview/mixkit-campfire-crackling-loop-1710.mp3',
  };

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _binauralPlayer.setLoopMode(LoopMode.one);
    for (final name in _ambientSounds.keys) {
      _ambientVolumes[name] = 0.0;
    }
  }

  @override
  void dispose() {
    _binauralPlayer.dispose();
    for (final p in _ambientPlayers.values) {
      p.dispose();
    }
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectPreset(BinauralPreset preset) async {
    HapticFeedback.mediumImpact();
    setState(() => _activePreset = preset);

    final wav = BinauralEngine.generateWav(
      baseFrequency: preset.baseFrequency,
      beatFrequency: preset.beatFrequency,
      volume: _binauralVolume,
    );

    await _binauralPlayer.setAudioSource(BinauralAudioSource(wav));

    if (_playing) {
      await _binauralPlayer.play();
    }
  }

  Future<void> _togglePlay() async {
    HapticFeedback.mediumImpact();
    if (_activePreset == null) return;

    if (_playing) {
      await _binauralPlayer.pause();
      for (final p in _ambientPlayers.values) {
        await p.pause();
      }
      _pulseCtrl.stop();
    } else {
      if (!_binauralPlayer.playing) {
        if (_binauralPlayer.audioSource == null) {
          await _selectPreset(_activePreset!);
        }
        await _binauralPlayer.play();
      }
      for (final entry in _ambientPlayers.entries) {
        if ((_ambientVolumes[entry.key] ?? 0) > 0) {
          await entry.value.play();
        }
      }
      _pulseCtrl.repeat(reverse: true);
    }

    setState(() => _playing = !_playing);
  }

  Future<void> _setAmbientVolume(String name, double volume) async {
    setState(() => _ambientVolumes[name] = volume);

    if (!_ambientPlayers.containsKey(name)) {
      final player = AudioPlayer();
      await player.setUrl(_ambientSounds[name]!);
      await player.setLoopMode(LoopMode.one);
      _ambientPlayers[name] = player;
    }

    final player = _ambientPlayers[name]!;
    await player.setVolume(volume);

    if (volume > 0 && _playing && !player.playing) {
      await player.play();
    } else if (volume == 0 && player.playing) {
      await player.pause();
    }
  }

  Future<void> _setBinauralVolume(double v) async {
    setState(() => _binauralVolume = v);
    await _binauralPlayer.setVolume(v);
  }

  Future<void> _getAiRecommendation() async {
    if (_loadingAi) return;
    HapticFeedback.lightImpact();
    setState(() {
      _loadingAi = true;
      _aiRecommendation = null;
    });

    try {
      final resp = await Backend.instance.chat(
        messages: [
          {
            'role': 'user',
            'content': 'Порекомендуй мне бинауральные частоты и ambient звуки для текущего момента. '
                'Доступные пресеты: ${binauralPresets.map((p) => "${p.name} (${p.beatFrequency}Hz)").join(", ")}. '
                'Ambient: Дождь, Океан, Лес, Костёр. '
                'Ответь кратко, 2-3 предложения.',
          },
        ],
      );
      if (mounted) {
        setState(() {
          _aiRecommendation = resp.reply;
          _loadingAi = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _aiRecommendation = 'Не удалось получить рекомендацию';
          _loadingAi = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final presets = binauralPresets.where((p) => p.category == _selectedCategory).toList();

    return Scaffold(
      body: GradientBg(
        showStars: true,
        intensity: 0.4,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: S.s, vertical: S.xs),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.pop();
                      },
                      icon: MIcon(MIconType.arrowBack, size: 22, color: context.cText),
                    ),
                    const SizedBox(width: S.xs),
                    Expanded(child: Text('Звуковая лаборатория', style: t.titleLarge)),
                    IconButton(
                      onPressed: _getAiRecommendation,
                      icon: const MIcon(MIconType.star, size: 22, color: C.accent),
                      tooltip: 'AI рекомендация',
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: S.m),
                  children: [
                    if (_aiRecommendation != null) ...[
                      GlassCard(
                        showBorder: true,
                        showGlow: true,
                        glowColor: C.glowAccent,
                        padding: const EdgeInsets.all(S.m),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const MIcon(MIconType.star, size: 20, color: C.accent),
                            const SizedBox(width: S.s),
                            Expanded(
                              child: Text(
                                _aiRecommendation!,
                                style: t.bodyMedium?.copyWith(color: context.cText),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms),
                      const SizedBox(height: S.m),
                    ],
                    if (_loadingAi)
                      const Padding(
                        padding: EdgeInsets.only(bottom: S.m),
                        child: Center(child: CircularProgressIndicator(color: C.accent, strokeWidth: 2)),
                      ),

                    _CategorySelector(
                      selected: _selectedCategory,
                      onChanged: (c) => setState(() => _selectedCategory = c),
                    ),
                    const SizedBox(height: S.m),

                    Text('Бинауральные частоты', style: t.titleMedium),
                    const SizedBox(height: S.s),
                    ...presets.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: S.s),
                          child: _PresetTile(
                            preset: p,
                            active: _activePreset == p,
                            onTap: () => _selectPreset(p),
                          ),
                        )),

                    const SizedBox(height: S.m),
                    if (_activePreset != null) ...[
                      Text('Громкость бинауральных', style: t.labelLarge?.copyWith(color: context.cTextSec)),
                      Slider(
                        value: _binauralVolume,
                        onChanged: _setBinauralVolume,
                        activeColor: C.primary,
                        inactiveColor: context.cSurfaceLight,
                      ),
                    ],

                    const SizedBox(height: S.m),
                    Text('Ambient слои', style: t.titleMedium),
                    const SizedBox(height: S.s),
                    ..._ambientSounds.keys.map((name) => _AmbientSlider(
                          name: name,
                          volume: _ambientVolumes[name] ?? 0,
                          onChanged: (v) => _setAmbientVolume(name, v),
                        )),

                    const SizedBox(height: S.xl),
                  ],
                ),
              ),
              _PlayControl(
                playing: _playing,
                hasPreset: _activePreset != null,
                presetName: _activePreset?.name,
                pulseCtrl: _pulseCtrl,
                onToggle: _togglePlay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const cats = [
      ('sleep', 'Сон', MIconType.moon),
      ('meditation', 'Медитация', MIconType.meditation),
      ('focus', 'Фокус', MIconType.star),
    ];
    return Row(
      children: cats.map((c) {
        final active = selected == c.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GlassCard(
              onTap: () => onChanged(c.$1),
              showBorder: active,
              opacity: active ? 0.15 : 0.06,
              padding: const EdgeInsets.symmetric(vertical: S.s, horizontal: S.xs),
              child: Column(
                children: [
                  MIcon(c.$3, size: 20, color: active ? C.accent : context.cTextDim),
                  const SizedBox(height: 4),
                  Text(
                    c.$2,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: active ? context.cText : context.cTextDim,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.preset, required this.active, required this.onTap});
  final BinauralPreset preset;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      onTap: onTap,
      showBorder: active,
      showGlow: active,
      glowColor: C.glowPrimary,
      opacity: active ? 0.15 : 0.08,
      padding: const EdgeInsets.all(S.m),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: active ? C.gradientPrimary : null,
              color: active ? null : context.cSurfaceLight,
            ),
            child: Center(
              child: Text(
                '${preset.beatFrequency.toStringAsFixed(0)}Hz',
                style: t.labelSmall?.copyWith(
                  color: active ? Colors.white : context.cTextDim,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: S.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(preset.name, style: t.titleSmall),
                Text(preset.description, style: t.bodySmall?.copyWith(color: context.cTextSec)),
              ],
            ),
          ),
          if (active) const MIcon(MIconType.check, size: 20, color: C.accent),
        ],
      ),
    );
  }
}

class _AmbientSlider extends StatelessWidget {
  const _AmbientSlider({required this.name, required this.volume, required this.onChanged});
  final String name;
  final double volume;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: S.xs),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(name, style: t.bodySmall?.copyWith(color: context.cTextSec)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: volume > 0 ? C.accent : context.cSurfaceLight,
                inactiveTrackColor: context.cSurfaceLight,
                thumbColor: C.accent,
                overlayColor: C.accent.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: volume,
                onChanged: onChanged,
                min: 0,
                max: 1,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${(volume * 100).round()}%',
              style: t.labelSmall,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayControl extends StatelessWidget {
  const _PlayControl({
    required this.playing,
    required this.hasPreset,
    required this.presetName,
    required this.pulseCtrl,
    required this.onToggle,
  });
  final bool playing;
  final bool hasPreset;
  final String? presetName;
  final AnimationController pulseCtrl;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(S.m, S.s, S.m, S.m),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.cSurfaceBorder, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playing ? 'Воспроизводится' : (hasPreset ? 'Готово' : 'Выберите пресет'),
                    style: t.labelSmall,
                  ),
                  if (presetName != null)
                    Text(presetName!, style: t.titleSmall),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: pulseCtrl,
              builder: (ctx, child) => Transform.scale(
                scale: playing ? 1.0 + 0.05 * pulseCtrl.value : 1.0,
                child: child,
              ),
              child: GestureDetector(
                onTap: hasPreset ? onToggle : null,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasPreset ? C.gradientPrimary : null,
                    color: hasPreset ? null : context.cSurfaceLight,
                    boxShadow: playing
                        ? [BoxShadow(color: C.glowPrimary, blurRadius: 20, spreadRadius: 2)]
                        : null,
                  ),
                  child: Center(
                    child: MIcon(
                      playing ? MIconType.close : MIconType.meditation,
                      size: 24,
                      color: hasPreset ? Colors.white : context.cTextDim,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
