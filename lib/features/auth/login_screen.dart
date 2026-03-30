import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  bool _isRegister = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Введите почту и пароль');
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _error = 'Некорректный формат почты');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signIn(email, pass);
      if (mounted) context.go('/practice');
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data as Map)['detail']?.toString()
          : null;
      setState(() => _error = msg ?? 'Неверная почта или пароль');
    } catch (_) {
      setState(() => _error = 'Произошла ошибка. Попробуйте позже.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  Future<void> _signUp() async {
    final email = _email.text.trim();
    final pass = _password.text;
    final name = _name.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Введите почту');
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _error = 'Некорректный формат почты');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Пароль должен быть не короче 6 символов');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signUp(
        email,
        pass,
        displayName: name.isNotEmpty ? name : null,
      );
      if (mounted) context.go('/practice');
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data as Map)['detail']?.toString()
          : null;
      setState(() => _error = msg ?? 'Не удалось создать аккаунт');
    } catch (_) {
      setState(() => _error = 'Произошла ошибка');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final controller = TextEditingController(text: _email.text.trim());
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.cSurface,
          title: Text('Восстановление пароля',
              style: TextStyle(color: context.cText)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            style: TextStyle(color: context.cText),
            decoration: _fieldDecoration(
              label: 'Почта',
              icon: Icons.email_outlined,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Отмена', style: TextStyle(color: context.cTextDim)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Отправить', style: TextStyle(color: C.accent)),
            ),
          ],
        );
      },
    );
    if (submitted != true || !mounted) {
      controller.dispose();
      return;
    }
    final email = controller.text.trim();
    controller.dispose();
    if (email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите почту')),
        );
      }
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthService.instance.requestPasswordReset(email);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Если эта почта зарегистрирована, мы отправим инструкции.',
          ),
        ),
      );
    } on DioException catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Не удалось отправить запрос. Попробуйте позже.')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Произошла ошибка.')),
      );
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: context.cTextDim),
      prefixIcon: Icon(icon, color: context.cTextDim),
      suffixIcon: suffix,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.m),
        borderSide: BorderSide(color: context.cTextDim.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.m),
        borderSide: const BorderSide(color: C.accent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBg(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: S.l),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.self_improvement, size: 72, color: C.accent)
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .scale(begin: const Offset(0.8, 0.8)),
                  const SizedBox(height: S.m),
                  Text(
                    'Meditator',
                    style: theme.textTheme.headlineLarge,
                  ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
                  const SizedBox(height: S.xs),
                  Text(
                    'Твой личный ментальный компаньон',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: context.cTextDim),
                  ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                  const SizedBox(height: S.xl),
                  GlassCard(
                    padding: const EdgeInsets.all(S.l),
                    child: AnimatedSize(
                      duration: Anim.normal,
                      curve: Anim.curve,
                      child: Column(
                        children: [
                          if (_isRegister)
                            Padding(
                              padding: const EdgeInsets.only(bottom: S.m),
                              child: TextField(
                                controller: _name,
                                textInputAction: TextInputAction.next,
                                style: TextStyle(color: context.cText),
                                decoration: _fieldDecoration(
                                  label: 'Имя',
                                  icon: Icons.person_outline,
                                ),
                              ),
                            ),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: TextStyle(color: context.cText),
                            decoration: _fieldDecoration(
                              label: 'Почта',
                              icon: Icons.email_outlined,
                            ),
                          ),
                          const SizedBox(height: S.m),
                          TextField(
                            controller: _password,
                            obscureText: !_showPassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) =>
                                _isRegister ? _signUp() : _signIn(),
                            style: TextStyle(color: context.cText),
                            decoration: _fieldDecoration(
                              label: 'Пароль',
                              icon: Icons.lock_outline,
                              suffix: IconButton(
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: context.cTextDim,
                                ),
                                onPressed: () => setState(
                                    () => _showPassword = !_showPassword),
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: S.s),
                            Text(
                              _error!,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: C.error),
                            ),
                          ],
                          const SizedBox(height: S.l),
                          GlowButton(
                            onPressed: _loading
                                ? null
                                : (_isRegister ? _signUp : _signIn),
                            isLoading: _loading,
                            width: double.infinity,
                            showGlow: true,
                            semanticLabel:
                                _isRegister ? 'Создать аккаунт' : 'Войти',
                            child: Text(
                                _isRegister ? 'Создать аккаунт' : 'Войти'),
                          ),
                          if (!_isRegister)
                            TextButton(
                              onPressed:
                                  _loading ? null : _showForgotPasswordDialog,
                              child: Text(
                                'Забыл пароль?',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: C.accent),
                              ),
                            ),
                          const SizedBox(height: S.s),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => setState(() {
                                      _isRegister = !_isRegister;
                                      _error = null;
                                    }),
                            child: Text(
                              _isRegister
                                  ? 'Уже есть аккаунт? Войти'
                                  : 'Нет аккаунта? Создать',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: C.accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms, duration: 600.ms).slideY(
                        begin: 0.05,
                        end: 0,
                        delay: 300.ms,
                        duration: 600.ms,
                      ),
                  const SizedBox(height: S.l),
                  TextButton(
                    onPressed: () => context.go('/onboarding'),
                    child: Text(
                      'Пройти онбординг заново',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
