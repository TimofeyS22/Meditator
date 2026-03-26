import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/api/backend.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/features/home/widgets/aura_card.dart';
import 'package:meditator/features/home/widgets/quick_actions.dart';
import 'package:meditator/features/home/widgets/stats_row.dart';
import 'package:meditator/shared/models/meditation.dart';
import 'package:meditator/shared/models/user_profile.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/shared/widgets/shimmer_loading.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);
  UserProfile? _profile;
  int _minutesToday = 0;
  Meditation? _recommended;
  String _reason = '';
  bool _loadingAura = true;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (!_scrollCtrl.hasClients) return;
      _scrollOffset.value = _scrollCtrl.offset;
    });
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  Future<int> _computeMinutesToday(String userId) async {
    final sessions = await Db.instance.getSessionsForUser(userId, limit: 80);
    final now = DateTime.now();
    var sum = 0;
    for (final s in sessions) {
      final raw = s['created_at'] ?? s['createdAt'];
      final created = raw is String ? DateTime.tryParse(raw) : null;
      if (created == null) continue;
      if (created.year != now.year || created.month != now.month || created.day != now.day) continue;
      final dm = s['duration_minutes'] ?? s['durationMinutes'];
      if (dm is int) sum += dm;
      if (dm is num) sum += dm.round();
    }
    return sum;
  }

  Future<void> _load() async {
    final uid = AuthService.instance.userId;
    UserProfile? prof;
    var todayMin = 0;
    if (uid != null) {
      final row = await Db.instance.getProfile(uid);
      if (row != null) {
        prof = UserProfile.fromJson(row);
        todayMin = await _computeMinutesToday(uid);
      }
    }
    if (!mounted) return;
    setState(() {
      _profile = prof;
      _minutesToday = todayMin;
      _loadingProfile = false;
    });

    final goal = prof?.goals.isNotEmpty == true ? prof!.goals.first.name : 'stress';
    final mood = _moodFromStress(prof?.stressLevel ?? StressLevel.moderate);
    final dur = prof?.preferredDuration.minutes ?? 10;

    Meditation? rec;
    var reason = '';
    try {
      final map = await Backend.instance.generateMeditation(
        mood: mood,
        goal: goal,
        durationMinutes: dur,
      );
      rec = _meditationFromAura(map);
      reason = (map['reason'] ?? map['why'] ?? map['summary'] ?? '') as String? ?? '';
    } catch (_) {
      try {
        final list = await Db.instance.getMeditations();
        if (list.isNotEmpty) {
          rec = Meditation.fromJson(list.first);
          reason = 'Подобрали из библиотеки — когда сеть недоступна, Aura всё равно рядом.';
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _recommended = rec;
      _reason = reason;
      _loadingAura = false;
    });
  }

  static String _moodFromStress(StressLevel s) => switch (s) {
        StressLevel.low => 'спокойный',
        StressLevel.moderate => 'сбалансированный',
        StressLevel.high => 'напряжённый',
        StressLevel.veryHigh => 'уставший',
      };

  static Meditation? _meditationFromAura(Map<String, dynamic> m) {
    MeditationCategory cat = MeditationCategory.breathing;
    final raw = m['category'];
    if (raw is String) {
      for (final c in MeditationCategory.values) {
        if (c.name == raw) cat = c;
      }
    }
    final id = m['id'] as String? ?? 'aura_${DateTime.now().millisecondsSinceEpoch}';
    final title = m['title'] as String? ?? m['name'] as String? ?? 'Практика от Aura';
    final description = m['description'] as String? ?? m['script'] as String? ?? '';
    final dur = (m['durationMinutes'] ?? m['duration_minutes']) as int? ?? 10;
    final audioUrl = m['audioUrl'] as String? ?? m['audio_url'] as String?;
    return Meditation(
      id: id,
      title: title,
      description: description,
      category: cat,
      durationMinutes: dur,
      audioUrl: audioUrl,
      isGenerated: true,
      createdAt: DateTime.now(),
    );
  }

  String _greeting() => C.timeOfDay().greeting;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = _profile?.displayName.trim();
    final who = (name != null && name.isNotEmpty) ? name : 'друг';

    final streak = _profile?.currentStreak ?? 0;
    final sessions = _profile?.totalSessions ?? 0;

    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffset,
      builder: (context, scrollOffset, _) => GradientBg(
        showStars: true,
        showAurora: false,
        intensity: 0.3,
        parallaxOffset: scrollOffset,
        child: RefreshIndicator(
          color: C.accent,
          onRefresh: _load,
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(S.m, S.m, S.m, S.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: -40,
                            top: -20,
                            child: IgnorePointer(
                              child: ImageFiltered(
                                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [
                                        C.primary.withValues(alpha: 0.08),
                                        Colors.transparent,
                                      ],
                                      radius: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Opacity(
                            opacity: (1.0 - (scrollOffset / 200.0)).clamp(0.0, 1.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Transform.scale(
                                  scale: 1.0 +
                                      (-scrollOffset / 500).clamp(0.0, 0.15),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${_greeting()}, $who',
                                    style: t.displayLarge,
                                  )
                                      .animate()
                                      .fadeIn(duration: 450.ms)
                                      .slideX(
                                          begin: -0.02, duration: 450.ms),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Aura на связи — давай пару минут для себя.',
                                  style: t.bodyMedium?.copyWith(color: C.textSec),
                                ).animate().fadeIn(delay: 80.ms, duration: 400.ms),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: S.l),
                      AuraCard(
                        meditation: _recommended,
                        reason: _reason,
                        loading: _loadingAura,
                      ),
                      const SizedBox(height: S.m),
                      if (_loadingProfile)
                        const _StatsRowSkeleton()
                      else
                        StatsRow(
                          minutesToday: _minutesToday,
                          streak: streak,
                          totalSessions: sessions,
                        ),
                      const SizedBox(height: S.l),
                      const QuickActions(),
                      const SizedBox(height: S.l),
                      GlowButton(
                        onPressed: () => context.push('/library'),
                        width: double.infinity,
                        semanticLabel: 'Открыть библиотеку медитаций',
                        child: const Text('Библиотека'),
                      ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.04),
                      const SizedBox(height: S.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRowSkeleton extends StatelessWidget {
  const _StatsRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: S.s),
          Expanded(
            child: ShimmerLoading(
              width: double.infinity,
              height: 80,
              borderRadius: R.l,
            ),
          ),
        ],
      ],
    );
  }
}
