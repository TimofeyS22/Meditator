import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/features/onboarding/pages/finish_page.dart';
import 'package:meditator/features/onboarding/pages/goals_page.dart';
import 'package:meditator/features/onboarding/pages/prefs_page.dart';
import 'package:meditator/features/onboarding/pages/stress_page.dart';
import 'package:meditator/features/onboarding/pages/welcome_page.dart';
import 'package:meditator/shared/models/user_profile.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _page = PageController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  final Set<MeditationGoal> _goals = {};
  StressLevel _stress = StressLevel.moderate;
  PreferredVoice _voice = PreferredVoice.any;
  PreferredDuration _duration = PreferredDuration.min10;
  OnboardingTimeSlot _slot = OnboardingTimeSlot.morning;

  int _index = 0;
  bool _loading = false;

  @override
  void dispose() {
    _page.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index == 1 && _goals.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выбери хотя бы одну цель')),
        );
      }
      return;
    }
    await _page.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _prev() async {
    await _page.previousPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onPageChanged(int i) {
    if (i > 1 && _goals.isEmpty) {
      _page.jumpToPage(1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сначала выбери цели')),
        );
      }
      return;
    }
    setState(() => _index = i);
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
  }

  Future<void> _signUpAndGo() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (email.isEmpty || pass.length < 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Введи почту и пароль не короче 6 символов')),
        );
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await AuthService.instance.signUp(email, pass);
      final uid = res.user?.id;
      if (uid != null) {
        await Db.instance.upsertProfile({
          'id': uid,
          'email': email,
          'display_name': email.split('@').first,
          'goals': _goals.map((e) => e.name).toList(),
          'stress_level': _stress.name,
          'preferred_duration': _duration.name,
          'preferred_voice': _voice.jsonName,
          'preferred_time_hour': _slot.suggestedHour,
        });
      }
      await _completeOnboarding();
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось создать аккаунт: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _skipAndGo() async {
    await _completeOnboarding();
    if (mounted) context.go('/home');
  }

  Future<void> _showSignIn() async {
    final em = TextEditingController();
    final pw = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: S.l,
            right: S.l,
            top: S.l,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + S.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Вход',
                  style: Theme.of(ctx)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: C.text)),
              const SizedBox(height: S.m),
              TextField(
                controller: em,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'Эл. почта'),
              ),
              const SizedBox(height: S.m),
              TextField(
                controller: pw,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Пароль'),
              ),
              const SizedBox(height: S.l),
              FilledButton(
                onPressed: () async {
                  try {
                    await AuthService.instance
                        .signIn(em.text.trim(), pw.text);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('onboarding_done', true);
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Ошибка входа: $e')),
                      );
                    }
                  }
                },
                child: const Text('Войти'),
              ),
              const SizedBox(height: S.s),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        );
      },
    );
    em.dispose();
    pw.dispose();
    if (ok == true && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBg(
        showStars: true,
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _page,
                physics: const BouncingScrollPhysics(),
                onPageChanged: _onPageChanged,
                children: [
                  WelcomePage(
                    onStart: _next,
                    onHasAccount: _showSignIn,
                  ),
                  GoalsPage(
                    selected: _goals,
                    onToggle: (g) => setState(() {
                      if (_goals.contains(g)) {
                        _goals.remove(g);
                      } else {
                        _goals.add(g);
                      }
                    }),
                  ),
                  StressPage(
                    selected: _stress,
                    onSelect: (s) => setState(() => _stress = s),
                  ),
                  PrefsPage(
                    voice: _voice,
                    duration: _duration,
                    timeSlot: _slot,
                    onVoice: (v) => setState(() => _voice = v),
                    onDuration: (d) => setState(() => _duration = d),
                    onTimeSlot: (t) => setState(() => _slot = t),
                  ),
                  FinishPage(
                    emailController: _email,
                    passwordController: _password,
                    onCreateAccount: _signUpAndGo,
                    onSkip: _skipAndGo,
                    isLoading: _loading,
                  ),
                ],
              ),
            ),
            _buildBottomArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.l, S.xs, S.l, S.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_index > 0 && _index < 4)
            Padding(
              padding: const EdgeInsets.only(bottom: S.m),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _prev,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 14, color: C.textSec),
                    label: Text('Назад',
                        style: TextStyle(color: C.textSec, fontSize: 15)),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _next,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Далее',
                            style: TextStyle(
                                color: C.accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: C.accent),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (_index == 4)
            Padding(
              padding: const EdgeInsets.only(bottom: S.m),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _prev,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 14, color: C.textSec),
                  label: Text('Назад',
                      style: TextStyle(color: C.textSec, fontSize: 15)),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final isActive = i == _index;
              return AnimatedContainer(
                duration: Anim.normal,
                curve: Anim.curve,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(R.full),
                  gradient: isActive ? C.gradientPrimary : null,
                  color: isActive ? null : C.textDim.withValues(alpha: 0.3),
                ),
              );
            }),
          ),
          const SizedBox(height: S.s),
        ],
      ),
    );
  }
}
