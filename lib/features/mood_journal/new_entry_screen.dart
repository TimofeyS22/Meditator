import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/api/api_service.dart';
import 'package:meditator/core/api/backend.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/shared/models/mood_entry.dart';
import 'package:meditator/shared/widgets/emotion_chip.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/shared/widgets/aura_avatar.dart';
import 'package:meditator/shared/widgets/voice_recorder.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kLocalJournalKey = 'meditator_local_journal';

class NewEntryScreen extends StatefulWidget {
  const NewEntryScreen({super.key});

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  int _step = 0;
  Emotion? _primary;
  final Set<Emotion> _secondary = {};
  double _intensity = 3;
  final _note = TextEditingController();
  final _noteFocus = FocusNode();
  bool _saving = false;
  bool _noteFocused = false;
  bool _voiceInputActive = false;
  bool _transcribingVoice = false;

  @override
  void initState() {
    super.initState();
    _noteFocus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted) setState(() => _noteFocused = _noteFocus.hasFocus);
  }

  @override
  void dispose() {
    _noteFocus.removeListener(_onFocusChanged);
    _noteFocus.dispose();
    _note.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0 && _primary == null) return;
    setState(() => _step = (_step + 1).clamp(0, 3));
  }

  void _back() {
    if (_step == 0) {
      context.pop();
      return;
    }
    setState(() => _step -= 1);
  }

  Future<void> _save() async {
    if (_primary == null) return;

    setState(() => _saving = true);
    final uid = AuthService.instance.userId;
    final id = const Uuid().v4();
    final now = DateTime.now();
    final entry = MoodEntry(
      id: id,
      userId: uid ?? 'local',
      primary: _primary!,
      secondary: _secondary.toList(),
      intensity: _intensity.round().clamp(1, 5),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      createdAt: now,
    );

    String insight = '';

    try {
      if (uid != null && uid.isNotEmpty) {
        await Db.instance.insertMoodEntry({
          'id': id,
          'user_id': uid,
          'primary_emotion': _primary!.name,
          'secondary_emotions': _secondary.map((e) => e.name).toList(),
          'intensity': entry.intensity,
          'note': entry.note,
          'created_at': now.toIso8601String(),
        });

        try {
          final rows = await Db.instance.getMoodEntries(uid, limit: 40);
          final entriesMaps = rows.map((r) => {
            'primary_emotion': r['primary_emotion'],
            'intensity': r['intensity'] ?? 3,
            'note': r['note'],
            'created_at': r['created_at'] ?? r['createdAt'],
          }).toList();
          final analysis = await Backend.instance.analyzeMood(
            entries: entriesMaps, userGoals: const [],
          );
          insight = _extractInsight(analysis);
          if (insight.isNotEmpty) {
            await Db.instance.updateMoodInsight(id, insight);
          }
        } catch (_) {}
      } else {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_kLocalJournalKey);
        final list = raw != null && raw.isNotEmpty
            ? (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];
        list.insert(0, entry.toJson());
        await prefs.setString(_kLocalJournalKey, jsonEncode(list));
      }

      if (!mounted) return;
      setState(() => _saving = false);

      await showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: S.l),
              child: Material(
                type: MaterialType.transparency,
                child: GlassCard(
                  showBorder: true,
                  showGlow: true,
                  glowColor: C.glowPrimary,
                  padding: const EdgeInsets.all(S.l),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 36,
                            height: 36,
                            child: AuraAvatar(size: 36),
                          ),
                          const SizedBox(width: S.s),
                          Text('Aura',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleMedium),
                        ],
                      ),
                      const SizedBox(height: S.m),
                      Text(
                        insight.isNotEmpty
                            ? insight
                            : 'Спасибо, что поделился. Это уже забота о себе.',
                        style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                              height: 1.5,
                            ),
                      ),
                      const SizedBox(height: S.l),
                      SizedBox(
                        width: double.infinity,
                        child: GlowButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Понятно'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить')),
        );
      }
    }
  }

  String? _transcriptionFromResponse(Map<String, dynamic>? m) {
    if (m == null) return null;
    for (final key in ['text', 'transcription', 'transcript', 'message']) {
      final v = m[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    final data = m['data'];
    if (data is Map) {
      final dm = Map<String, dynamic>.from(data);
      for (final key in ['text', 'transcription', 'transcript']) {
        final v = dm[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }
    return null;
  }

  Future<void> _showVoiceRecorderSheet() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.cSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: VoiceRecorder(
          onRecordingComplete: (path) {
            Navigator.of(ctx).pop();
            _applyVoiceTranscription(path);
          },
          onCancel: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  Future<void> _applyVoiceTranscription(String filePath) async {
    if (!mounted) return;
    setState(() => _transcribingVoice = true);
    final map = await ApiService.instance.transcribeAudio(filePath);
    final text = _transcriptionFromResponse(map);
    if (!mounted) return;
    setState(() => _transcribingVoice = false);
    if (text != null && text.isNotEmpty) {
      setState(() {
        _note.text = text;
        _voiceInputActive = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось распознать речь')),
      );
    }
  }

  String _extractInsight(Map<String, dynamic> m) {
    final msg = m['message'] as String?;
    if (msg != null && msg.trim().isNotEmpty) return msg.trim();
    final ins = m['insight'] as String?;
    if (ins != null && ins.trim().isNotEmpty) return ins.trim();
    final list = m['insights'];
    if (list is List && list.isNotEmpty) {
      return list.map((e) => e.toString()).where((s) => s.isNotEmpty).join('\n');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBg(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ambient color wash matching selected emotion
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: Anim.slow,
                  child: _primary != null
                      ? Container(
                          key: ValueKey(_primary),
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0, -0.3),
                              radius: 1.2,
                              colors: [
                                _primary!.color.withValues(alpha: 0.1),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(S.s, S.s, S.m, S.s),
                  child: Row(
                    children: [
                      IconButton(
                        icon: MIcon(MIconType.arrowBack,
                            size: 24, color: context.cText),
                        tooltip: 'Назад',
                        onPressed: _back,
                      ),
                      Expanded(
                        child: Text(
                          'Новая запись',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Step progress — unified gradient bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: S.m),
                  child: Semantics(
                    label: 'Шаг ${_step + 1} из 4',
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final totalWidth = constraints.maxWidth;
                        final progress = (_step + 1) / 4;
                        return Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.cSurfaceLight,
                            borderRadius: BorderRadius.circular(R.full),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              curve: Anim.curve,
                              width: totalWidth * progress,
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(R.full),
                                gradient: C.gradientPrimary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: S.m),

                // Step content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) {
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: _buildStep(context),
                    ),
                  ),
                ),

                // Bottom buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(S.m, S.m, S.m, S.l),
                  child: _step < 3
                      ? Row(
                          children: [
                            if (_step == 1)
                              TextButton(
                                onPressed: _next,
                                child: Text('Пропустить',
                                    style: TextStyle(color: context.cTextSec)),
                              ),
                            const Spacer(),
                            GlowButton(
                              onPressed:
                                  _step == 0 && _primary == null ? null : _next,
                              semanticLabel: 'Перейти к следующему шагу',
                              child: const Text('Дальше'),
                            ),
                          ],
                        )
                      : GlowButton(
                          onPressed: _saving ? null : _save,
                          isLoading: _saving,
                          width: double.infinity,
                          semanticLabel: 'Сохранить запись в журнал',
                          child: const Text('Сохранить'),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: S.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Что ты\nчувствуешь?',
                      style: Theme.of(context).textTheme.displayMedium)
                  .animate()
                  .fadeIn(),
              const SizedBox(height: S.l),
              Wrap(
                spacing: S.s,
                runSpacing: S.s,
                children: [
                  for (final e in Emotion.values)
                    EmotionChip(
                      iconData: e.iconData,
                      iconColor: e.color,
                      label: e.label,
                      color: e.color,
                      isSelected: _primary == e,
                      onTap: () => setState(() => _primary = e),
                    ),
                ],
              ),
            ],
          ),
        );

      case 1:
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: S.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Что ещё?',
                      style: Theme.of(context).textTheme.headlineMedium)
                  .animate()
                  .fadeIn(),
              const SizedBox(height: S.s),
              Text('Можно выбрать несколько или пропустить',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: context.cTextDim)),
              const SizedBox(height: S.m),
              Wrap(
                spacing: S.s,
                runSpacing: S.s,
                children: [
                  for (final e in Emotion.values)
                    if (e != _primary)
                      EmotionChip(
                        iconData: e.iconData,
                        iconColor: e.color,
                        label: e.label,
                        color: e.color,
                        isSelected: _secondary.contains(e),
                        onTap: () => setState(() {
                          if (_secondary.contains(e)) {
                            _secondary.remove(e);
                          } else {
                            _secondary.add(e);
                          }
                        }),
                      ),
                ],
              ),
            ],
          ),
        );

      case 2:
        final emotionColor = _primary?.color ?? C.primary;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Насколько сильно?',
                      style: Theme.of(context).textTheme.headlineMedium)
                  .animate()
                  .fadeIn(),
              const SizedBox(height: S.xxl),
              Center(
                child: Text(
                  '${_intensity.round()}',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: emotionColor,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(height: S.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final level = i + 1;
                  final filled = level <= _intensity.round();
                  return Semantics(
                    button: true,
                    selected: filled,
                    label: 'Интенсивность $level из 5',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _intensity = level.toDouble());
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: S.xs),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: AnimatedContainer(
                              duration: Anim.fast,
                              curve: Anim.curve,
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    filled ? emotionColor : Colors.transparent,
                                border: Border.all(
                                  color: filled
                                      ? emotionColor
                                      : emotionColor.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                                boxShadow: filled
                                    ? [
                                        BoxShadow(
                                          color: emotionColor.withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          spreadRadius: -2,
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: S.m),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: S.xl),
                    child: Text('Легко',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: S.xl),
                    child: Text('Очень сильно',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall),
                  ),
                ],
              ),
            ],
          ),
        );

      default:
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: S.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Что произошло?',
                      style: Theme.of(context).textTheme.headlineMedium)
                  .animate()
                  .fadeIn(),
              const SizedBox(height: S.s),
              Text('По желанию — пара слов для контекста',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: context.cTextDim)),
              const SizedBox(height: S.m),
              if (_voiceInputActive)
                Padding(
                  padding: const EdgeInsets.only(bottom: S.s),
                  child: Row(
                    children: [
                      const MIcon(MIconType.mic, size: 16, color: C.accent),
                      const SizedBox(width: S.xs),
                      Text(
                        'Голосовой ввод',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: C.accent,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: Anim.fast,
                      curve: Anim.curve,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(R.xl + 2),
                        gradient: _noteFocused ? C.gradientPrimary : null,
                      ),
                      padding: const EdgeInsets.all(1.5),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.cSurfaceLight,
                          borderRadius: BorderRadius.circular(R.xl),
                        ),
                        child: TextField(
                          controller: _note,
                          focusNode: _noteFocus,
                          minLines: 5,
                          maxLines: null,
                          style: TextStyle(color: context.cText),
                          onChanged: (_) {
                            if (_voiceInputActive) {
                              setState(() => _voiceInputActive = false);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Что было на душе...',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            hintStyle: TextStyle(color: context.cTextDim),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: S.xs),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _transcribingVoice
                        ? const SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: C.accent,
                                ),
                              ),
                            ),
                          )
                        : IconButton(
                            tooltip: 'Голосовой ввод',
                            onPressed: _saving ? null : _showVoiceRecorderSheet,
                            icon: const MIcon(
                              MIconType.mic,
                              size: 24,
                              color: C.accent,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }
}
