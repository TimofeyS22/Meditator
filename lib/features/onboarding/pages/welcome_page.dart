import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';
import 'package:meditator/shared/widgets/aura_avatar.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/meditator_illustration.dart';
import 'package:meditator/shared/widgets/onboarding_illustration.dart';
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

class _WelcomePageState extends State<WelcomePage> {
  double _avatarScale = 1.06;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AccessibilityUtils.reduceMotion(context);
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
                  center: const Alignment(0, -0.2),
                  radius: 1.15,
                  colors: [
                    C.primary.withValues(alpha: 0.12),
                    C.accent.withValues(alpha: 0.04),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Center(
                child: OnboardingIllustration(
                  scene: OnboardingScene.welcome,
                  size: 200,
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1, 1),
                      duration: 500.ms,
                      curve: Curves.easeOutCubic,
                    ),
              ),
              const SizedBox(height: S.m),
              SizedBox(
                width: 300,
                height: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const MeditatorIllustration(size: 300),
                    _reduceMotion
                        ? const AuraAvatar(size: 80)
                        : TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.94, end: _avatarScale),
                            duration: const Duration(seconds: 3),
                            curve: Curves.easeInOut,
                            onEnd: () => setState(() {
                              _avatarScale = _avatarScale > 1.0 ? 0.94 : 1.06;
                            }),
                            builder: (_, scale, child) =>
                                Transform.scale(scale: scale, child: child),
                            child: const AuraAvatar(size: 80),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: S.l),
              Text(
                'Meditator',
                textAlign: TextAlign.center,
                style: t.displayLarge,
              )
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .then()
                  .shimmer(
                    duration: 1200.ms,
                    color: C.accent.withValues(alpha: 0.3),
                  ),
              const SizedBox(height: S.m),
              Text(
                'Пространство покоя внутри тебя',
                textAlign: TextAlign.center,
                style: t.bodyLarge?.copyWith(color: C.textSec, height: 1.45),
              ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
              const SizedBox(height: S.s),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  'Персональные практики, дыхание и мягкая поддержка Aura каждый день.',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: C.textDim, height: 1.5),
                ),
              ).animate().fadeIn(delay: 470.ms, duration: 600.ms),
              const Spacer(flex: 2),
              GlowButton(
                onPressed: widget.onStart,
                width: double.infinity,
                showGlow: true,
                semanticLabel: 'Начать онбординг',
                child: const Text('Начать путь'),
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 500.ms)
                  .slideY(
                      begin: 0.15,
                      delay: 500.ms,
                      duration: 500.ms,
                      curve: Anim.curve),
              const SizedBox(height: S.m),
              TextButton(
                onPressed: widget.onHasAccount,
                child: Text(
                  'Уже есть аккаунт',
                  style: t.labelLarge?.copyWith(color: C.textSec),
                ),
              ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
              const SizedBox(height: S.xl),
            ],
          ),
        ),
      ],
    );
  }
}
