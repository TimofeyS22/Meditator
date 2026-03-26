import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/shared/models/mood_entry.dart';
import 'package:meditator/shared/utils/accessibility.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/empty_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

MoodEntry _entryFromDbRow(Map<String, dynamic> row) {
  return MoodEntry.fromJson({
    'id': row['id'],
    'userId': row['user_id'] ?? row['userId'],
    'primary': row['primary'],
    'secondary': row['secondary'],
    'intensity': row['intensity'],
    'note': row['note'],
    'aiInsight': row['ai_insight'] ?? row['insight'] ?? row['aiInsight'],
    'createdAt': row['created_at'] ?? row['createdAt'],
  });
}

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<MoodEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _loading = false;
        _entries = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Db.instance.getMoodEntries(uid);
      if (!mounted) return;
      setState(() {
        _entries = rows.map(_entryFromDbRow).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить записи';
      });
    }
  }

  Map<String, Emotion> _dominantByDay() {
    final now = DateTime.now();
    final map = <String, Emotion>{};
    for (var d = 0; d < 7; d++) {
      final day =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - d));
      final key = _dayKey(day);
      MoodEntry? pick;
      for (final e in _entries) {
        if (_dayKey(e.createdAt) != key) continue;
        if (pick == null || e.createdAt.isAfter(pick.createdAt)) pick = e;
      }
      if (pick != null) map[key] = pick.primary;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    final df = DateFormat('d MMM', 'ru');
    final dominant = _dominantByDay();
    final now = DateTime.now();
    final weekDays = List.generate(7, (d) {
      final day =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - d));
      return MapEntry(_dayKey(day), day);
    });

    return Scaffold(
      body: GradientBg(
        showStars: true,
        intensity: 0.3,
        child: RefreshIndicator(
          color: C.accent,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(S.m, S.l, S.m, S.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Журнал',
                              style: Theme.of(context).textTheme.displayMedium)
                          .animate()
                          .fadeIn(duration: Anim.normal)
                          .slideY(begin: -0.08, end: 0),
                      const SizedBox(height: S.m),
                      SizedBox(
                        width: double.infinity,
                        child: GlassCard(
                          showBorder: true,
                          onTap: () => context.push('/journal/new'),
                          semanticLabel: 'Создать новую запись в журнале',
                          padding: const EdgeInsets.symmetric(
                              vertical: S.m, horizontal: S.l),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Как ты?',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: C.text)),
                              const SizedBox(width: S.s),
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    C.gradientPrimary.createShader(bounds),
                                child: const MIcon(MIconType.add,
                                    size: 26, color: Colors.white),
                              )
                                  .animate(
                                      onPlay: reduceMotion
                                          ? null
                                          : (c) => c.repeat())
                                  .shimmer(
                                      delay: 2000.ms,
                                      duration: 1200.ms,
                                      color: Colors.white24),
                            ],
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 80.ms)
                          .slideY(begin: 0.05, end: 0),
                    ],
                  ),
                ),
              ),

              // --- Loading / Error ---
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                      child: CircularProgressIndicator(color: C.primary)),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child:
                        Text(_error!, style: const TextStyle(color: C.textSec)),
                  ),
                )
              else ...[
                // --- Week row ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: S.m, vertical: S.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Неделя',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: C.textSec)),
                        const SizedBox(height: S.s),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var i = 0; i < weekDays.length; i++)
                              _DayCircle(
                                emoji: dominant[weekDays[i].key]?.emoji ?? '?',
                                color: dominant[weekDays[i].key]?.color ??
                                    C.surfaceLight,
                                label: df.format(weekDays[i].value),
                                hasEntry:
                                    dominant.containsKey(weekDays[i].key),
                              )
                                  .animate()
                                  .fadeIn(delay: (100 + i * 40).ms)
                                  .scale(
                                    begin: const Offset(0.8, 0.8),
                                    end: const Offset(1, 1),
                                    delay: (100 + i * 40).ms,
                                    curve: Curves.easeOutBack,
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Empty state ---
                if (_entries.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(S.xl),
                      child: EmptyState(
                        type: EmptyStateType.journal,
                        title: 'Начни вести дневник',
                        subtitle: 'Aura найдёт паттерны в твоих эмоциях',
                        actionLabel: 'Новая запись',
                        onAction: () => context.push('/journal/new'),
                      ).animate().fadeIn(duration: Anim.slow),
                    ),
                  )
                else
                  // --- Entry cards ---
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: S.m),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final entry = _entries[i];
                          return Dismissible(
                            key: ValueKey(entry.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              decoration: BoxDecoration(
                                color: C.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(R.l),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: S.l),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: C.error,
                                size: 28,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              final confirmed =
                                  await showModalBottomSheet<bool>(
                                context: context,
                                builder: (sheetContext) {
                                  return SafeArea(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          S.l, S.m, S.l, S.l),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            'Удалить запись?',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(color: C.text),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: S.l),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          sheetContext, false),
                                                  child: const Text('Отмена'),
                                                ),
                                              ),
                                              const SizedBox(width: S.m),
                                              Expanded(
                                                child: FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          sheetContext, true),
                                                  style: FilledButton
                                                      .styleFrom(
                                                    backgroundColor: C.error,
                                                  ),
                                                  child: const Text('Удалить'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                              if (confirmed == true) {
                                HapticFeedback.mediumImpact();
                              }
                              return confirmed ?? false;
                            },
                            onDismissed: (_) {
                              setState(() {
                                _entries.removeWhere((e) => e.id == entry.id);
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: S.m),
                              child: GlassCard(
                                showBorder: true,
                                padding: EdgeInsets.zero,
                                child: IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 3,
                                        color: entry.primary.color,
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(S.m),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(entry.primary.emoji,
                                                  style: const TextStyle(
                                                      fontSize: 28)),
                                              const SizedBox(width: S.m),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          entry.primary.label,
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .titleSmall
                                                              ?.copyWith(
                                                                  color:
                                                                      C.text),
                                                        ),
                                                        const Spacer(),
                                                        Text(
                                                          df.format(entry
                                                              .createdAt),
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                  color: C
                                                                      .textDim),
                                                        ),
                                                      ],
                                                    ),
                                                    if (entry.note != null &&
                                                        entry.note!
                                                            .trim()
                                                            .isNotEmpty) ...[
                                                      const SizedBox(
                                                          height: S.xs),
                                                      Text(
                                                        entry.note!.trim(),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: Theme.of(
                                                                context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                                color: C
                                                                    .textSec),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                              .animate(delay: (40 * i).ms)
                              .fadeIn(duration: Anim.normal)
                              .slideX(begin: 0.03, end: 0);
                        },
                        childCount: _entries.length,
                      ),
                    ),
                  ),

                // --- Analytics card ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(S.m, S.m, S.m, S.xxl),
                    child: GlassCard(
                      showBorder: true,
                      onTap: () => context.push('/journal/analytics'),
                      semanticLabel: 'Открыть аналитику настроения',
                      padding: const EdgeInsets.all(S.m),
                      child: Row(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                C.gradientPrimary.createShader(bounds),
                            child: const MIcon(MIconType.insights,
                                size: 24, color: Colors.white),
                          ),
                          const SizedBox(width: S.m),
                          Expanded(
                            child: Text('Аналитика',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: C.text)),
                          ),
                          const MIcon(MIconType.chevronRight,
                              size: 24, color: C.textDim),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCircle extends StatelessWidget {
  const _DayCircle({
    required this.emoji,
    required this.color,
    required this.label,
    required this.hasEntry,
  });

  final String emoji;
  final Color color;
  final String label;
  final bool hasEntry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: hasEntry ? 'Есть запись за $label' : 'Нет записи за $label',
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: hasEntry
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.25),
                        color.withValues(alpha: 0.08),
                      ],
                    )
                  : null,
              color: hasEntry ? null : C.surface,
              border: Border.all(
                color: hasEntry
                    ? color.withValues(alpha: 0.6)
                    : C.surfaceLight.withValues(alpha: 0.4),
                width: hasEntry ? 2 : 1,
              ),
              boxShadow: hasEntry
                  ? [
                      BoxShadow(
                          color: color.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: -2)
                    ]
                  : null,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 44,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: C.textDim,
                    fontSize: 10,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
