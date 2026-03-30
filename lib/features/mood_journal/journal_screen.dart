import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/shared/models/mood_entry.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/empty_state.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/shared/widgets/shimmer_loading.dart';
import 'package:meditator/shared/widgets/sticker_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocalJournalKey = 'meditator_local_journal';

MoodEntry _entryFromDbRow(Map<String, dynamic> row) {
  return MoodEntry.fromJson({
    'id': row['id'],
    'userId': row['user_id'] ?? row['userId'],
    'primary': row['primary_emotion'] ?? row['primary'],
    'secondary': row['secondary_emotions'] ?? row['secondary'],
    'intensity': row['intensity'],
    'note': row['note'],
    'aiInsight': row['ai_insight'] ?? row['aiInsight'],
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
    setState(() { _loading = true; _error = null; });
    final uid = AuthService.instance.userId;

    if (uid != null && uid.isNotEmpty) {
      try {
        final rows = await Db.instance.getMoodEntries(uid);
        if (!mounted) return;
        setState(() {
          _entries = rows.map(_entryFromDbRow).toList();
          _loading = false;
        });
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = 'Не удалось загрузить записи';
          _loading = false;
        });
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLocalJournalKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        if (!mounted) return;
        setState(() {
          _entries = list
              .map((e) => MoodEntry.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _loading = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) setState(() { _entries = []; _loading = false; });
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
        intensity: 0.2,
        child: RefreshIndicator(
          color: C.accent,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(S.l, S.l, S.l, S.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Журнал', style: Theme.of(context).textTheme.displayMedium)
                          .animate()
                          .fadeIn(duration: Anim.normal)
                          .slideY(begin: -0.06, end: 0),
                    ],
                  ),
                ),
              ),

              if (_loading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(S.l),
                    child: Column(
                      children: List.generate(3, (i) => Padding(
                        padding: const EdgeInsets.only(bottom: S.m),
                        child: ShimmerLoading(width: double.infinity, height: 72, borderRadius: R.l, organic: true),
                      )),
                    ),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(_error!, style: TextStyle(color: context.cTextSec)),
                  ),
                )
              else ...[
                // Week row
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: S.l, vertical: S.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Неделя',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: context.cTextSec,
                              letterSpacing: 0.5,
                            )),
                        const SizedBox(height: S.m),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var i = 0; i < weekDays.length; i++)
                              _DayDot(
                                color: dominant[weekDays[i].key]?.color,
                                label: DateFormat.E('ru').format(weekDays[i].value).substring(0, 2),
                                hasEntry: dominant.containsKey(weekDays[i].key),
                              )
                                  .animate()
                                  .fadeIn(delay: (80 + i * 40).ms)
                                  .scaleXY(
                                    begin: 0.6,
                                    end: 1.0,
                                    delay: (80 + i * 40).ms,
                                    curve: Anim.curve,
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

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
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: S.l),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final entry = _entries[i];
                          return _EntryCard(
                            entry: entry,
                            index: i,
                            onDelete: () async {
                              HapticFeedback.mediumImpact();
                              final id = entry.id;
                              setState(() => _entries.removeWhere((e) => e.id == id));
                              final uid = AuthService.instance.userId;
                              if (uid != null && uid.isNotEmpty) {
                                await Db.instance.deleteMoodEntry(id);
                              }
                            },
                          );
                        },
                        childCount: _entries.length,
                      ),
                    ),
                  ),

                if (_entries.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(S.l, S.m, S.l, S.xxl),
                      child: GlassCard(
                        variant: GlassCardVariant.surface,
                        onTap: () => context.push('/journal/analytics'),
                        semanticLabel: 'Открыть аналитику настроения',
                        padding: const EdgeInsets.all(S.m),
                        child: Row(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  C.gradientPrimary.createShader(bounds),
                              child: const MIcon(MIconType.insights, size: 22, color: Colors.white),
                            ),
                            const SizedBox(width: S.m),
                            Expanded(
                              child: Text('Аналитика',
                                  style: Theme.of(context).textTheme.titleMedium),
                            ),
                            MIcon(MIconType.chevronRight, size: 20, color: context.cTextDim),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: !_loading
          ? FloatingActionButton(
              onPressed: () async {
                await context.push('/journal/new');
                _load();
              },
              backgroundColor: C.primary,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            )
              .animate()
              .fadeIn(delay: 400.ms, duration: Anim.normal)
              .scaleXY(begin: 0.8, delay: 400.ms, duration: Anim.normal, curve: Anim.curve)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.color,
    required this.label,
    required this.hasEntry,
  });

  final Color? color;
  final String label;
  final bool hasEntry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: hasEntry ? 'Есть запись' : 'Нет записи',
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasEntry
                  ? (color ?? C.primary).withValues(alpha: 0.2)
                  : context.cSurfaceLight.withValues(alpha: 0.3),
              border: hasEntry
                  ? Border.all(color: (color ?? C.primary).withValues(alpha: 0.5), width: 1.5)
                  : null,
            ),
            child: hasEntry
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color ?? C.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 9,
              color: context.cTextDim,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.index,
    required this.onDelete,
  });

  final MoodEntry entry;
  final int index;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final df = DateFormat('d MMM', 'ru');

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: C.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(R.l),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: S.l),
        child: const MIcon(MIconType.delete, size: 24, color: C.error),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showModalBottomSheet<bool>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(S.l, S.m, S.l, S.l),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Удалить запись?', style: t.titleMedium, textAlign: TextAlign.center),
                  const SizedBox(height: S.l),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Отмена'),
                        ),
                      ),
                      const SizedBox(width: S.m),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(backgroundColor: C.error),
                          child: const Text('Удалить'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: S.m),
        child: GlassCard(
          variant: GlassCardVariant.surface,
          padding: const EdgeInsets.all(S.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StickerIcon(
                icon: entry.primary.iconData,
                color: entry.primary.color,
                size: 28,
              ),
              const SizedBox(width: S.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(entry.primary.label, style: t.titleMedium),
                        const Spacer(),
                        Text(df.format(entry.createdAt), style: t.bodySmall),
                      ],
                    ),
                    if (entry.note != null && entry.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: S.xs),
                      Text(
                        entry.note!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: (60 * index).ms)
        .fadeIn(duration: Anim.normal)
        .slideX(begin: 0.03, end: 0);
  }
}
