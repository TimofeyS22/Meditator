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
import 'package:meditator/shared/widgets/aura_avatar.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/core/notifications/notification_service.dart';
import 'package:meditator/shared/widgets/shimmer_loading.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfile? _profile;
  int _minutesToday = 0;
  Meditation? _recommended;
  String _reason = '';
  bool _loadingAura = true;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _load();
    NotificationService.instance.init().then((_) {
      NotificationService.instance.triggerAnalysis();
      NotificationService.instance.checkPendingNotifications();
    }).catchError((_) {});
  }

  Future<int> _computeMinutesToday(String userId) async {
    final sessions = await Db.instance.getSessionsForUser(userId, limit: 80);
    final now = DateTime.now();
    var sumSeconds = 0;
    for (final s in sessions) {
      final raw = s['created_at'] ?? s['createdAt'];
      final created = raw is String ? DateTime.tryParse(raw) : null;
      if (created == null) continue;
      if (created.year != now.year ||
          created.month != now.month ||
          created.day != now.day) {
        continue;
      }
      final ds = s['duration_seconds'];
      if (ds is int) {
        sumSeconds += ds;
        continue;
      }
      if (ds is num) {
        sumSeconds += ds.round();
        continue;
      }
      final dm = s['duration_minutes'] ?? s['durationMinutes'];
      if (dm is int) {
        sumSeconds += dm * 60;
        continue;
      }
      if (dm is num) {
        sumSeconds += (dm.round() * 60);
        continue;
      }
    }
    return (sumSeconds / 60).ceil();
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

    final goal =
        prof?.goals.isNotEmpty == true ? prof!.goals.first.name : 'stress';
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
      reason =
          (map['reason'] ?? map['why'] ?? map['summary'] ?? '') as String? ??
              '';
    } catch (_) {
      try {
        final list = await Db.instance.getMeditations();
        if (list.isNotEmpty) {
          rec = Meditation.fromJson(list.first);
          reason = 'Подобрали из библиотеки — Aura всё равно рядом.';
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
    final id =
        m['id'] as String? ?? 'aura_${DateTime.now().millisecondsSinceEpoch}';
    final title =
        m['title'] as String? ?? m['name'] as String? ?? 'Практика от Aura';
    final description =
        m['description'] as String? ?? m['script'] as String? ?? '';
    final dur =
        (m['durationMinutes'] ?? m['duration_minutes']) as int? ?? 10;
    final audioUrl =
        m['audioUrl'] as String? ?? m['audio_url'] as String?;
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
    final topPad = MediaQuery.paddingOf(context).top;

    return GradientBg(
      showStars: true,
      showAurora: false,
      intensity: 0.2,
      child: RefreshIndicator(
        color: C.accent,
        backgroundColor: context.cSurface,
        onRefresh: _load,
        displacement: 60,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(
              decelerationRate: ScrollDecelerationRate.fast,
            ),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(S.l, topPad + S.l, S.l, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Compact header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            '${_greeting()}, $who',
                            style: t.displayMedium,
                          )
                              .animate()
                              .fadeIn(duration: 450.ms, curve: Anim.curve)
                              .slideY(begin: 0.04, duration: 450.ms, curve: Anim.curve),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/aura'),
                          child: const Hero(
                            tag: 'aura_avatar_header',
                            child: AuraAvatar(size: 36),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: S.section),

                    // Hero zone — Aura recommendation
                    AuraCard(
                      meditation: _recommended,
                      reason: _reason,
                      loading: _loadingAura,
                    ),

                    const SizedBox(height: S.section),

                    // Stats
                    _loadingProfile
                        ? _StatsRowSkeleton()
                        : StatsRow(
                            minutesToday: _minutesToday,
                            streak: streak,
                            totalSessions: sessions,
                          ),

                    const SizedBox(height: S.section),

                    // Practices section
                    Text('Практики', style: t.headlineMedium)
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 400.ms),
                    const SizedBox(height: S.m),

                    const QuickActions(),

                    SizedBox(
                      height:
                          MediaQuery.paddingOf(context).bottom + 80 + S.xl,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRowSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: S.xl),
          Expanded(
            child: ShimmerLoading(
              width: double.infinity,
              height: 48,
              borderRadius: R.s,
              organic: true,
            ),
          ),
        ],
      ],
    );
  }
}
