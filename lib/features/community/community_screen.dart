import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Sample models (replace with API DTOs / repository later) ─────────────

class CommunityChallengeSample {
  const CommunityChallengeSample({
    required this.id,
    required this.title,
    required this.description,
    required this.totalDays,
    required this.participantCount,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final int totalDays;
  final int participantCount;
  final MIconType icon;
}

class CommunityGroupSample {
  const CommunityGroupSample({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.description,
    required this.avatarColors,
  });

  final String id;
  final String name;
  final int memberCount;
  final String description;
  final List<Color> avatarColors;
}

class LeaderboardEntrySample {
  const LeaderboardEntrySample({
    required this.rank,
    required this.displayName,
    required this.minutesMeditated,
    required this.streakDays,
    required this.isCurrentUser,
  });

  final int rank;
  final String displayName;
  final int minutesMeditated;
  final int streakDays;
  final bool isCurrentUser;
}

// ── Hardcoded catalog (swap for API fetch) ─────────────────────────────────

const List<CommunityChallengeSample> kSampleChallenges = [
  CommunityChallengeSample(
    id: 'ch_mindfulness_7',
    title: '7 дней осознанности',
    description: 'Короткая практика каждый день — замечать момент без оценки.',
    totalDays: 7,
    participantCount: 234,
    icon: MIconType.star,
  ),
  CommunityChallengeSample(
    id: 'ch_morning_21',
    title: 'Утренний ритуал',
    description: '21 день спокойного старта: дыхание, намерение, мягкий фокус.',
    totalDays: 21,
    participantCount: 89,
    icon: MIconType.bolt,
  ),
  CommunityChallengeSample(
    id: 'ch_sleep_14',
    title: 'Засыпай за 10 минут',
    description: 'Вечерние медитации и расслабление тела перед сном.',
    totalDays: 14,
    participantCount: 567,
    icon: MIconType.moon,
  ),
  CommunityChallengeSample(
    id: 'ch_breath_30',
    title: 'Дыши каждый день',
    description: '30 дней дыхательных сессий — от 3 до 10 минут в день.',
    totalDays: 30,
    participantCount: 412,
    icon: MIconType.air,
  ),
];

const List<CommunityGroupSample> kSampleGroups = [
  CommunityGroupSample(
    id: 'grp_beginners',
    name: 'Новички',
    memberCount: 1204,
    description: 'Первые шаги в медитации, вопросы и поддержка без давления.',
    avatarColors: [C.calm, C.accent, C.primary],
  ),
  CommunityGroupSample(
    id: 'grp_advanced',
    name: 'Продвинутые',
    memberCount: 532,
    description: 'Углублённая практика, ретритный опыт и честные разборы.',
    avatarColors: [C.gold, C.rose, C.warm],
  ),
  CommunityGroupSample(
    id: 'grp_moms',
    name: 'Мамы в дзене',
    memberCount: 890,
    description: 'Найти паузу между делами: микро-практики и тёплое сообщество.',
    avatarColors: [C.grateful, C.happy, C.accentLight],
  ),
  CommunityGroupSample(
    id: 'grp_insomnia',
    name: 'Бессонница',
    memberCount: 678,
    description: 'Ночные и вечерние практики для успокоения нервной системы.',
    avatarColors: [C.sad, C.calm, C.primaryMuted],
  ),
];

List<LeaderboardEntrySample> kSampleLeaderboard() {
  const raw = <({
    int rank,
    String name,
    int min,
    int streak,
    bool me,
  })>[
    (rank: 1, name: 'Медитатор-8834', min: 412, streak: 21, me: false),
    (rank: 2, name: 'Медитатор-1205', min: 389, streak: 18, me: false),
    (rank: 3, name: 'Медитатор-5512', min: 356, streak: 14, me: false),
    (rank: 4, name: 'Медитатор-3091', min: 298, streak: 12, me: false),
    (rank: 5, name: 'Медитатор-7740', min: 265, streak: 11, me: false),
    (rank: 6, name: 'Медитатор-4521', min: 241, streak: 9, me: true),
    (rank: 7, name: 'Медитатор-6618', min: 198, streak: 8, me: false),
    (rank: 8, name: 'Медитатор-2204', min: 176, streak: 7, me: false),
    (rank: 9, name: 'Медитатор-9147', min: 154, streak: 5, me: false),
    (rank: 10, name: 'Медитатор-3380', min: 132, streak: 4, me: false),
  ];
  return raw
      .map(
        (e) => LeaderboardEntrySample(
          rank: e.rank,
          displayName: e.name,
          minutesMeditated: e.min,
          streakDays: e.streak,
          isCurrentUser: e.me,
        ),
      )
      .toList();
}

// ── SharedPreferences keys (local join + progress until API exists) ────────

abstract class CommunityPrefs {
  static const joinedIdsKey = 'community_challenges_joined';
  static String progressKey(String challengeId) => 'community_challenge_days_$challengeId';
}

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  double _parallax = 0;

  Set<String> _joinedChallengeIds = {};
  Map<String, int> _challengeDaysDone = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(() {
      if (!mounted) return;
      setState(() => _parallax = _scrollController.offset);
    });
    _loadPrefs();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    HapticFeedback.selectionClick();
    setState(() {});
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final joined = prefs.getStringList(CommunityPrefs.joinedIdsKey) ?? [];
    final days = <String, int>{};
    for (final id in joined) {
      days[id] = prefs.getInt(CommunityPrefs.progressKey(id)) ?? 0;
    }
    if (!mounted) return;
    setState(() {
      _joinedChallengeIds = joined.toSet();
      _challengeDaysDone = days;
    });
  }

  Future<void> _persistJoined() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      CommunityPrefs.joinedIdsKey,
      _joinedChallengeIds.toList(),
    );
  }

  Future<void> _persistProgress(String id, int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(CommunityPrefs.progressKey(id), days);
  }

  Future<void> _joinChallenge(CommunityChallengeSample c) async {
    setState(() {
      _joinedChallengeIds.add(c.id);
      _challengeDaysDone[c.id] = _challengeDaysDone[c.id] ?? 0;
    });
    await _persistJoined();
    await _persistProgress(c.id, _challengeDaysDone[c.id]!);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBg(
      showAurora: true,
      intensity: 0.55,
      parallaxOffset: _parallax,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(S.m, S.s, S.m, S.s),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (context.canPop()) context.pop();
                  },
                  icon: MIcon(MIconType.arrowBack, size: 22, color: context.cText),
                ),
                Expanded(
                  child: Text(
                    'Сообщество',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: context.cText,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.m),
            child: _GlassTabBar(controller: _tabController),
          ),
          const SizedBox(height: S.s),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ChallengesTab(
                  joinedIds: _joinedChallengeIds,
                  daysDone: _challengeDaysDone,
                  onJoin: _joinChallenge,
                ),
                _GroupsTab(
                  onCreateGroup: () {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Скоро!',
                          style: TextStyle(color: context.cText),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                _LeadersTab(entries: kSampleLeaderboard()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glass TabBar + gradient pill indicator ─────────────────────────────────

class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return ClipRRect(
      borderRadius: BorderRadius.circular(R.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isLight
                ? Colors.white.withValues(alpha: 0.55)
                : C.surfaceGlass.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(R.xl),
            border: Border.all(color: context.cSurfaceBorder),
          ),
          child: TabBar(
            controller: controller,
            splashFactory: InkRipple.splashFactory,
            overlayColor: WidgetStatePropertyAll(
              C.primary.withValues(alpha: 0.08),
            ),
            dividerColor: Colors.transparent,
            labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
            unselectedLabelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
            labelColor: Colors.white,
            unselectedLabelColor: context.cTextSec,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.all(S.xs),
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(R.xl - 2),
              gradient: C.gradientPrimary,
              boxShadow: [
                BoxShadow(
                  color: C.glowPrimary.withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ],
            ),
            tabs: const [
              Tab(text: 'Челленджи'),
              Tab(text: 'Группы'),
              Tab(text: 'Лидеры'),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tab: Challenges ────────────────────────────────────────────────────────

class _ChallengesTab extends StatelessWidget {
  const _ChallengesTab({
    required this.joinedIds,
    required this.daysDone,
    required this.onJoin,
  });

  final Set<String> joinedIds;
  final Map<String, int> daysDone;
  final void Function(CommunityChallengeSample) onJoin;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(S.m, S.s, S.m, S.xxl),
      itemCount: kSampleChallenges.length,
      itemBuilder: (context, index) {
        final c = kSampleChallenges[index];
        final joined = joinedIds.contains(c.id);
        final done = (daysDone[c.id] ?? 0).clamp(0, c.totalDays);
        final t = done / c.totalDays;

        return Padding(
          padding: const EdgeInsets.only(bottom: S.m),
          child: GlassCard(
            useBlur: true,
            opacity: 0.1,
            showBorder: true,
            showLightSweep: index == 0,
            padding: const EdgeInsets.all(S.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(R.m),
                        gradient: C.gradientAurora,
                      ),
                      child: Center(
                        child: MIcon(c.icon, size: 26, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: S.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.title,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: context.cText,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: S.xs),
                          Text(
                            c.description,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: context.cTextSec,
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: S.m),
                Row(
                  children: [
                    MIcon(MIconType.meditation, size: 16, color: context.cTextDim),
                    const SizedBox(width: S.xs),
                    Text(
                      '${c.participantCount} участников',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.cTextDim,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: S.s),
                ClipRRect(
                  borderRadius: BorderRadius.circular(R.full),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: t),
                    duration: Anim.normal,
                    curve: Anim.curve,
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: joined ? value : 0,
                        minHeight: 6,
                        backgroundColor: context.cSurfaceLight.withValues(alpha: 0.5),
                        color: C.accent,
                        borderRadius: BorderRadius.circular(R.full),
                      );
                    },
                  ),
                ),
                const SizedBox(height: S.xs),
                Text(
                  joined
                      ? 'День $done из ${c.totalDays}'
                      : '${c.totalDays} дней · присоединись, чтобы отслеживать прогресс',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.cTextDim,
                      ),
                ),
                const SizedBox(height: S.m),
                if (!joined)
                  GlowButton(
                    showGlow: true,
                    onPressed: () => onJoin(c),
                    child: const Text('Присоединиться'),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: S.s + 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(R.xl),
                      gradient: LinearGradient(
                        colors: [
                          C.accent.withValues(alpha: 0.2),
                          C.primary.withValues(alpha: 0.15),
                        ],
                      ),
                      border: Border.all(color: C.accent.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MIcon(MIconType.check, size: 18, color: C.accentLight),
                        const SizedBox(width: S.xs),
                        Text(
                          'Вы в челлендже',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: context.cText,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(duration: Anim.normal, delay: (Anim.stagger * index).inMilliseconds.ms)
            .slideY(begin: 0.06, end: 0, duration: Anim.normal, curve: Anim.curve);
      },
    );
  }
}

// ── Tab: Groups ────────────────────────────────────────────────────────────

class _GroupsTab extends StatelessWidget {
  const _GroupsTab({required this.onCreateGroup});

  final VoidCallback onCreateGroup;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(S.m, S.s, S.m, S.m),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final g = kSampleGroups[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: S.m),
                  child: GlassCard(
                    useBlur: true,
                    opacity: 0.1,
                    showBorder: true,
                    padding: const EdgeInsets.all(S.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _AvatarStack(colors: g.avatarColors),
                            const SizedBox(width: S.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    g.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: context.cText,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${g.memberCount} участников',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: context.cTextDim,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            MIcon(MIconType.chevronRight, size: 20, color: context.cTextDim),
                          ],
                        ),
                        const SizedBox(height: S.m),
                        Text(
                          g.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: context.cTextSec,
                                height: 1.45,
                              ),
                        ),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(
                      duration: Anim.normal,
                      delay: (Anim.stagger * index).inMilliseconds.ms,
                    )
                    .slideX(begin: 0.04, end: 0, duration: Anim.normal, curve: Anim.curve);
              },
              childCount: kSampleGroups.length,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(S.m, S.s, S.m, S.xxl),
          sliver: SliverToBoxAdapter(
            child: GlowButton(
              showGlow: true,
              glowColor: C.glowAccent,
              onPressed: onCreateGroup,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MIcon(MIconType.add, size: 20, color: Colors.white),
                  const SizedBox(width: S.s),
                  const Text('Создать группу'),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 280.ms, duration: Anim.normal)
                .shimmer(duration: 1800.ms, color: Colors.white.withValues(alpha: 0.12)),
          ),
        ),
      ],
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    const size = 36.0;
    const overlap = 18.0;
    final n = colors.length;
    final w = size + (n - 1) * overlap;
    return SizedBox(
      width: w,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < n; i++)
            Positioned(
              left: i * overlap,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      colors[i],
                      colors[i].withValues(alpha: 0.65),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.light
                        ? context.cSurface
                        : context.cBg,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors[i].withValues(alpha: 0.35),
                      blurRadius: 8,
                      spreadRadius: -1,
                    ),
                  ],
                ),
                child: Center(
                  child: MIcon(
                    MIconType.meditation,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Tab: Leaders ───────────────────────────────────────────────────────────

class _LeadersTab extends StatelessWidget {
  const _LeadersTab({required this.entries});

  final List<LeaderboardEntrySample> entries;

  static LinearGradient? _podiumGradient(int rank) {
    switch (rank) {
      case 1:
        return const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFBBF24), Color(0xFFF97316)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 2:
        return LinearGradient(
          colors: [
            const Color(0xFFE8E8E8),
            const Color(0xFF94A3B8),
            const Color(0xFF64748B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 3:
        return const LinearGradient(
          colors: [Color(0xFFCD7F32), Color(0xFFB45309), Color(0xFF9A3412)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(S.m, S.s, S.m, S.xxl),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: S.m),
            child: Text(
              'Недельный рейтинг',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.cTextSec,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ).animate().fadeIn(duration: Anim.fast);
        }
        final e = entries[index - 1];
        final podium = _podiumGradient(e.rank);
        final highlight = e.isCurrentUser;

        Widget card = GlassCard(
          useBlur: true,
          opacity: highlight ? 0.14 : 0.08,
          showBorder: true,
          showGlow: highlight,
          glowColor: C.glowAccent,
          showAnimatedBorder: e.rank <= 3,
          borderGradientColors: e.rank == 1
              ? const [Color(0xFFFFD700), C.accent, C.primary, Color(0xFFFFD700)]
              : e.rank == 2
                  ? [const Color(0xFFCBD5E1), C.calm, C.primary, const Color(0xFFCBD5E1)]
                  : e.rank == 3
                      ? const [Color(0xFFCD7F32), C.warm, C.rose, Color(0xFFCD7F32)]
                      : null,
          padding: const EdgeInsets.symmetric(horizontal: S.m, vertical: S.s + 2),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: podium != null
                    ? ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) =>
                            podium.createShader(bounds),
                        child: Text(
                          '${e.rank}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                        ),
                      )
                    : Text(
                        '${e.rank}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: context.cTextDim,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
              ),
              const SizedBox(width: S.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            e.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: context.cText,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        if (e.isCurrentUser) ...[
                          const SizedBox(width: S.s),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: S.s, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: C.gradientPrimary,
                              borderRadius: BorderRadius.circular(R.full),
                            ),
                            child: Text(
                              'Вы',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${e.minutesMeditated} мин · серия ${e.streakDays} дн.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.cTextSec,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MIcon(MIconType.fire, size: 18, color: C.warm.withValues(alpha: 0.9)),
                  Text(
                    '${e.streakDays}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: context.cTextDim,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ),
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: S.s),
          child: card
              .animate()
              .fadeIn(
                duration: Anim.normal,
                delay: (Anim.stagger * index).inMilliseconds.ms,
              )
              .slideX(begin: 0.05, end: 0, duration: Anim.normal, curve: Anim.curve),
        );
      },
    );
  }
}
