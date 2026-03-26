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
import 'package:meditator/shared/widgets/morphing_blob.dart';
import 'package:meditator/shared/widgets/progress_arc.dart';
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
    final streak = prof?.currentStreak ?? 0;
    final milestones = [3, 7, 14, 30, 60, 100, 365];
    if (milestones.contains(streak) && streak > _celebratedStreak) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _showStreakCelebration = true;
            _celebratedStreak = streak;
          });
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
        child: const Center(child: CircularProgressIndicator(color: C.primary)),
      );
    }

    final profile = _profile!;
    final theme = Theme.of(context);
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(S.m, S.m, S.m, S.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            Row(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MorphingBlob(size: 80, color: C.primary),
                      ClipOval(
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: profile.avatarUrl != null &&
                                  profile.avatarUrl!.isNotEmpty
                              ? Image.network(
                                  profile.avatarUrl!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _InitialsText(
                                    initials: _initials(
                                        displayName == 'Медитатор'
                                            ? null
                                            : displayName),
                                  ),
                                )
                              : _InitialsText(
                                  initials: _initials(
                                      displayName == 'Медитатор'
                                          ? null
                                          : displayName),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: S.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.displayMedium,
                      ),
                      if (profile.email.isNotEmpty) ...[
                        const SizedBox(height: S.xs),
                        Text(
                          profile.email,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: C.textSec),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            )
                .animate()
                .fadeIn(duration: Anim.normal)
                .slideX(begin: 0.04, end: 0, duration: Anim.normal),

            const SizedBox(height: S.xl),

            Text('Статистика',
                style: theme.textTheme.headlineMedium),
            const SizedBox(height: S.m),

            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    showGlow: streakFire,
                    glowColor: C.gold,
                    semanticLabel: 'Всего сессий ${profile.totalSessions}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) =>
                              C.gradientPrimary.createShader(b),
                          child: const MIcon(MIconType.meditation,
                              size: 24, color: Colors.white),
                        ),
                        const SizedBox(height: S.s),
                        AnimatedNumber(
                          value: profile.totalSessions,
                          style: theme.textTheme.headlineLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text('Сессии',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: C.textSec)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: S.s),
                Expanded(
                  child: GlassCard(
                    semanticLabel: 'Всего минут ${profile.totalMinutes}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) =>
                              C.gradientPrimary.createShader(b),
                          child: const MIcon(MIconType.timer,
                              size: 24, color: Colors.white),
                        ),
                        const SizedBox(height: S.s),
                        AnimatedNumber(
                          value: profile.totalMinutes,
                          style: theme.textTheme.headlineLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text('Минуты',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: C.textSec)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: S.s),
                Expanded(
                  child: GlassCard(
                    showGlow: streakFire,
                    glowColor: C.gold,
                    semanticLabel: 'Текущая серия ${profile.currentStreak} дней',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => (streakFire
                                  ? C.gradientGold
                                  : C.gradientPrimary)
                              .createShader(b),
                          child: streakFire
                              ? const MIcon(MIconType.fire,
                                  size: 24, color: Colors.white)
                              : const MIcon(MIconType.bolt,
                                  size: 24, color: Colors.white),
                        ),
                        const SizedBox(height: S.s),
                        AnimatedNumber(
                          value: profile.currentStreak,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: streakFire ? C.gold : null,
                          ),
                          suffix: streakFire ? ' 🔥' : null,
                        ),
                        Text('Серия',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: C.textSec)),
                      ],
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 80.ms, duration: Anim.normal),

            const SizedBox(height: S.xl),

            Text('Уровень', style: theme.textTheme.headlineMedium),
            const SizedBox(height: S.m),
            GlassCard(
              semanticLabel:
                  'Уровень ${level.title}, прогресс ${(level.progress * 100).round()}%',
              child: Row(
                children: [
                  ProgressArc(
                    progress: level.progress.clamp(0.0, 1.0),
                    size: 92,
                    strokeWidth: 6,
                    child: Text(
                      '${profile.totalSessions}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: S.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(level.title,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: S.xs),
                        Text(
                          'Aura: чем стабильнее практика, тем глубже калибровка медитаций под тебя.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: C.textSec, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 120.ms, duration: Anim.normal),

            const SizedBox(height: S.xl),

            Text('Меню', style: theme.textTheme.headlineMedium),
            const SizedBox(height: S.s),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _MenuRow(
                    icon: const MIcon(MIconType.settings,
                        size: 22, color: Colors.white),
                    title: 'Настройки',
                    onTap: () => context.push('/settings'),
                    semanticLabel: 'Открыть настройки',
                  ),
                  const Divider(height: 1, color: C.surfaceBorder),
                  _MenuRow(
                    icon: const MIcon(MIconType.premium,
                        size: 22, color: Colors.white),
                    title: 'Подписка',
                    onTap: () async {
                      await context.push('/paywall');
                      await _load();
                    },
                    semanticLabel: 'Открыть подписку',
                  ),
                  const Divider(height: 1, color: C.surfaceBorder),
                  _MenuRow(
                    icon: const MIcon(MIconType.heart,
                        size: 22, color: Colors.white),
                    title: 'Мой партнёр',
                    onTap: () => context.push('/pair'),
                    semanticLabel: 'Открыть экран партнёра',
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 160.ms, duration: Anim.normal)
                .slideY(begin: 0.03, end: 0, duration: Anim.normal),

            const SizedBox(height: S.xl),

            Text('Достижения', style: theme.textTheme.headlineMedium),
            const SizedBox(height: S.m),
            Wrap(
              spacing: S.s,
              runSpacing: S.s,
              children: achievements.map((a) {
                return Chip(
                  avatar: a.done
                      ? ShaderMask(
                          shaderCallback: (b) =>
                              C.gradientPrimary.createShader(b),
                          child: const MIcon(MIconType.check,
                              size: 18, color: Colors.white),
                        )
                      : const MIcon(MIconType.lock,
                          size: 18, color: C.textDim),
                  label: Text(a.title),
                  backgroundColor:
                      a.done ? C.surfaceLight : C.surface,
                  side: BorderSide(
                    color: a.done
                        ? C.accent.withValues(alpha: 0.35)
                        : C.surfaceBorder,
                  ),
                  labelStyle: TextStyle(
                    color: a.done ? C.text : C.textDim,
                    fontSize: 13,
                  ),
                );
              }).toList(),
            ).animate().fadeIn(delay: 200.ms, duration: Anim.normal),

            const SizedBox(height: S.xxl),

            GlassCard(
              onTap: _signOut,
              semanticLabel: 'Выйти из аккаунта',
              opacity: 0.06,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MIcon(MIconType.logout,
                      size: 20,
                      color: C.error.withValues(alpha: 0.8)),
                  const SizedBox(width: S.s),
                  Text(
                    'Выйти',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: C.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    this.semanticLabel,
  });

  final Widget icon;
  final String title;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
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
                child: icon,
              ),
              const SizedBox(width: S.m),
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              const Icon(Icons.chevron_right_rounded, color: C.textDim),
            ],
          ),
        ),
      ),
    );
  }
}
