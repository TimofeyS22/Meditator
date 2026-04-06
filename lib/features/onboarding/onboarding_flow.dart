import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/shared/theme/cosmic.dart';

// ─── Spec constants ──────────────────────────────────────────────────────────

const _violet = Color(0xFFA78BFA);
const _cosmosCenter = Color(0xFF1E1B4B);
const _cosmosEdge = Color(0xFF020617);

const _easeOutCubic = Curves.easeOutCubic;
const _easeInOutSine = Cubic(0.37, 0.0, 0.63, 1.0);
const _materialEase = Cubic(0.4, 0.0, 0.2, 1.0);

const _textWhite85 = Color(0xD9FFFFFF); // rgba(255,255,255,0.85)

// ─── Scenes ──────────────────────────────────────────────────────────────────

enum _Scene {
  textAppearance,
  stateSelection,
  aiResponse,
  authOptions,
  emailForm,
  universeDeepening,
  finalState,
}

// ─── Emotion model with cosmos reaction ──────────────────────────────────────

class _CosmosReaction {
  final double speedMul;
  final double densityMul;
  final double glowBoost;
  final bool chaotic;
  final double jitter;
  final double zoomPressure;
  final Color hue;

  const _CosmosReaction({
    required this.speedMul,
    required this.densityMul,
    required this.glowBoost,
    required this.chaotic,
    this.jitter = 0,
    this.zoomPressure = 0,
    required this.hue,
  });
}

class _Emotion {
  final String label;
  final IconData icon;
  final _CosmosReaction reaction;
  final String aiText;

  const _Emotion({
    required this.label,
    required this.icon,
    required this.reaction,
    required this.aiText,
  });
}

const _emotions = [
  _Emotion(
    label: 'Спокойствие',
    icon: Icons.spa_rounded,
    reaction: _CosmosReaction(
      speedMul: 0.6, densityMul: 1.0, glowBoost: 0.3,
      chaotic: false, hue: Color(0xFF60A5FA),
    ),
    aiText: 'Давай углубим это.',
  ),
  _Emotion(
    label: 'Тревога',
    icon: Icons.air_rounded,
    reaction: _CosmosReaction(
      speedMul: 1.3, densityMul: 1.0, glowBoost: -0.1,
      chaotic: false, jitter: 0.75, hue: Color(0xFF5CE1E6),
    ),
    aiText: 'Давай замедлимся.',
  ),
  _Emotion(
    label: 'Усталость',
    icon: Icons.bedtime_rounded,
    reaction: _CosmosReaction(
      speedMul: 0.4, densityMul: 1.0, glowBoost: -0.15,
      chaotic: false, hue: Color(0xFFFFB156),
    ),
    aiText: 'Отдохни.',
  ),
  _Emotion(
    label: 'Перегрузка',
    icon: Icons.flash_on_rounded,
    reaction: _CosmosReaction(
      speedMul: 1.2, densityMul: 1.8, glowBoost: 0.1,
      chaotic: true, zoomPressure: 0.03, hue: Color(0xFFFF6B8A),
    ),
    aiText: 'Стоп. Здесь тихо.',
  ),
  _Emotion(
    label: 'Пустота',
    icon: Icons.blur_on_rounded,
    reaction: _CosmosReaction(
      speedMul: 0.15, densityMul: 0.2, glowBoost: -0.3,
      chaotic: false, hue: Color(0xFF6366F1),
    ),
    aiText: 'Я здесь.',
  ),
];

// ─── Main widget ─────────────────────────────────────────────────────────────

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow>
    with TickerProviderStateMixin {

  _Scene _scene = _Scene.textAppearance;
  _Emotion? _emotion;
  bool _isLogin = false;
  String? _authError;
  bool _authLoading = false;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _nameFocus = FocusNode();

  // Cosmos background
  late final AnimationController _cosmosCtrl;
  late final AnimationController _breathCtrl;
  late final AnimationController _cosmosReactCtrl;
  late final AnimationController _cameraZoomCtrl;
  late final List<_Particle> _particles;

  // Scene-specific
  late final AnimationController _textEnterCtrl;
  late final AnimationController _chipsEnterCtrl;
  late final AnimationController _orbFloatCtrl;
  late final AnimationController _orbEnterCtrl;
  late final AnimationController _aiTextCtrl;
  late final AnimationController _authEnterCtrl;
  late final AnimationController _finalCtrl;

  // Reactive cosmos state
  _CosmosReaction _fromReaction = const _CosmosReaction(
    speedMul: 1.0, densityMul: 1.0, glowBoost: 0.0,
    chaotic: false, hue: _violet,
  );
  _CosmosReaction _toReaction = const _CosmosReaction(
    speedMul: 1.0, densityMul: 1.0, glowBoost: 0.0,
    chaotic: false, hue: _violet,
  );

  double _typingPulse = 0.0;

  @override
  void initState() {
    super.initState();
    final rng = Random(77);
    _particles = List.generate(40, (i) => _Particle.random(rng, i, 40));

    _cosmosCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))
      ..repeat();
    _breathCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
    _cosmosReactCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _cameraZoomCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    _textEnterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _chipsEnterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _orbFloatCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000));
    _orbEnterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _aiTextCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _authEnterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _finalCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _chipsEnterCtrl.forward();
    });

    _emailCtrl.addListener(_onTyping);
    _passCtrl.addListener(_onTyping);
    _nameCtrl.addListener(_onTyping);
  }

  @override
  void dispose() {
    _cosmosCtrl.dispose();
    _breathCtrl.dispose();
    _cosmosReactCtrl.dispose();
    _cameraZoomCtrl.dispose();
    _textEnterCtrl.dispose();
    _chipsEnterCtrl.dispose();
    _orbFloatCtrl.dispose();
    _orbEnterCtrl.dispose();
    _aiTextCtrl.dispose();
    _authEnterCtrl.dispose();
    _finalCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onTyping() {
    setState(() => _typingPulse = 1.0);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _typingPulse = 0.0);
    });
  }

  // ── Scene transitions ────────────────────────────────────────────────

  void _selectEmotion(_Emotion e) {
    HapticFeedback.mediumImpact();
    _emotion = e;
    _fromReaction = _toReaction;
    _toReaction = e.reaction;
    _cosmosReactCtrl.forward(from: 0);

    setState(() => _scene = _Scene.aiResponse);
    _orbEnterCtrl.forward(from: 0);
    _orbFloatCtrl.repeat();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _aiTextCtrl.forward(from: 0);
    });

    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted || _scene != _Scene.aiResponse) return;
      setState(() => _scene = _Scene.authOptions);
      _authEnterCtrl.forward(from: 0);
    });
  }

  void _chooseEmail() {
    HapticFeedback.lightImpact();
    setState(() => _scene = _Scene.emailForm);
    Future.delayed(const Duration(milliseconds: 300), () => _emailFocus.requestFocus());
  }

  void _backToAuth() {
    HapticFeedback.lightImpact();
    setState(() { _scene = _Scene.authOptions; _authError = null; });
  }

  void _toggleAuthMode() {
    HapticFeedback.lightImpact();
    setState(() { _isLogin = !_isLogin; _authError = null; });
  }

  Future<void> _submitAuth() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _authError = 'Заполни все поля');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() { _authLoading = true; _authError = null; });

    final auth = ref.read(authProvider.notifier);
    final error = _isLogin
        ? await auth.login(_emailCtrl.text.trim(), _passCtrl.text)
        : await auth.register(_emailCtrl.text.trim(), _passCtrl.text,
            name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null);

    if (!mounted) return;
    if (error != null) {
      setState(() { _authLoading = false; _authError = error; });
      return;
    }
    _enterFinal();
  }

  void _skip() {
    HapticFeedback.lightImpact();
    _enterFinal();
  }

  void _enterFinal() {
    setState(() { _authLoading = false; _scene = _Scene.universeDeepening; });
    _cameraZoomCtrl.forward();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _scene = _Scene.finalState);
      _finalCtrl.forward();
    });

    Future.delayed(const Duration(milliseconds: 3500), () async {
      if (!mounted) return;
      await ref.read(authProvider.notifier).completeOnboarding();
      if (!mounted) return;
      context.go('/home');
    });
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _cosmosCtrl, _breathCtrl, _cosmosReactCtrl,
          _cameraZoomCtrl, _textEnterCtrl, _chipsEnterCtrl,
          _orbFloatCtrl, _orbEnterCtrl, _aiTextCtrl,
          _authEnterCtrl, _finalCtrl,
        ]),
        builder: (context, _) {
          final breath = _easeInOutSine.transform(_breathCtrl.value);
          final reactT = _easeOutCubic.transform(_cosmosReactCtrl.value);
          final zoom = 1.0 + _materialEase.transform(_cameraZoomCtrl.value) * 0.1;

          final speedMul = lerpDouble(_fromReaction.speedMul, _toReaction.speedMul, reactT)!;
          final densityMul = lerpDouble(_fromReaction.densityMul, _toReaction.densityMul, reactT)!;
          final glowBoost = lerpDouble(_fromReaction.glowBoost, _toReaction.glowBoost, reactT)!;
          final jitter = lerpDouble(_fromReaction.jitter, _toReaction.jitter, reactT)!;
          final accent = Color.lerp(_fromReaction.hue, _toReaction.hue, reactT)!;
          final chaotic = reactT > 0.5 ? _toReaction.chaotic : _fromReaction.chaotic;

          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Living cosmos
                Transform.scale(
                  scale: zoom,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _CosmosPainter(
                        time: _cosmosCtrl.value,
                        breath: breath,
                        particles: _particles,
                        speedMul: speedMul + _typingPulse * 0.05,
                        densityMul: densityMul + (_scene == _Scene.universeDeepening ? 0.5 : 0),
                        glowBoost: glowBoost,
                        accent: accent,
                        chaotic: chaotic,
                        jitter: jitter,
                      ),
                    ),
                  ),
                ),

                // Vignette
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const [0.3, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),

                // Content
                SafeArea(child: _buildScene(breath)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScene(double breath) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: _easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.02), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: _easeOutCubic)),
          child: child,
        ),
      ),
      child: switch (_scene) {
        _Scene.textAppearance || _Scene.stateSelection =>
            _buildEmotionScene(breath),
        _Scene.aiResponse => _buildAiScene(),
        _Scene.authOptions => _buildAuthScene(breath),
        _Scene.emailForm => _buildEmailScene(breath),
        _Scene.universeDeepening => const SizedBox.expand(key: ValueKey('deep')),
        _Scene.finalState => _buildFinalScene(),
      },
    );
  }

  // ── Scene 4+5: Emotion ───────────────────────────────────────────────

  Widget _buildEmotionScene(double breath) {
    final textT = _easeOutCubic.transform(_textEnterCtrl.value);
    final chipsT = _chipsEnterCtrl.value;

    return Padding(
      key: const ValueKey('emotion'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 3),
          Opacity(
            opacity: textT,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - textT)),
              child: const Text(
                'Что ты сейчас\nчувствуешь?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: _textWhite85,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 40),
          ..._emotions.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final delay = i * 0.18;
            final t = _easeOutCubic.transform(
              ((chipsT - delay) / (1 - delay)).clamp(0, 1),
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - t)),
                  child: _EmotionItem(
                    emotion: e,
                    onTap: () => _selectEmotion(e),
                  ),
                ),
              ),
            );
          }),
          const Spacer(flex: 4),
        ],
      ),
    );
  }

  // ── Scene 6: AI Response ─────────────────────────────────────────────

  Widget _buildAiScene() {
    final orbT = _easeOutCubic.transform(_orbEnterCtrl.value);
    final float = sin(_orbFloatCtrl.value * 2 * pi) * 6.0;
    final aiTextT = _easeOutCubic.transform(_aiTextCtrl.value);
    final accent = _emotion?.reaction.hue ?? _violet;

    return Padding(
      key: const ValueKey('ai'),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 3),
          Transform.translate(
            offset: Offset(0, float),
            child: Transform.scale(
              scale: 0.4 + 0.6 * orbT,
              child: Opacity(
                opacity: orbT,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.9),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.4),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.15),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Opacity(
            opacity: aiTextT,
            child: Text(
              _emotion?.aiText ?? '',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w300,
                color: _textWhite85.withValues(alpha: 0.9 * aiTextT),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(flex: 4),
        ],
      ),
    );
  }

  // ── Scene 7: Auth Options ────────────────────────────────────────────

  Widget _buildAuthScene(double breath) {
    final t = _authEnterCtrl.value;
    final accent = _emotion?.reaction.hue ?? _violet;

    return Padding(
      key: const ValueKey('auth'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 3),
          _staggerFade(t, 0.0, child: const Text(
            'Сохраним это\nпространство для тебя',
            style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w400,
              color: _textWhite85, height: 1.3,
            ),
            textAlign: TextAlign.center,
          )),
          const SizedBox(height: 8),
          _staggerFade(t, 0.1, child: Text(
            'Создай аккаунт или войди',
            style: TextStyle(
              fontSize: 14, color: Colors.white.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          )),
          const SizedBox(height: 36),
          _staggerFade(t, 0.2, child: _GlassButton(
            icon: Icons.apple_rounded,
            label: 'Apple',
            onTap: () {},
          )),
          const SizedBox(height: 12),
          _staggerFade(t, 0.3, child: _GlassButton(
            icon: Icons.g_mobiledata_rounded,
            label: 'Google',
            onTap: () {},
          )),
          const SizedBox(height: 12),
          _staggerFade(t, 0.4, child: _GlassButton(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            accentColor: accent,
            onTap: _chooseEmail,
          )),
          const SizedBox(height: 24),
          _staggerFade(t, 0.5, child: GestureDetector(
            onTap: _skip,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Пропустить',
                style: TextStyle(
                  fontSize: 14, color: Colors.white.withValues(alpha: 0.45),
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
          )),
          const Spacer(flex: 4),
        ],
      ),
    );
  }

  Widget _staggerFade(double progress, double delay, {required Widget child}) {
    final t = _easeOutCubic.transform(
      ((progress - delay) / (1 - delay)).clamp(0, 1),
    );
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, 8 * (1 - t)),
        child: child,
      ),
    );
  }

  // ── Scene 8: Email Form ──────────────────────────────────────────────

  Widget _buildEmailScene(double breath) {
    final accent = _emotion?.reaction.hue ?? _violet;

    return SingleChildScrollView(
      key: const ValueKey('email'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _backToAuth,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Icon(Icons.arrow_back_rounded,
                    color: Colors.white.withValues(alpha: 0.6), size: 20),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _AuthModePill(isLogin: _isLogin, accent: accent, onToggle: _toggleAuthMode),
          const SizedBox(height: 32),
          if (!_isLogin)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CosmicInput(
                ctrl: _nameCtrl, focus: _nameFocus, hint: 'Имя',
                icon: Icons.person_outline_rounded, accent: accent,
                onSubmit: (_) => _emailFocus.requestFocus(),
              ),
            ),
          _CosmicInput(
            ctrl: _emailCtrl, focus: _emailFocus, hint: 'Email',
            icon: Icons.mail_outline_rounded, accent: accent,
            keyboard: TextInputType.emailAddress,
            onSubmit: (_) => _passFocus.requestFocus(),
          ),
          const SizedBox(height: 12),
          _CosmicInput(
            ctrl: _passCtrl, focus: _passFocus, hint: 'Пароль',
            icon: Icons.lock_outline_rounded, accent: accent,
            obscure: true, onSubmit: (_) => _submitAuth(),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300), curve: _easeOutCubic,
            child: _authError != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_authError!,
                      style: TextStyle(fontSize: 13,
                        color: const Color(0xFFFFB156).withValues(alpha: 0.75)),
                      textAlign: TextAlign.center,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          _SubmitButton(
            label: _isLogin ? 'Войти' : 'Создать',
            loading: _authLoading, accent: accent, onTap: _submitAuth,
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 32),
        ],
      ),
    );
  }

  // ── Scene 10: Final ──────────────────────────────────────────────────

  Widget _buildFinalScene() {
    final t = _easeOutCubic.transform(_finalCtrl.value);
    final accent = _emotion?.reaction.hue ?? _violet;

    return Column(
      key: const ValueKey('final'),
      children: [
        const Spacer(flex: 3),
        Transform.scale(
          scale: 0.95 + 0.05 * t,
          child: Opacity(
            opacity: t,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.9),
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 50, spreadRadius: 6),
                  BoxShadow(color: Colors.white.withValues(alpha: 0.2), blurRadius: 80),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: const Text(
              'Я здесь',
              style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w300,
                color: _textWhite85, letterSpacing: 2,
              ),
            ),
          ),
        ),
        const Spacer(flex: 4),
      ],
    );
  }
}

// ─── Emotion item (Scene 5 spec) ─────────────────────────────────────────────

class _EmotionItem extends StatefulWidget {
  final _Emotion emotion;
  final VoidCallback onTap;
  const _EmotionItem({required this.emotion, required this.onTap});
  @override
  State<_EmotionItem> createState() => _EmotionItemState();
}

class _EmotionItemState extends State<_EmotionItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
  }
  @override
  void dispose() { _press.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _press,
      builder: (_, __) {
        final p = _press.value;
        return GestureDetector(
          onTapDown: (_) => _press.forward(),
          onTapUp: (_) { _press.reverse(); widget.onTap(); },
          onTapCancel: () => _press.reverse(),
          child: Transform.scale(
            scale: 1.0 + 0.03 * p,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withValues(alpha: 0.05 + 0.02 * p),
                border: Border.all(
                  color: widget.emotion.reaction.hue.withValues(alpha: 0.1 + 0.15 * p),
                ),
                boxShadow: p > 0 ? [
                  BoxShadow(
                    color: widget.emotion.reaction.hue.withValues(alpha: 0.08 * p),
                    blurRadius: 16,
                  ),
                ] : null,
              ),
              child: Row(
                children: [
                  Icon(widget.emotion.icon, size: 20,
                      color: widget.emotion.reaction.hue),
                  const SizedBox(width: 12),
                  Text(widget.emotion.label, style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w400,
                    color: _textWhite85,
                  )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Glass button (Scene 7 spec: 48px, r24, glassmorphism) ───────────────────

class _GlassButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;
  const _GlassButton({
    required this.icon, required this.label,
    this.accentColor = Colors.white,
    required this.onTap,
  });
  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
  }
  @override
  void dispose() { _press.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _press,
      builder: (_, __) {
        final p = _press.value;
        return GestureDetector(
          onTapDown: (_) => _press.forward(),
          onTapUp: (_) {
            _press.reverse();
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          onTapCancel: () => _press.reverse(),
          child: Transform.scale(
            scale: 1.0 - 0.02 * p,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, size: 20, color: widget.accentColor),
                      const SizedBox(width: 10),
                      Text(widget.label, style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500,
                        color: _textWhite85,
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Cosmic input (Scene 8 spec: 52px, r20, glow on focus) ──────────────────

class _CosmicInput extends StatefulWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final String hint;
  final IconData icon;
  final Color accent;
  final bool obscure;
  final TextInputType? keyboard;
  final ValueChanged<String>? onSubmit;

  const _CosmicInput({
    required this.ctrl, required this.focus,
    required this.hint, required this.icon,
    required this.accent, this.obscure = false,
    this.keyboard, this.onSubmit,
  });
  @override
  State<_CosmicInput> createState() => _CosmicInputState();
}

class _CosmicInputState extends State<_CosmicInput> {
  bool _focused = false;
  @override
  void initState() {
    super.initState();
    widget.focus.addListener(() => setState(() => _focused = widget.focus.hasFocus));
  }

  @override
  Widget build(BuildContext context) {
    final borderAlpha = _focused ? 0.35 : 0.08;
    final fillAlpha = _focused ? 0.08 : 0.05;
    final glowAlpha = _focused ? 0.18 : 0.0;

    return AnimatedScale(
      scale: _focused ? 1.01 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: _easeOutCubic,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: _easeOutCubic,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(alpha: fillAlpha),
              border: Border.all(
                color: _focused
                    ? widget.accent.withValues(alpha: borderAlpha)
                    : Colors.white.withValues(alpha: borderAlpha),
              ),
              boxShadow: glowAlpha > 0 ? [
                BoxShadow(
                  color: widget.accent.withValues(alpha: glowAlpha),
                  blurRadius: 24,
                ),
              ] : null,
            ),
            child: TextField(
              controller: widget.ctrl,
              focusNode: widget.focus,
              obscureText: widget.obscure,
              keyboardType: widget.keyboard,
              onSubmitted: widget.onSubmit,
              style: const TextStyle(color: _textWhite85, fontSize: 15),
              cursorColor: widget.accent,
              decoration: InputDecoration(
                prefixIcon: Icon(widget.icon, size: 20,
                    color: _focused ? widget.accent : Colors.white.withValues(alpha: 0.45)),
                hintText: widget.hint,
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontWeight: FontWeight.w300),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Submit button ───────────────────────────────────────────────────────────

class _SubmitButton extends StatefulWidget {
  final String label;
  final bool loading;
  final Color accent;
  final VoidCallback onTap;
  const _SubmitButton({required this.label, required this.loading, required this.accent, required this.onTap});
  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
  }
  @override
  void dispose() { _press.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _press,
      builder: (_, __) {
        final p = _press.value;
        return GestureDetector(
          onTapDown: widget.loading ? null : (_) => _press.forward(),
          onTapUp: widget.loading ? null : (_) { _press.reverse(); widget.onTap(); },
          onTapCancel: widget.loading ? null : () => _press.reverse(),
          child: Transform.scale(
            scale: 1.0 - 0.02 * p,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(colors: [
                  widget.accent,
                  widget.accent.withValues(alpha: 0.7),
                ]),
                boxShadow: [
                  BoxShadow(color: widget.accent.withValues(alpha: 0.25), blurRadius: 24),
                ],
              ),
              child: Center(
                child: widget.loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.label, style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Auth mode pill ──────────────────────────────────────────────────────────

class _AuthModePill extends StatelessWidget {
  final bool isLogin;
  final Color accent;
  final VoidCallback onToggle;
  const _AuthModePill({required this.isLogin, required this.accent, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(children: [
            _PillTab(label: 'Регистрация', active: !isLogin,
                accent: accent, onTap: isLogin ? onToggle : null),
            _PillTab(label: 'Вход', active: isLogin,
                accent: accent, onTap: isLogin ? null : onToggle),
          ]),
        ),
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  final String label;
  final bool active;
  final Color accent;
  final VoidCallback? onTap;
  const _PillTab({required this.label, required this.active, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: _easeOutCubic,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: active ? accent.withValues(alpha: 0.18) : Colors.transparent,
            border: active ? Border.all(color: accent.withValues(alpha: 0.25)) : null,
          ),
          child: Center(child: Text(label, style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.4),
          ))),
        ),
      ),
    );
  }
}

// ─── Particle ────────────────────────────────────────────────────────────────

class _Particle {
  final double x, y, size, baseAlpha;
  final double driftAmpX, driftAmpY, driftFreqX, driftFreqY, phase;
  final int layer;

  const _Particle({
    required this.x, required this.y, required this.size, required this.baseAlpha,
    required this.driftAmpX, required this.driftAmpY,
    required this.driftFreqX, required this.driftFreqY,
    required this.phase, required this.layer,
  });

  factory _Particle.random(Random rng, int i, int total) => _Particle(
    x: rng.nextDouble(), y: rng.nextDouble(),
    size: 1.0 + rng.nextDouble() * 2.0,
    baseAlpha: 0.2 + rng.nextDouble() * 0.4,
    driftAmpX: 0.01 + rng.nextDouble() * 0.04,
    driftAmpY: 0.01 + rng.nextDouble() * 0.03,
    driftFreqX: 0.5 + rng.nextDouble() * 1.5,
    driftFreqY: 0.5 + rng.nextDouble() * 1.5,
    phase: rng.nextDouble() * 2 * pi,
    layer: rng.nextInt(3),
  );

  static const layerSpeeds = [0.5, 1.0, 1.5];
}

// ─── Cosmos painter (reactive) ───────────────────────────────────────────────

class _CosmosPainter extends CustomPainter {
  final double time, breath, speedMul, densityMul, glowBoost, jitter;
  final Color accent;
  final bool chaotic;
  final List<_Particle> particles;

  _CosmosPainter({
    required this.time, required this.breath, required this.particles,
    required this.speedMul, required this.densityMul, required this.glowBoost,
    required this.accent, required this.chaotic, required this.jitter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Radial gradient
    canvas.drawRect(rect, Paint()
      ..shader = RadialGradient(
        center: Alignment.center, radius: 1.2,
        colors: [
          Color.lerp(_cosmosCenter, accent, 0.15)!,
          _cosmosEdge,
        ],
      ).createShader(rect));

    // Nebula bloom
    final bloomCenter = Offset(size.width * 0.5, size.height * 0.38);
    final bloomR = size.width * 0.6;
    final bloomAlpha = (0.06 + glowBoost * 0.1).clamp(0.01, 0.2);
    canvas.drawCircle(bloomCenter, bloomR, Paint()
      ..shader = RadialGradient(colors: [
        accent.withValues(alpha: bloomAlpha),
        accent.withValues(alpha: bloomAlpha * 0.3),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: bloomCenter, radius: bloomR)));

    // Particles
    final t = time * 2 * pi;
    final paint = Paint();
    final visibleCount = (particles.length * densityMul).round().clamp(0, particles.length);

    for (var i = 0; i < visibleCount; i++) {
      final p = particles[i];
      final spd = _Particle.layerSpeeds[p.layer] * speedMul;
      final twinkle = (sin(t * 1.5 * spd + p.phase) + 1.0) * 0.5;

      double px = (p.x + sin(t * p.driftFreqX * spd + p.phase) * p.driftAmpX) % 1.0;
      double py = (p.y + cos(t * p.driftFreqY * spd + p.phase) * p.driftAmpY) % 1.0;

      if (chaotic) {
        px += sin(t * 3.0 * p.phase + p.phase * 2.71) * 0.008;
        py += cos(t * 2.7 * p.phase + p.phase * 3.14) * 0.006;
      }
      if (jitter > 0) {
        px += sin(t * 8.0 + p.phase * 5.0) * jitter * 0.002;
        py += cos(t * 7.0 + p.phase * 4.0) * jitter * 0.002;
      }

      final alpha = (p.baseAlpha * (0.35 + 0.65 * twinkle)).clamp(0.0, 1.0);
      paint.color = Color.lerp(Colors.white, accent, p.layer == 2 ? 0.3 : 0.0)!
          .withValues(alpha: alpha);

      canvas.drawCircle(
        Offset(px * size.width, py * size.height),
        p.size * (0.85 + 0.15 * breath),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CosmosPainter old) =>
      old.time != time || old.breath != breath ||
      old.speedMul != speedMul || old.densityMul != densityMul ||
      old.chaotic != chaotic || old.jitter != jitter ||
      old.accent != accent || old.glowBoost != glowBoost;
}
