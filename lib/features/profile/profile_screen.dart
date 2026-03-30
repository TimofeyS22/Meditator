import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/shared/models/user_profile.dart';
import 'package:meditator/shared/widgets/animated_number.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/shared/widgets/skeleton_placeholders.dart';
import 'package:meditator/shared/widgets/streak_celebration.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;
  int _plantCount = 0;
  bool _showStreakCelebration = false;
  int _celebratedStreak = 0;

  String? get _uid => AuthService.instance.userId;

  static const _kCelebratedStreak = 'celebrated_streak';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = _uid;
    UserProfile? prof;
    var plants = 0;
    final prefs = await SharedPreferences.getInstance();
    final premiumPref = prefs.getBool('isPremium') ?? false;
    _celebratedStreak = prefs.getInt(_kCelebratedStreak) ?? 0;

    try {
      if (uid != null && uid.isNotEmpty) {
        final row = await Db.instance.getProfile(uid);
        if (row != null) {
          final parsed = UserProfile.fromJson(row);
          prof = parsed.copyWith(isPremium: premiumPref || parsed.isPremium);
        }
        try {
          final garden = await Db.instance.getGarden(uid);
          plants = garden.length;
        } catch (_) {}
      }
    } catch (_) {}

    prof ??= UserProfile(
      id: uid ?? 'local',
      email: AuthService.instance.currentUser?.email ?? '',
      displayName: '',
      createdAt: DateTime.now(),
      isPremium: premiumPref,
    );

    if (!mounted) return;
    setState(() {
      _profile = prof;
      _plantCount = plants;
      _loading = false;
    });
    final streak = prof.currentStreak;
    final milestones = [3, 7, 14, 30, 60, 100, 365];
    if (milestones.contains(streak) && streak > _celebratedStreak) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          setState(() {
            _showStreakCelebration = true;
            _celebratedStreak = streak;
          });
          final p = await SharedPreferences.getInstance();
          await p.setInt(_kCelebratedStreak, streak);
        }
      });
    }
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return 'М';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  ({String title, double progress}) _levelFor(int sessions) {
    if (sessions <= 10) {
      return (title: 'Новичок', progress: (sessions / 11).clamp(0.0, 1.0));
    }
    if (sessions <= 50) {
      return (title: 'Практик', progress: ((sessions - 11) / 40).clamp(0.0, 1.0));
    }
    if (sessions <= 200) {
      return (title: 'Мастер', progress: ((sessions - 51) / 150).clamp(0.0, 1.0));
    }
    return (title: 'Гуру', progress: 1.0);
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_done');
    await AuthService.instance.signOut();
    if (!mounted) return;
    context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _profile == null) {
      return GradientBg(
        showStars: true,
        intensity: 0.2,
        child: const SafeArea(child: ProfileSkeleton()),
      );
    }

    final profile = _profile!;
    final t = Theme.of(context).textTheme;
    final displayName =
        profile.displayName.trim().isNotEmpty ? profile.displayName : 'Медитатор';
    final level = _levelFor(profile.totalSessions);
    final streakFire = profile.currentStreak > 7;

    final achievements = <({String title, bool done})>[
      (title: 'Первая медитация', done: profile.totalSessions >= 1),
      (title: '7 дней подряд', done: profile.currentStreak >= 7),
      (title: '30 сессий', done: profile.totalSessions >= 30),
      (title: 'Садовник', done: _plantCount >= 1),
    ];

    return Stack(
      children: [
        GradientBg(
          showStars: true,
          intensity: 0.2,
          child: RefreshIndicator(
            onRefresh: _load,
            color: C.accent,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(S.l, S.l, S.l, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compact header
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: C.gradientPrimary,
                        ),
                        child: ClipOval(
                          child: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                              ? Image.network(
                                  profile.avatarUrl!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _InitialsText(
                                    initials: _initials(displayName == 'Медитатор' ? null : displayName),
                                  ),
                                )
                              : _InitialsText(
                                  initials: _initials(displayName == 'Медитатор' ? null : displayName),
                                ),
                        ),
                      ),
                      const SizedBox(width: S.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName, style: t.headlineLarge),
                            if (profile.email.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(profile.email, style: t.bodySmall?.copyWith(color: context.cTextSec)),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.push('/settings'),
                        icon: MIcon(MIconType.settings, size: 22, color: context.cTextSec),
                        tooltip: 'Настройки',
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(duration: Anim.normal)
                      .slideY(begin: -0.04, end: 0, duration: Anim.normal),

                  const SizedBox(height: S.section),

                  // Stats — horizontal scroll
                  SizedBox(
                    height: 88,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      children: [
                        _StatTile(
                          icon: MIconType.meditation,
                          value: profile.totalSessions,
                          label: 'Сессии',
                          accentColor: C.primary,
                        ),
                        const SizedBox(width: S.s),
                        _StatTile(
                          icon: MIconType.timer,
                          value: profile.totalMinutes,
                          label: 'Минуты',
                          accentColor: C.accent,
                        ),
                        const SizedBox(width: S.s),
                        _StatTile(
                          icon: streakFire ? MIconType.fire : MIconType.bolt,
                          value: profile.currentStreak,
                          label: 'Серия',
                          accentColor: streakFire ? C.gold : C.primary,
                          showGlow: streakFire,
                        ),
                        const SizedBox(width: S.s),
                        _StatTile(
                          icon: MIconType.eco,
                          value: _plantCount,
                          label: 'Растения',
                          accentColor: C.ok,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms, duration: Anim.normal),

                  const SizedBox(height: S.section),

                  // Level — inline progress bar
                  GlassCard(
                    variant: GlassCardVariant.surface,
                    semanticLabel: 'Уровень ${level.title}, прогресс ${(level.progress * 100).round()}%',
                    padding: const EdgeInsets.all(S.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(level.title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Text(
                              '${profile.totalSessions} сессий',
                              style: t.bodySmall?.copyWith(color: context.cTextSec),
                            ),
                          ],
                        ),
                        const SizedBox(height: S.m),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(R.full),
                          child: LinearProgressIndicator(
                            value: level.progress.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: context.cSurfaceLight,
                            valueColor: const AlwaysStoppedAnimation<Color>(C.primary),
                          ),
                        ),
                        const SizedBox(height: S.s),
                        Text(
                          'Чем стабильнее практика, тем глубже калибровка.',
                          style: t.bodySmall?.copyWith(color: context.cTextDim, height: 1.4),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 150.ms, duration: Anim.normal),

                  const SizedBox(height: S.section),

                  // Menu
                  GlassCard(
                    variant: GlassCardVariant.surface,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _MenuRow(
                          icon: MIconType.eco,
                          title: 'Мой сад',
                          subtitle: '$_plantCount растений',
                          onTap: () => context.push('/garden'),
                        ),
                        Divider(height: 1, color: context.cSurfaceBorder),
                        _MenuRow(
                          icon: MIconType.heart,
                          title: 'Мой партнёр',
                          onTap: () => context.push('/pair'),
                        ),
                        Divider(height: 1, color: context.cSurfaceBorder),
                        _MenuRow(
                          icon: MIconType.premium,
                          title: 'Подписка',
                          subtitle: profile.isPremium ? 'Premium' : null,
                          onTap: () async {
                            await context.push('/paywall');
                            await _load();
                          },
                        ),
                        Divider(height: 1, color: context.cSurfaceBorder),
                        _MenuRow(
                          icon: MIconType.arrowForward,
                          title: 'Загрузки',
                          onTap: () => context.push('/downloads'),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: Anim.normal)
                      .slideY(begin: 0.02, end: 0, duration: Anim.normal),

                  const SizedBox(height: S.section),

                  // Achievements
                  Text('Достижения', style: t.headlineMedium),
                  const SizedBox(height: S.m),
                  Wrap(
                    spacing: S.s,
                    runSpacing: S.s,
                    children: achievements.map((a) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: S.m, vertical: S.s),
                        constraints: const BoxConstraints(minHeight: S.minTapTarget),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(R.full),
                          color: a.done
                              ? context.cSurfaceLight.withValues(alpha: 0.5)
                              : context.cSurface.withValues(alpha: 0.4),
                          border: Border.all(
                            color: a.done
                                ? C.accent.withValues(alpha: 0.3)
                                : context.cSurfaceBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (a.done)
                              ShaderMask(
                                shaderCallback: (b) => C.gradientPrimary.createShader(b),
                                child: const MIcon(MIconType.check, size: 16, color: Colors.white),
                              )
                            else
                              MIcon(MIconType.lock, size: 16, color: context.cTextDim),
                            const SizedBox(width: S.s),
                            Text(
                              a.title,
                              style: t.bodySmall?.copyWith(
                                color: a.done ? context.cText : context.cTextDim,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ).animate().fadeIn(delay: 250.ms, duration: Anim.normal),

                  const SizedBox(height: S.xxl),

                  // Sign out
                  GlassCard(
                    variant: GlassCardVariant.surface,
                    onTap: _signOut,
                    semanticLabel: 'Выйти из аккаунта',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MIcon(MIconType.logout, size: 20, color: C.error.withValues(alpha: 0.8)),
                        const SizedBox(width: S.s),
                        Text(
                          'Выйти',
                          style: t.titleMedium?.copyWith(color: C.error, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showStreakCelebration)
          Positioned.fill(
            child: StreakCelebration(
              streakDays: _celebratedStreak,
              onDismiss: () => setState(() => _showStreakCelebration = false),
            ),
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.accentColor,
    this.showGlow = false,
  });

  final MIconType icon;
  final int value;
  final String label;
  final Color accentColor;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      variant: GlassCardVariant.surface,
      showGlow: showGlow,
      glowColor: accentColor.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: S.m, vertical: S.m),
      child: SizedBox(
        width: 88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (b) => LinearGradient(colors: [accentColor, accentColor]).createShader(b),
              child: MIcon(icon, size: 20, color: Colors.white),
            ),
            const SizedBox(height: S.s),
            AnimatedNumber(
              value: value,
              style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(label, style: t.bodySmall?.copyWith(color: context.cTextSec)),
          ],
        ),
      ),
    );
  }
}

class _InitialsText extends StatelessWidget {
  const _InitialsText({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: Colors.transparent,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.semanticLabel,
  });

  final MIconType icon;
  final String title;
  final VoidCallback onTap;
  final String? subtitle;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: semanticLabel ?? title,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.m, vertical: S.m),
          child: Row(
            children: [
              ShaderMask(
                shaderCallback: (b) => C.gradientPrimary.createShader(b),
                child: MIcon(icon, size: 22, color: Colors.white),
              ),
              const SizedBox(width: S.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleMedium),
                    if (subtitle != null)
                      Text(subtitle!, style: t.bodySmall?.copyWith(color: context.cTextSec)),
                  ],
                ),
              ),
              MIcon(MIconType.chevronRight, color: context.cTextDim, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
