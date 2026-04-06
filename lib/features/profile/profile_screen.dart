import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/core/aura/aura_engine.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/core/cosmos/cosmos_state.dart';
import 'package:meditator/shared/theme/cosmic.dart';
import 'package:meditator/shared/widgets/cosmic_background.dart';
import 'package:meditator/shared/widgets/glass_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enterCtrl;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final aura = ref.watch(auraProvider);
    final auth = ref.watch(authProvider);
    final isLoggedIn = auth.status == AuthStatus.authenticated;

    return Scaffold(
      backgroundColor: Cosmic.bg,
      body: CosmicBackground(
        intensity: 0.4,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _enterCtrl,
            builder: (_, __) {
              final val =
                  CurvedAnimation(parent: _enterCtrl, curve: Anim.curve).value;

              return Opacity(
                opacity: val,
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: Space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: Space.sm),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: const Icon(Icons.arrow_back_rounded,
                                  color: Cosmic.text),
                            ),
                            const Spacer(),
                            Text('Профиль', style: t.titleLarge),
                            const Spacer(),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),

                      const SizedBox(height: Space.xl),

                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: Cosmic.gradientPrimary,
                            boxShadow: [
                              BoxShadow(
                                  color: Cosmic.glowPrimary,
                                  blurRadius: 20),
                            ],
                          ),
                          child: const Icon(Icons.person_rounded,
                              size: 40, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: Space.lg),

                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              value: '${aura.totalSessions}',
                              label: 'Сессий',
                              icon: Icons.self_improvement_rounded,
                              color: Cosmic.primary,
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: _StatCard(
                              value: '${aura.streak}',
                              label: 'Дней подряд',
                              icon: Icons.local_fire_department_rounded,
                              color: Cosmic.warm,
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: _StatCard(
                              value: '${aura.moodHistory.length}',
                              label: 'Чекинов',
                              icon: Icons.timeline_rounded,
                              color: Cosmic.accent,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: Space.xl),

                      Builder(builder: (context) {
                        final cosmos = ref.watch(cosmosStateProvider);
                        final stage = cosmos.stage;
                        final progress = (cosmos.evolutionLevel / 50).clamp(0.0, 1.0);
                        return GlassCard(
                          padding: const EdgeInsets.all(Space.md),
                          opacity: 0.06,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Твоя вселенная', style: t.titleMedium),
                                  Text(
                                    stage.label,
                                    style: t.bodySmall?.copyWith(
                                      color: Cosmic.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: Space.sm),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: Cosmic.surfaceLight,
                                  color: Cosmic.primary,
                                ),
                              ),
                              const SizedBox(height: Space.sm),
                              Text(
                                '${cosmos.starCount} звёзд · ${aura.totalSessions} сессий',
                                style: t.bodySmall?.copyWith(color: Cosmic.textDim),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: Space.xl),

                      if (!isLoggedIn) ...[
                        GlassCard(
                          onTap: () => context.go('/onboarding'),
                          padding: const EdgeInsets.all(Space.md),
                          opacity: 0.06,
                          child: Row(
                            children: [
                              Icon(Icons.cloud_sync_rounded,
                                  color: Cosmic.accent, size: 24),
                              const SizedBox(width: Space.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Синхронизация',
                                        style: t.titleMedium),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Войди, чтобы сохранить прогресс',
                                      style: t.bodySmall?.copyWith(
                                          color: Cosmic.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  color: Cosmic.textDim, size: 20),
                            ],
                          ),
                        ),
                        const SizedBox(height: Space.md),
                      ],

                      Text('Настройки',
                          style: t.titleMedium
                              ?.copyWith(color: Cosmic.textDim)),
                      const SizedBox(height: Space.md),

                      _SettingsTile(
                        icon: Icons.notifications_rounded,
                        label: 'Напоминания',
                        onTap: () {},
                      ),
                      const SizedBox(height: Space.sm),
                      _SettingsTile(
                        icon: Icons.workspace_premium_rounded,
                        label: 'Подписка',
                        color: Cosmic.warm,
                        onTap: () => context.push('/paywall'),
                      ),
                      const SizedBox(height: Space.sm),
                      _SettingsTile(
                        icon: Icons.info_outline_rounded,
                        label: 'О приложении',
                        onTap: () {},
                      ),

                      if (isLoggedIn) ...[
                        const SizedBox(height: Space.sm),
                        _SettingsTile(
                          icon: Icons.logout_rounded,
                          label: 'Выйти',
                          color: Cosmic.rose,
                          onTap: () {
                            ref.read(authProvider.notifier).logout();
                          },
                        ),
                      ],

                      const SizedBox(height: Space.xxl),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

}

class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.all(Space.md),
      opacity: 0.06,
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: Space.sm),
          Text(value, style: t.headlineLarge?.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: t.bodySmall?.copyWith(fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.color = Cosmic.textMuted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      padding:
          const EdgeInsets.symmetric(horizontal: Space.md, vertical: 14),
      opacity: 0.05,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: Space.md),
          Expanded(child: Text(label, style: t.titleMedium)),
          const Icon(Icons.chevron_right_rounded,
              color: Cosmic.textDim, size: 20),
        ],
      ),
    );
  }
}
