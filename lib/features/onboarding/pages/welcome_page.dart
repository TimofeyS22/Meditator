import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';
import 'package:meditator/shared/widgets/aura_avatar.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/particle_field.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({
    super.key,
    required this.onStart,
    required this.onHasAccount,
  });

  final VoidCallback onStart;
  final VoidCallback onHasAccount;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breatheCtrl;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rm = AccessibilityUtils.reduceMotion(context);
    if (_reduceMotion != rm) {
      _reduceMotion = rm;
      if (_reduceMotion) {
        _breatheCtrl.stop();
      } else if (!_breatheCtrl.isAnimating) {
        _breatheCtrl.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  radius: 1.0,
                  colors: [
                    C.primary.withValues(alpha: 0.14),
                    C.accent.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: ParticleField(count: 60, twinkle: true),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.l),
          child: Column(
            children: [
              const Spacer(flex: 3),
              AnimatedBuilder(
                animation: _breatheCtrl,
                builder: (context, child) {
                  final breathe = _reduceMotion ? 0.5 : _breatheCtrl.value;
                  final scale = 1.0 + 0.04 * breathe;
                  final glowAlpha = 0.15 + 0.12 * breathe;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: C.primary.withValues(alpha: glowAlpha),
                            blurRadius: 50 + 20 * breathe,
                            spreadRadius: 10 + 10 * breathe,
                          ),
                          BoxShadow(
                            color: C.accent.withValues(alpha: glowAlpha * 0.6),
                            blurRadius: 30 + 15 * breathe,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  );
                },
                child: const AuraAvatar(size: 120),
              )
                  .animate()
                  .fadeIn(duration: 800.ms, curve: Curves.easeOut)
                  .scale(
                    begin: const Offset(0.7, 0.7),
                    end: const Offset(1, 1),
                    duration: 800.ms,
                    curve: Curves.easeOutCubic,
                  ),
              const SizedBox(height: S.xxl),
              Text(
                'Meditator',
                textAlign: TextAlign.center,
                style: t.displayLarge,
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 600.ms)
                  .then()
                  .shimmer(
                    duration: 1200.ms,
                    color: C.accent.withValues(alpha: 0.3),
                  ),
              const SizedBox(height: S.m),
              Text(
                'Пространство покоя внутри тебя',
                textAlign: TextAlign.center,
                style: t.bodyLarge?.copyWith(color: context.cTextSec, height: 1.45),
              ).animate().fadeIn(delay: 500.ms, duration: 600.ms),
              const SizedBox(height: S.s),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  'Персональные практики, дыхание и мягкая поддержка Aura каждый день.',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: context.cTextDim, height: 1.5),
                ),
              ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
              const Spacer(flex: 3),
              GlowButton(
                onPressed: widget.onStart,
                width: double.infinity,
                showGlow: true,
                semanticLabel: 'Начать онбординг',
                child: const Text('Начать путь'),
              )
                  .animate()
                  .fadeIn(delay: 700.ms, duration: 500.ms)
                  .slideY(
                    begin: 0.15,
                    delay: 700.ms,
                    duration: 500.ms,
                    curve: Anim.curve,
                  ),
              const SizedBox(height: S.m),
              TextButton(
                onPressed: widget.onHasAccount,
                child: Text(
                  'Уже есть аккаунт',
                  style: t.labelLarge?.copyWith(color: context.cTextSec),
                ),
              ).animate().fadeIn(delay: 800.ms, duration: 400.ms),
              const SizedBox(height: S.xl),
            ],
          ),
        ),
      ],
    );
  }
}
