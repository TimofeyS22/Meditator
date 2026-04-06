import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/shared/theme/cosmic.dart';
import 'package:meditator/shared/widgets/cosmic_background.dart';
import 'package:meditator/shared/widgets/particle_field.dart';
import 'package:meditator/shared/widgets/cosmic_button.dart';
import 'package:meditator/shared/widgets/glass_card.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final CurvedAnimation _enterCurved;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _enterCurved = CurvedAnimation(parent: _enterCtrl, curve: Anim.curve);
  }

  @override
  void dispose() {
    _enterCurved.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Cosmic.bg,
      body: CosmicBackground(
        intensity: 1.2,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ParticleField(count: 40, color: Cosmic.warm),
            ),
            SafeArea(
              child: AnimatedBuilder(
                animation: _enterCtrl,
                builder: (_, __) {
                  final val = _enterCurved.value;
                  return Opacity(
                    opacity: val,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: Space.sm),
                              child: IconButton(
                                onPressed: () => context.pop(),
                                icon: const Icon(Icons.close_rounded, color: Cosmic.textMuted),
                              ),
                            ),
                          ),

                          const SizedBox(height: Space.xxl),

                          // Premium badge
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: Cosmic.gradientWarm,
                              boxShadow: [
                                BoxShadow(
                                  color: Cosmic.warm.withValues(alpha: 0.4),
                                  blurRadius: 40,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: Space.xl),

                          Text(
                            'У Aura есть\nбольше для тебя',
                            style: t.displayMedium,
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: Space.md),

                          Text(
                            'Раскрой полный потенциал практики',
                            style: t.bodyLarge?.copyWith(color: Cosmic.textMuted),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: Space.xl),

                          // Features
                          _PremiumFeature(
                            icon: Icons.all_inclusive_rounded,
                            title: 'Безлимитные сессии',
                            subtitle: 'Без ограничений, когда тебе нужно',
                            color: Cosmic.primary,
                          ),
                          const SizedBox(height: Space.sm),
                          _PremiumFeature(
                            icon: Icons.auto_awesome_rounded,
                            title: 'Полная Aura',
                            subtitle: 'Глубокие инсайты, память, голос',
                            color: Cosmic.accent,
                          ),
                          const SizedBox(height: Space.sm),
                          _PremiumFeature(
                            icon: Icons.bedtime_rounded,
                            title: 'Истории для сна',
                            subtitle: 'Засыпай под голос Aura',
                            color: Cosmic.warm,
                          ),

                          const SizedBox(height: Space.xxl),

                          CosmicButton(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              // RevenueCat integration point
                              context.pop();
                            },
                            width: double.infinity,
                            gradient: Cosmic.gradientWarm,
                            child: const Text('Попробовать бесплатно · 7 дней'),
                          ),

                          const SizedBox(height: Space.md),

                          Text(
                            'Затем 299₽/мес · Отмена в любое время',
                            style: t.bodySmall?.copyWith(color: Cosmic.textDim),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: Space.lg),

                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Text(
                              'Восстановить покупки',
                              style: t.bodySmall?.copyWith(
                                color: Cosmic.textMuted,
                                decoration: TextDecoration.underline,
                                decorationColor: Cosmic.textDim,
                              ),
                            ),
                          ),

                          const SizedBox(height: Space.xl),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumFeature extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;

  const _PremiumFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 14),
      opacity: 0.06,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: t.bodySmall?.copyWith(color: Cosmic.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
