import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/api/backend.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/shared/models/mood_entry.dart';
import 'package:meditator/shared/widgets/animated_number.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/shared/widgets/aura_avatar.dart';
import 'package:meditator/shared/widgets/progress_arc.dart';
import 'package:meditator/shared/widgets/sticker_icon.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';

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

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<MoodEntry> _entries30 = [];
  List<String> _auraPatterns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = AuthService.instance.userId;
    if (uid == null) {
      setState(() {
        _loading = false;
        _entries30 = [];
        _auraPatterns = [];
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await Db.instance.getMoodEntries(uid, limit: 200);
      final all = rows.map(_entryFromDbRow).toList();
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final filtered = all.where((e) => e.createdAt.isAfter(cutoff)).toList();

      final maps = filtered
          .map((e) => {
                'primary_emotion': e.primary.name,
                'intensity': e.intensity,
                'note': e.note,
                'created_at': e.createdAt.toIso8601String(),
              })
          .toList();

      var patterns = <String>[];
      if (maps.isNotEmpty) {
        try {
          final res = await Backend.instance.analyzeMood(
            entries: maps,
            userGoals: const [],
          );
          patterns = _patternsFromResponse(res);
        } catch (_) {
          patterns = [];
        }
      }

      if (!mounted) return;
      setState(() {
        _entries30 = filtered;
        _auraPatterns = patterns;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _patternsFromResponse(Map<String, dynamic> m) {
    final p = m['patterns'];
    if (p is List) {
      return p
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    final ins = m['insights'];
    if (ins is List) {
      return ins
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    final single = m['insight'] as String? ?? m['message'] as String?;
    if (single != null && single.trim().isNotEmpty) return [single.trim()];
    return [];
  }

  Map<Emotion, int> _counts() {
    final c = <Emotion, int>{};
    for (final e in _entries30) {
      c[e.primary] = (c[e.primary] ?? 0) + 1;
    }
    return c;
  }

  List<MapEntry<Emotion, int>> _top6() {
    final list = _counts().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(6).toList();
  }

  double _positiveRatio() {
    if (_entries30.isEmpty) return 0.5;
    var pos = 0;
    for (final e in _entries30) {
      if (e.primary.isPositive) pos++;
    }
    return pos / _entries30.length;
  }

  Map<String, Emotion?> _weekDominant() {
    final now = DateTime.now();
    final map = <String, Emotion?>{};
    for (var d = 0; d < 7; d++) {
      final day =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - d));
      final key = _dayKey(day);
      MoodEntry? pick;
      for (final e in _entries30) {
        if (_dayKey(e.createdAt) != key) continue;
        if (pick == null || e.createdAt.isAfter(pick.createdAt)) pick = e;
      }
      map[key] = pick?.primary;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final top = _top6();
    final maxC = top.isEmpty ? 1 : top.map((e) => e.value).reduce(math.max);
    final ratio = _positiveRatio();
    final week = _weekDominant();
    final now = DateTime.now();
    final weekKeys = List.generate(7, (d) {
      final day =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - d));
      return _dayKey(day);
    });

    return Scaffold(
      body: GradientBg(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: C.primary))
            : CustomScrollView(
                slivers: [
                  // --- Header ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(S.s, S.s, S.m, S.m),
                      child: Row(
                        children: [
                          IconButton(
                            icon: MIcon(MIconType.arrowBack,
                                size: 24, color: context.cText),
                            tooltip: 'Назад',
                            onPressed: () => context.pop(),
                          ),
                          Expanded(
                            child: Text(
                              'Аналитика',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .displayMedium,
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: S.m),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // --- Bar chart ---
                        Text('Частота эмоций (30 дней)',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(color: context.cTextSec))
                            .animate()
                            .fadeIn(),
                        const SizedBox(height: S.s),
                        if (top.isEmpty)
                          GlassCard(
                            showBorder: true,
                            padding: const EdgeInsets.all(S.l),
                            child: Text(
                              'Пока мало данных — отмечай настроение чаще',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: context.cTextDim),
                            ),
                          )
                        else
                          GlassCard(
                            showBorder: true,
                            padding: const EdgeInsets.all(S.m),
                            child: Column(
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: Anim.dramatic,
                                  curve: Anim.curve,
                                  builder: (context, progress, _) => SizedBox(
                                    height: 112,
                                    width: double.infinity,
                                    child: CustomPaint(
                                      painter: _EmotionBarsPainter(
                                        entries: top,
                                        maxCount: maxC,
                                        progress: progress,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: S.s),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final e in top)
                                      Expanded(
                                        child: Column(
                                          children: [
                                            StickerIcon(
                                              icon: e.key.iconData,
                                              color: e.key.color,
                                              size: 16,
                                              showBackground: false,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              e.key.label,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontSize: 11,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                        // --- Horizontal gradient bars ---
                        if (top.isNotEmpty) ...[
                          const SizedBox(height: S.l),
                          Text('Распределение',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(color: context.cTextSec))
                              .animate()
                              .fadeIn(),
                          const SizedBox(height: S.s),
                          GlassCard(
                            showBorder: true,
                            padding: const EdgeInsets.all(S.m),
                            child: Column(
                              children: [
                                for (var i = 0; i < top.length; i++)
                                  Padding(
                                    padding: EdgeInsets.only(
                                        bottom:
                                            i < top.length - 1 ? S.s : 0),
                                    child: Row(
                                      children: [
                                        StickerIcon(
                                          icon: top[i].key.iconData,
                                          color: top[i].key.color,
                                          size: 16,
                                          showBackground: false,
                                        ),
                                        const SizedBox(width: S.s),
                                        SizedBox(
                                          width: 70,
                                          child: Text(
                                            top[i].key.label,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(color: context.cTextSec),
                                          ),
                                        ),
                                        const SizedBox(width: S.s),
                                        Expanded(
                                          child:
                                              TweenAnimationBuilder<double>(
                                            tween: Tween(
                                                begin: 0,
                                                end: top[i].value / maxC),
                                            duration: Duration(
                                                milliseconds: 500 + i * 100),
                                            curve: Anim.curve,
                                            builder: (context, value, _) =>
                                                FractionallySizedBox(
                                              alignment:
                                                  Alignment.centerLeft,
                                              widthFactor:
                                                  value.clamp(0.0, 1.0),
                                              child: Container(
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          3),
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      top[i].key.color,
                                                      top[i]
                                                          .key
                                                          .color
                                                          .withValues(
                                                              alpha: 0.4),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: S.s),
                                        SizedBox(
                                          width: 22,
                                          child: Text(
                                            '${top[i].value}',
                                            textAlign: TextAlign.right,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                      .animate()
                                      .fadeIn(delay: (i * 60).ms)
                                      .slideX(begin: -0.05, end: 0),
                              ],
                            ),
                          ),
                        ],

                        // --- Week ---
                        const SizedBox(height: S.l),
                        Text('Неделя',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(color: context.cTextSec))
                            .animate()
                            .fadeIn(),
                        const SizedBox(height: S.s),
                        GlassCard(
                          showBorder: true,
                          padding: const EdgeInsets.all(S.m),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (var i = 0; i < weekKeys.length; i++)
                                _WeekDot(emotion: week[weekKeys[i]])
                                    .animate()
                                    .fadeIn(delay: (60 + i * 40).ms)
                                    .scale(
                                      begin: const Offset(0.8, 0.8),
                                      end: const Offset(1, 1),
                                      delay: (60 + i * 40).ms,
                                      curve: Anim.curveGentle,
                                    ),
                            ],
                          ),
                        ),

                        // --- Positive ratio ---
                        const SizedBox(height: S.l),
                        Text('Позитив / негатив',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(color: context.cTextSec))
                            .animate()
                            .fadeIn(),
                        const SizedBox(height: S.s),
                        Center(
                          child: GlassCard(
                            showBorder: true,
                            padding: const EdgeInsets.all(S.l),
                            child: ProgressArc(
                              progress: ratio,
                              size: 160,
                              strokeWidth: 12,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedNumber(
                                    value: (ratio * 100).round(),
                                    suffix: '%',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  Text('позитивных',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 100.ms),

                        // --- Aura patterns ---
                        const SizedBox(height: S.l),
                        Text('Паттерны от Aura',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(color: context.cTextSec))
                            .animate()
                            .fadeIn(),
                        const SizedBox(height: S.s),
                        if (_auraPatterns.isEmpty)
                          GlassCard(
                            showBorder: true,
                            padding: const EdgeInsets.all(S.m),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 30,
                                  height: 30,
                                  child:
                                      const AuraAvatar(size: 30),
                                ),
                                const SizedBox(width: S.s),
                                Expanded(
                                  child: Text(
                                    'Aura подскажет паттерны, когда накопится больше записей',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: context.cTextDim),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._auraPatterns.asMap().entries.map(
                                (entry) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: S.s),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                          R.l + 1),
                                      gradient: C.gradientPrimary,
                                    ),
                                    padding: const EdgeInsets.all(1),
                                    child: GlassCard(
                                      padding: const EdgeInsets.all(S.m),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 30,
                                            height: 30,
                                            child: const AuraAvatar(size: 30),
                                          ),
                                          const SizedBox(width: S.s),
                                          Expanded(
                                            child: Text(
                                              entry.value,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    height: 1.45,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                    .animate()
                                    .fadeIn(delay: (entry.key * 80).ms)
                                    .slideY(begin: 0.05, end: 0),
                              ),
                        const SizedBox(height: S.xxl),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _WeekDot extends StatelessWidget {
  const _WeekDot({required this.emotion});

  final Emotion? emotion;

  @override
  Widget build(BuildContext context) {
    final c = emotion?.color ?? context.cSurfaceLight;
    final hasEmotion = emotion != null;
    return Semantics(
      label: hasEmotion ? 'Эмоция ${emotion!.label}' : 'Нет записи',
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: hasEmotion
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    c.withValues(alpha: 0.3),
                    c.withValues(alpha: 0.1),
                  ],
                )
              : null,
          color: hasEmotion ? null : context.cSurface,
          border: Border.all(
            color: hasEmotion
                ? c.withValues(alpha: 0.65)
                : context.cSurfaceLight.withValues(alpha: 0.4),
            width: hasEmotion ? 2 : 1,
          ),
          boxShadow: hasEmotion
              ? [
                  BoxShadow(
                      color: c.withValues(alpha: 0.2),
                      blurRadius: 6,
                      spreadRadius: -2)
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: emotion != null
            ? StickerIcon(
                icon: emotion!.iconData,
                color: emotion!.color,
                size: 20,
                showBackground: false,
              )
            : Icon(Icons.remove_rounded, size: 16, color: context.cTextDim),
      ),
    );
  }
}

class _EmotionBarsPainter extends CustomPainter {
  _EmotionBarsPainter({
    required this.entries,
    required this.maxCount,
    this.progress = 1.0,
  });

  final List<MapEntry<Emotion, int>> entries;
  final int maxCount;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty || maxCount <= 0) return;
    final n = entries.length;
    const gap = 6.0;
    final barW = (size.width - gap * (n - 1)) / n;
    final baseY = size.height - 4;
    const topPad = 8.0;
    final usableH = size.height - topPad - 24;
    const stagger = 0.08;
    const growDur = 0.55;

    for (var i = 0; i < n; i++) {
      final e = entries[i];
      final barStart = i * stagger;
      final t = ((progress - barStart) / growDur).clamp(0.0, 1.0);
      final h = usableH * (e.value / maxCount) * t;
      if (h <= 0) continue;
      final x = i * (barW + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, baseY - h, barW, h),
        const Radius.circular(6),
      );
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [e.key.color.withValues(alpha: 0.35), e.key.color],
        ).createShader(Rect.fromLTWH(x, baseY - h, barW, h));
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmotionBarsPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.maxCount != maxCount ||
        oldDelegate.progress != progress;
  }
}
