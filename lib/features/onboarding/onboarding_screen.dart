import 'package:dio/dio.dart';
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
import 'package:meditator/shared/widgets/aurora_shader_bg.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _page = PageController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  final Set<MeditationGoal> _goals = {};
  StressLevel _stress = StressLevel.moderate;
  PreferredVoice _voice = PreferredVoice.any;
  PreferredDuration _duration = PreferredDuration.min10;
  OnboardingTimeSlot _slot = OnboardingTimeSlot.morning;

  int _index = 0;
  bool _loading = false;
  double _pagePosition = 0.0;

  late final AnimationController _shimmerCtrl;

  static const _pageCount = 5;

  @override
  void initState() {
    super.initState();
    _page.addListener(_onScroll);
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  void _onScroll() {
    setState(() => _pagePosition = _page.page ?? 0.0);
  }

  @override
  void dispose() {
    _page.removeListener(_onScroll);
    _page.dispose();
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _shimmerCtrl.dispose();
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
    if (i == _pageCount - 1) {
      _shimmerCtrl.repeat();
    } else if (_shimmerCtrl.isAnimating) {
      _shimmerCtrl.stop();
      _shimmerCtrl.reset();
    }
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
      final displayName = _name.text.trim().isNotEmpty
          ? _name.text.trim()
          : email.split('@').first;
      await AuthService.instance.signUp(email, pass, displayName: displayName);
      await Db.instance.upsertProfile({
        'display_name': displayName,
        'goals': _goals.map((e) => e.name).toList(),
        'stress_level': _stress.name,
        'preferred_duration': _duration.name,
        'preferred_voice': _voice.jsonName,
        'preferred_time_hour': _slot.suggestedHour,
      });
      await _completeOnboarding();
      if (mounted) context.go('/practice');
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
    if (mounted) context.go('/practice');
  }

  Future<void> _showSignIn() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _SignInSheet(),
    );
    if (ok == true && mounted) context.go('/practice');
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return WelcomePage(onStart: _next, onHasAccount: _showSignIn);
      case 1:
        return GoalsPage(
          selected: _goals,
          onToggle: (g) => setState(() {
            if (_goals.contains(g)) {
              _goals.remove(g);
            } else {
              _goals.add(g);
            }
          }),
        );
      case 2:
        return StressPage(
          selected: _stress,
          onSelect: (s) => setState(() => _stress = s),
        );
      case 3:
        return PrefsPage(
          voice: _voice,
          duration: _duration,
          timeSlot: _slot,
          onVoice: (v) => setState(() => _voice = v),
          onDuration: (d) => setState(() => _duration = d),
          onTimeSlot: (t) => setState(() => _slot = t),
        );
      case 4:
        return FinishPage(
          nameController: _name,
          emailController: _email,
          passwordController: _password,
          onCreateAccount: _signUpAndGo,
          onSkip: _skipAndGo,
          isLoading: _loading,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedProgress =
        (_pagePosition / (_pageCount - 1)).clamp(0.0, 1.0);
    final bgIntensity = 0.3 + 0.4 * normalizedProgress;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBg(
        showStars: true,
        showAurora: true,
        intensity: bgIntensity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: AuroraShaderBg(progress: normalizedProgress),
            ),
            Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _page,
                    physics: const BouncingScrollPhysics(
                      decelerationRate: ScrollDecelerationRate.fast,
                    ),
                    onPageChanged: _onPageChanged,
                    children: List.generate(_pageCount, (i) {
                      final distance = (_pagePosition - i).abs();
                      final opacity =
                          (1.0 - distance * 0.4).clamp(0.0, 1.0);
                      final scale =
                          (1.0 - distance * 0.05).clamp(0.95, 1.0);
                      return Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity,
                          child: _buildPage(i),
                        ),
                      );
                    }),
                  ),
                ),
                _buildBottomArea(),
              ],
            ),
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
          AnimatedSwitcher(
            duration: Anim.normal,
            switchInCurve: Anim.curve,
            switchOutCurve: Anim.curve,
            child: _index > 0 && _index < 4
                ? Padding(
                    key: const ValueKey('nav_mid'),
                    padding: const EdgeInsets.only(bottom: S.m),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: _prev,
                          style: TextButton.styleFrom(
                            minimumSize:
                                const Size(S.minTapTarget, S.minTapTarget),
                            tapTargetSize: MaterialTapTargetSize.padded,
                          ),
                          icon: MIcon(MIconType.arrowBack,
                              size: 16, color: context.cTextSec),
                          label: Text('Назад',
                              style:
                                  TextStyle(color: context.cTextSec, fontSize: 15)),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _next,
                          style: TextButton.styleFrom(
                            minimumSize:
                                const Size(S.minTapTarget, S.minTapTarget),
                            tapTargetSize: MaterialTapTargetSize.padded,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Далее',
                                  style: TextStyle(
                                      color: C.accent,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15)),
                              const SizedBox(width: 4),
                              MIcon(MIconType.arrowForward,
                                  size: 16, color: C.accent),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : _index == 4
                    ? Padding(
                        key: const ValueKey('nav_last'),
                        padding: const EdgeInsets.only(bottom: S.m),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _prev,
                            style: TextButton.styleFrom(
                              minimumSize:
                                  const Size(S.minTapTarget, S.minTapTarget),
                              tapTargetSize: MaterialTapTargetSize.padded,
                            ),
                            icon: MIcon(MIconType.arrowBack,
                                size: 16, color: context.cTextSec),
                            label: Text('Назад',
                                style: TextStyle(
                                    color: context.cTextSec, fontSize: 15)),
                          ),
                        ),
                      )
                    : const SizedBox(
                        key: ValueKey('nav_welcome'),
                        height: S.m,
                      ),
          ),
          _buildProgressLine(),
          const SizedBox(height: S.s),
        ],
      ),
    );
  }

  Widget _buildProgressLine() {
    final isLastPage = _index == _pageCount - 1;
    final fraction =
        (_pagePosition / (_pageCount - 1)).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final fillWidth = totalWidth * fraction;

        return SizedBox(
          height: 12,
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: totalWidth,
                height: 4,
                decoration: BoxDecoration(
                  color: context.cTextDim.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(R.full),
                ),
              ),
              Container(
                width: fillWidth,
                height: 4,
                decoration: BoxDecoration(
                  gradient: fillWidth > 0 ? C.gradientPrimary : null,
                  borderRadius: BorderRadius.circular(R.full),
                  boxShadow: fillWidth > 0
                      ? [
                          BoxShadow(
                            color: C.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
              if (fillWidth > 4)
                Positioned(
                  left: fillWidth - 3,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.9),
                      boxShadow: [
                        BoxShadow(
                          color: C.accent.withValues(alpha: 0.8),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              if (isLastPage)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _shimmerCtrl,
                    builder: (context, _) {
                      return Align(
                        alignment: Alignment(
                          -1.0 + 2.0 * _shimmerCtrl.value,
                          0.0,
                        ),
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(R.full),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.35),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SignInSheet extends StatefulWidget {
  const _SignInSheet();

  @override
  State<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<_SignInSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Введите почту и пароль');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signIn(email, pass);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done', true);
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data as Map)['detail']?.toString()
          : null;
      setState(() => _error = msg ?? 'Неверная почта или пароль');
    } catch (_) {
      setState(() => _error = 'Не удалось подключиться к серверу');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _dec(String hint, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.cTextDim),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.m),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.m),
          borderSide: const BorderSide(color: C.accent, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: S.m, vertical: S.m),
        suffixIcon: suffix,
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(R.xl)),
      ),
      padding: EdgeInsets.only(
        left: S.l,
        right: S.l,
        top: S.l,
        bottom: MediaQuery.viewInsetsOf(context).bottom + S.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: S.l),
          Text('С возвращением', style: t.headlineMedium),
          const SizedBox(height: S.xs),
          Text('Войдите в свой аккаунт',
              style: t.bodyMedium?.copyWith(color: context.cTextDim)),
          const SizedBox(height: S.l),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: context.cText),
            decoration: _dec('Эл. почта'),
          ),
          const SizedBox(height: S.m),
          TextField(
            controller: _password,
            obscureText: !_showPassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: TextStyle(color: context.cText),
            decoration: _dec('Пароль',
                suffix: GestureDetector(
                  onTap: () =>
                      setState(() => _showPassword = !_showPassword),
                  child: Padding(
                    padding: const EdgeInsets.all(S.m),
                    child: MIcon(
                      _showPassword ? MIconType.close : MIconType.lock,
                      size: 20,
                      color: context.cTextDim,
                    ),
                  ),
                )),
          ),
          if (_error != null) ...[
            const SizedBox(height: S.s),
            Text(_error!,
                style: t.bodySmall?.copyWith(color: C.error),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: S.l),
          SizedBox(
            height: 52,
            child: AnimatedContainer(
              duration: Anim.fast,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(R.m),
                gradient: _loading ? null : C.gradientPrimary,
                color: _loading
                    ? Colors.white.withValues(alpha: 0.1)
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _loading ? null : _submit,
                  borderRadius: BorderRadius.circular(R.m),
                  child: Center(
                    child: _loading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.cText,
                            ),
                          )
                        : Text('Войти',
                            style: t.labelLarge
                                ?.copyWith(color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: S.m),
          TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context),
            child:
                Text('Закрыть', style: t.bodyMedium?.copyWith(color: context.cTextDim)),
          ),
        ],
      ),
    );
  }
}
