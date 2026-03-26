import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/onboarding_illustration.dart';

class FinishPage extends StatefulWidget {
  const FinishPage({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.onCreateAccount,
    required this.onSkip,
    required this.isLoading,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onCreateAccount;
  final VoidCallback onSkip;
  final bool isLoading;

  @override
  State<FinishPage> createState() => _FinishPageState();
}

class _FinishPageState extends State<FinishPage> {
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _emailFocused = false;
  bool _passwordFocused = false;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(_onEmailFocusChange);
    _passwordFocus.addListener(_onPasswordFocusChange);
  }

  void _onEmailFocusChange() =>
      setState(() => _emailFocused = _emailFocus.hasFocus);

  void _onPasswordFocusChange() =>
      setState(() => _passwordFocused = _passwordFocus.hasFocus);

  @override
  void dispose() {
    _emailFocus.removeListener(_onEmailFocusChange);
    _passwordFocus.removeListener(_onPasswordFocusChange);
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(S.l, S.xl, S.l, S.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: OnboardingIllustration(
              scene: OnboardingScene.finish,
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
          Text(
            'Последний шаг',
            style: t.displayMedium,
          ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.05),
          const SizedBox(height: S.m),
          Text(
            'Создай аккаунт, чтобы сохранить прогресс, или продолжи как гость.',
            style: t.bodyMedium?.copyWith(color: C.textDim, height: 1.45),
          ).animate().fadeIn(delay: 90.ms, duration: 400.ms),
          const SizedBox(height: S.l),
          _buildGradientField(
            controller: widget.emailController,
            focusNode: _emailFocus,
            isFocused: _emailFocused,
            hint: 'Эл. почта',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            delay: 140,
          ),
          const SizedBox(height: S.m),
          _buildGradientField(
            controller: widget.passwordController,
            focusNode: _passwordFocus,
            isFocused: _passwordFocused,
            hint: 'Пароль',
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            delay: 200,
          ),
          const SizedBox(height: S.l),
          GlowButton(
            onPressed: widget.isLoading ? null : widget.onCreateAccount,
            width: double.infinity,
            isLoading: widget.isLoading,
            showGlow: true,
            semanticLabel: 'Создать аккаунт',
            child: const Text('Создать аккаунт'),
          ).animate().fadeIn(delay: 260.ms, duration: 400.ms),
          const SizedBox(height: S.m),
          Center(
            child: TextButton(
              onPressed: widget.isLoading ? null : widget.onSkip,
              child: Text(
                'Пропустить',
                style: t.labelLarge?.copyWith(color: C.textDim),
              ),
            ),
          ).animate().fadeIn(delay: 320.ms, duration: 350.ms),
        ],
      ),
    );
  }

  Widget _buildGradientField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required String hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    required List<String> autofillHints,
    required int delay,
  }) {
    return AnimatedContainer(
      duration: Anim.fast,
      curve: Anim.curve,
      decoration: BoxDecoration(
        gradient: isFocused ? C.gradientPrimary : null,
        borderRadius: BorderRadius.circular(R.m),
      ),
      padding: const EdgeInsets.all(1.5),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
        autofillHints: autofillHints,
        style: const TextStyle(color: C.text),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: C.surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(R.m - 1.5),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(R.m - 1.5),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(R.m - 1.5),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: C.textDim),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: delay.ms, duration: 400.ms)
        .slideY(begin: 0.04);
  }
}
