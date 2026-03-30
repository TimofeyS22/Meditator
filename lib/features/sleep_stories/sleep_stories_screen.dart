import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/features/home/meditation_playback_cache.dart';
import 'package:meditator/shared/models/meditation.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/shared/widgets/shimmer_loading.dart';

/// Глобальное состояние таймера сна (сохраняется между открытиями экрана).
class SleepStoriesScreen extends StatefulWidget {
  const SleepStoriesScreen({super.key});

  static int? sleepTimerMinutes;
  static DateTime? sleepTimerEndsAt;

  @override
  State<SleepStoriesScreen> createState() => _SleepStoriesScreenState();
}

class _SleepStoriesScreenState extends State<SleepStoriesScreen> {
  List<Meditation> _stories = [];
  bool _loading = true;
  Timer? _tick;

  static const _cardW = 272.0;
  static const _cardH = 168.0;

  static const _navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF070B1A),
      Color(0xFF0F1633),
      Color(0xFF1A1F4A),
    ],
  );

  @override
  void initState() {
    super.initState();
    _syncTimerExpiry();
    _startTickerIfNeeded();
    _fetch();
  }

  void _syncTimerExpiry() {
    final end = SleepStoriesScreen.sleepTimerEndsAt;
    if (end != null && DateTime.now().isAfter(end)) {
      SleepStoriesScreen.sleepTimerMinutes = null;
      SleepStoriesScreen.sleepTimerEndsAt = null;
    }
  }

  void _startTickerIfNeeded() {
    _tick?.cancel();
    if (SleepStoriesScreen.sleepTimerEndsAt == null) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final end = SleepStoriesScreen.sleepTimerEndsAt;
      if (end != null && DateTime.now().isAfter(end)) {
        SleepStoriesScreen.sleepTimerMinutes = null;
        SleepStoriesScreen.sleepTimerEndsAt = null;
        _tick?.cancel();
        _tick = null;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final rows = await Db.instance.getMeditations();
    if (!mounted) return;
    final list = rows.map((e) => Meditation.fromJson(e)).toList();
    final sleep = list.where((m) => m.category == MeditationCategory.sleep).toList();
    setState(() {
      _stories = sleep;
      _loading = false;
    });
  }

  void _setSleepTimer(int? minutes) {
    setState(() {
      SleepStoriesScreen.sleepTimerMinutes = minutes;
      if (minutes == null) {
        SleepStoriesScreen.sleepTimerEndsAt = null;
        _tick?.cancel();
        _tick = null;
      } else {
        SleepStoriesScreen.sleepTimerEndsAt =
            DateTime.now().add(Duration(minutes: minutes));
        _startTickerIfNeeded();
      }
    });
  }

  String _countdownLabel() {
    final end = SleepStoriesScreen.sleepTimerEndsAt;
    if (end == null) return '';
    final d = end.difference(DateTime.now());
    if (d.isNegative) return '';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _openStory(Meditation m) {
    MeditationPlaybackCache.byId[m.id] = m;
    context.push('/play?id=${Uri.encodeComponent(m.id)}');
  }

  String _snippet(String text, {int max = 96}) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max).trim()}…';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBg(
          showStars: true,
          intensity: 0.5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(S.m, S.s, S.m, S.s),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      tooltip: 'Назад',
                      icon: MIcon(MIconType.arrowBack, size: 24, color: context.cText),
                    ),
                    Expanded(
                      child: Text(
                        'Истории для сна',
                        textAlign: TextAlign.center,
                        style: t.headlineMedium?.copyWith(
                          color: context.cText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ).animate().fadeIn(duration: Anim.normal),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: S.m),
                child: GlassCard(
                  padding: const EdgeInsets.all(S.m),
                  opacity: 0.12,
                  showBorder: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          MIcon(MIconType.timer, size: 22, color: const Color(0xFF93C5FD)),
                          const SizedBox(width: S.s),
                          Text(
                            'Таймер сна',
                            style: t.titleLarge?.copyWith(color: context.cText),
                          ),
                        ],
                      ),
                      const SizedBox(height: S.xs),
                      Text(
                        'Автоостановка воспроизведения',
                        style: t.bodySmall?.copyWith(color: context.cTextSec),
                      ),
                      if (SleepStoriesScreen.sleepTimerEndsAt != null &&
                          _countdownLabel().isNotEmpty) ...[
                        const SizedBox(height: S.m),
                        Text(
                          'Осталось: ${_countdownLabel()}',
                          style: t.titleMedium?.copyWith(
                            color: const Color(0xFF7DD3FC),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: S.m),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: Row(
                          children: [
                            _TimerGlowChoice(
                              label: 'Выкл',
                              selected: SleepStoriesScreen.sleepTimerMinutes == null,
                              onTap: () => _setSleepTimer(null),
                            ),
                            const SizedBox(width: S.s),
                            _TimerGlowChoice(
                              label: '15 мин',
                              selected: SleepStoriesScreen.sleepTimerMinutes == 15,
                              onTap: () => _setSleepTimer(15),
                            ),
                            const SizedBox(width: S.s),
                            _TimerGlowChoice(
                              label: '30 мин',
                              selected: SleepStoriesScreen.sleepTimerMinutes == 30,
                              onTap: () => _setSleepTimer(30),
                            ),
                            const SizedBox(width: S.s),
                            _TimerGlowChoice(
                              label: '45 мин',
                              selected: SleepStoriesScreen.sleepTimerMinutes == 45,
                              onTap: () => _setSleepTimer(45),
                            ),
                            const SizedBox(width: S.s),
                            _TimerGlowChoice(
                              label: '60 мин',
                              selected: SleepStoriesScreen.sleepTimerMinutes == 60,
                              onTap: () => _setSleepTimer(60),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: Anim.stagger, duration: Anim.normal)
                  .slideY(begin: 0.04, curve: Anim.curve),

              Padding(
                padding: const EdgeInsets.fromLTRB(S.m, S.l, S.m, S.s),
                child: Text(
                  'Подборка',
                  style: t.titleLarge?.copyWith(color: context.cTextSec),
                ),
              ).animate().fadeIn(delay: Anim.stagger * 2, duration: Anim.normal),

              Expanded(
                child: _loading
                    ? ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(S.m, 0, S.m, S.xl),
                        children: List.generate(
                          4,
                          (i) => Padding(
                            padding: const EdgeInsets.only(right: S.m),
                            child: ShimmerLoading(
                              width: _cardW,
                              height: _cardH,
                              borderRadius: R.l,
                              organic: true,
                            ),
                          ),
                        ),
                      )
                    : _stories.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(S.l),
                              child: Text(
                                'Пока нет историй для сна — загляни позже.',
                                textAlign: TextAlign.center,
                                style: t.bodyMedium?.copyWith(color: context.cTextSec),
                              ),
                            ),
                          )
                            .animate()
                            .fadeIn(duration: Anim.normal)
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(S.m, 0, S.m, S.xl),
                            itemCount: _stories.length,
                            itemBuilder: (context, i) {
                              final m = _stories[i];
                              return Padding(
                                padding: const EdgeInsets.only(right: S.m),
                                child: _SleepStoryCard(
                                  meditation: m,
                                  gradient: _navyGradient,
                                  onTap: () => _openStory(m),
                                  snippet: _snippet(m.description),
                                )
                                    .animate()
                                    .fadeIn(
                                      delay: Duration(
                                        milliseconds: 50 * i,
                                      ),
                                      duration: Anim.normal,
                                    )
                                    .slideX(
                                      begin: 0.06,
                                      curve: Anim.curve,
                                      duration: Anim.normal,
                                    ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerGlowChoice extends StatelessWidget {
  const _TimerGlowChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlowButton(
      width: label == 'Выкл' ? 76 : 88,
      showGlow: selected,
      glowColor: const Color(0x406366F1),
      semanticLabel: label,
      onPressed: onTap,
      child: Text(label),
    );
  }
}

class _SleepStoryCard extends StatelessWidget {
  const _SleepStoryCard({
    required this.meditation,
    required this.gradient,
    required this.onTap,
    required this.snippet,
  });

  final Meditation meditation;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final String snippet;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(R.l),
        child: Ink(
          width: _SleepStoriesScreenState._cardW,
          height: _SleepStoriesScreenState._cardH,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(R.l),
            gradient: gradient,
            border: Border.all(
              color: const Color(0xFF312E81).withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF312E81).withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(S.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(S.s),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B4B).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(R.m),
                      ),
                      child: const MIcon(
                        MIconType.moon,
                        size: 26,
                        color: Color(0xFFC7D2FE),
                      ),
                    ),
                    const SizedBox(width: S.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meditation.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleMedium?.copyWith(
                              color: context.cText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${meditation.durationMinutes} мин',
                            style: t.labelSmall?.copyWith(
                              color: const Color(0xFF93C5FD),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(
                    color: context.cTextSec,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
