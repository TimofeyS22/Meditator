import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/subscription/subscription_service.dart';
import 'package:meditator/shared/utils/accessibility.dart';
import 'package:meditator/shared/utils/error_handler.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _annual = true;
  bool _loading = false;

  static const _features = [
    'AI-медитации от Aura',
    'Безлимитный доступ к библиотеке',
    'Детальная аналитика настроения',
  ];

  Future<void> _subscribe() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final plan = _annual ? 'annual' : 'monthly';
      final url = await SubscriptionService.instance.createPayment(plan);
      if (url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          SubscriptionService.instance.startPolling();
        }
      }
    } on DioException catch (e) {
      if (mounted) AppError.showDio(e);
    } catch (_) {
      if (mounted) AppError.show('Не удалось создать платёж. Попробуйте позже.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    final titleStyle = theme.textTheme.displayMedium?.copyWith(
      color: Colors.white,
      height: 1.1,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBg(
        showAurora: true,
        intensity: 0.8,
        child: Stack(
          children: [
            Positioned(
              top: S.xs,
              right: S.xs,
              child: IconButton(
                onPressed: () => context.pop(),
                tooltip: 'Закрыть',
                icon: MIcon(MIconType.close, size: 24, color: context.cTextSec),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(S.m, S.xxl + S.m, S.m, S.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShaderMask(
                    shaderCallback: (b) => C.gradientGold.createShader(b),
                    child: Text(
                      'Meditator\nPremium',
                      textAlign: TextAlign.center,
                      style: titleStyle,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: AccessibilityUtils.adjustedDuration(context, Anim.slow))
                      .scaleXY(
                        begin: reduceMotion ? 1 : 0.92,
                        end: 1,
                        duration: AccessibilityUtils.adjustedDuration(context, Anim.slow),
                        curve: Anim.curve,
                      ),

                  const SizedBox(height: S.xl),

                  ...List.generate(_features.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: S.m),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (b) =>
                                C.gradientPrimary.createShader(b),
                            child: const MIcon(MIconType.check, size: 22, color: Colors.white),
                          ),
                          const SizedBox(width: S.s),
                          Expanded(
                            child: Text(
                              _features[i],
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: context.cText,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(
                          delay: (100 + i * 80).ms,
                          duration: Anim.normal,
                        )
                        .slideY(
                          begin: 0.12,
                          end: 0,
                          delay: (100 + i * 80).ms,
                          duration: Anim.normal,
                          curve: Anim.curve,
                        );
                  }),

                  const SizedBox(height: S.l),

                  _PriceCard(
                    title: 'Месяц',
                    price: '299 ₽/мес',
                    selected: !_annual,
                    onTap: () => setState(() => _annual = false),
                  ),
                  const SizedBox(height: S.m),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _PriceCard(
                        title: 'Год',
                        price: '1 990 ₽/год',
                        selected: _annual,
                        onTap: () => setState(() => _annual = true),
                        highlight: true,
                      ),
                      Positioned(
                        top: -10,
                        right: 12,
                        child: (reduceMotion
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: S.s,
                                  vertical: S.xs,
                                ),
                                decoration: BoxDecoration(
                                  gradient: C.gradientGold,
                                  borderRadius: BorderRadius.circular(R.s),
                                ),
                                child: Text(
                                  'Экономия 65%',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: C.bg,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              )
                            : Shimmer.fromColors(
                                baseColor: C.gold,
                                highlightColor: C.accentLight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: S.s,
                                    vertical: S.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: C.gradientGold,
                                    borderRadius: BorderRadius.circular(R.s),
                                  ),
                                  child: Text(
                                    'Экономия 65%',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: C.bg,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              )),
                      ),
                    ],
                  ),

                  const SizedBox(height: S.xl),

                  GlowButton(
                    variant: GlowButtonVariant.primary,
                    onPressed: _loading ? null : _subscribe,
                    width: double.infinity,
                    showGlow: !_loading,
                    semanticLabel: 'Активировать пробный премиум на 7 дней',
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Попробовать бесплатно — 7 дней'),
                  )
                      .animate()
                      .fadeIn(
                        delay: 700.ms,
                        duration: AccessibilityUtils.adjustedDuration(context, Anim.normal),
                      )
                      .slideY(
                        begin: reduceMotion ? 0 : 0.08,
                        end: 0,
                        delay: 700.ms,
                        duration: AccessibilityUtils.adjustedDuration(context, Anim.normal),
                      ),

                  const SizedBox(height: S.m),

                  Text(
                    'Отмена в любое время',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.cTextSec,
                      height: 1.4,
                    ),
                  ).animate().fadeIn(delay: 780.ms, duration: Anim.normal),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.title,
    required this.price,
    required this.selected,
    required this.onTap,
    this.highlight = false,
  });

  final String title;
  final String price;
  final bool selected;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      variant: selected ? GlassCardVariant.glass : GlassCardVariant.surface,
      onTap: onTap,
      showGlow: selected,
      glowColor: highlight ? C.gold.withValues(alpha: 0.4) : C.glowPrimary,
      showBorder: selected,
      opacity: selected ? 0.12 : 0.08,
      semanticLabel: '$title, $price${selected ? ', выбран тариф' : ''}',
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? C.primary : context.cTextDim,
          ),
          const SizedBox(width: S.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.cText,
                  ),
                ),
                const SizedBox(height: S.xs),
                Text(
                  price,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: highlight && selected ? C.accent : context.cTextSec,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
