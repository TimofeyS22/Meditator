import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/api/backend.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/shared/models/mood_entry.dart';
import 'package:meditator/shared/widgets/emotion_chip.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/shared/widgets/aura_avatar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || _primary == null) return;

    setState(() => _saving = true);
    final id = const Uuid().v4();
    final now = DateTime.now();
    final entry = MoodEntry(
      id: id,
      userId: uid,
      primary: _primary!,
      secondary: _secondary.toList(),
      intensity: _intensity.round().clamp(1, 5),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      createdAt: now,
    );

    try {
      await Db.instance.insertMoodEntry({
        'id': id,
        'user_id': uid,
        'primary': _primary!.name,
        'secondary': _secondary.map((e) => e.name).toList(),
        'intensity': entry.intensity,
        'note': entry.note,
        'created_at': now.toIso8601String(),
      });

      final rows = await Db.instance.getMoodEntries(uid, limit: 40);
      final entriesMaps = rows.map((r) {
        return {
          'primary': r['primary'],
          'intensity': r['intensity'] ?? 3,
          'secondary': r['secondary'] ?? [],
          'note': r['note'],
          'created_at': r['created_at'] ?? r['createdAt'],
        };
      }).toList();

      final analysis = await Backend.instance.analyzeMood(
        entries: entriesMaps,
        userGoals: const [],
      );
      final insight = _extractInsight(analysis);
      if (insight.isNotEmpty) {
        await Db.instance.updateMoodInsight(id, insight);
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
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: const AuraAvatar(size: 36),
                          ),
                          const SizedBox(width: S.s),
                          Text('Aura',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: C.text)),
                        ],
                      ),
                      const SizedBox(height: S.m),
                      Text(
                        insight.isNotEmpty
                            ? insight
                            : 'Спасибо, что поделился. Это уже забота о себе.',
                        style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                              color: C.textSec,
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
          const SnackBar(
              content:
                  Text('Не удалось сохранить. Проверь сеть и попробуй снова.')),
        );
      }
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
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: C.text),
                        tooltip: 'Назад',
                        onPressed: _back,
                      ),
                      Expanded(
                        child: Text(
                          'Новая запись',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: C.text),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Step progress
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: S.m),
                  child: Semantics(
                    label: 'Шаг ${_step + 1} из 4',
                    child: Row(
                      children: List.generate(4, (i) {
                        final active = i <= _step;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(R.full),
                                gradient: active ? C.gradientPrimary : null,
                                color: active ? null : C.surfaceLight,
                              ),
                            ),
                          ),
                        );
                      }),
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
                                child: const Text('Пропустить',
                                    style: TextStyle(color: C.textSec)),
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
                      emoji: e.emoji,
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
                      ?.copyWith(color: C.textDim)),
              const SizedBox(height: S.m),
              Wrap(
                spacing: S.s,
                runSpacing: S.s,
                children: [
                  for (final e in Emotion.values)
                    if (e != _primary)
                      EmotionChip(
                        emoji: e.emoji,
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
                        padding: const EdgeInsets.symmetric(horizontal: S.s),
                        child: SizedBox(
                          width: 36,
                          height: 36,
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
                            .bodySmall
                            ?.copyWith(color: C.textDim)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: S.xl),
                    child: Text('Очень сильно',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: C.textDim)),
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
                      ?.copyWith(color: C.textDim)),
              const SizedBox(height: S.m),
              AnimatedContainer(
                duration: Anim.fast,
                curve: Anim.curve,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(R.m + 2),
                  gradient: _noteFocused ? C.gradientPrimary : null,
                ),
                padding: const EdgeInsets.all(1.5),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: C.surfaceLight,
                    borderRadius: BorderRadius.circular(R.m),
                  ),
                  child: TextField(
                    controller: _note,
                    focusNode: _noteFocus,
                    minLines: 5,
                    maxLines: null,
                    style: const TextStyle(color: C.text),
                    decoration: InputDecoration(
                      hintText: 'Что было на душе...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      hintStyle: const TextStyle(color: C.textDim),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}
