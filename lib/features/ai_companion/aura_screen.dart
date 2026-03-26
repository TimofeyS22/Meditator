import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/api/backend.dart';
import 'package:meditator/shared/models/mood_entry.dart';
import 'package:meditator/shared/widgets/emotion_chip.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/shared/widgets/aura_avatar.dart';

class _ChatMessage {
  _ChatMessage({required this.role, required this.content, this.isNew = false});
  final String role;
  final String content;
  bool isNew;
}

class AuraScreen extends StatefulWidget {
  const AuraScreen({super.key});

  @override
  State<AuraScreen> createState() => _AuraScreenState();
}

class _AuraScreenState extends State<AuraScreen> with TickerProviderStateMixin {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _focusNode = FocusNode();
  final List<_ChatMessage> _messages = [];
  bool _thinking = false;
  bool _meditationLoading = false;
  String _moodLabel = 'спокойствие';
  String _moodKey = Emotion.peace.name;
  bool _inputFocused = false;
  int _sendTapCount = 0;

  late final AnimationController _shimmerCtrl;

  static const List<Emotion> _quick = [
    Emotion.joy,
    Emotion.peace,
    Emotion.anxiety,
    Emotion.sadness,
    Emotion.gratitude,
    Emotion.fatigue,
  ];

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat();
    _focusNode.addListener(_onFocusChange);
    _messages.add(
      _ChatMessage(
        role: 'aura',
        content: 'Привет! Я Aura, твой AI-компаньон. Как ты себя чувствуешь?',
        isNew: true,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBottom());
  }

  void _onFocusChange() {
    setState(() => _inputFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _parseAuraReply(Map<String, dynamic> m) {
    final msg = m['message'] as String?;
    if (msg != null && msg.trim().isNotEmpty) return msg.trim();
    final ins = m['insight'] as String?;
    if (ins != null && ins.trim().isNotEmpty) return ins.trim();
    final list = m['insights'];
    if (list is List && list.isNotEmpty) {
      final parts = list.map((e) => e.toString()).where((s) => s.isNotEmpty);
      if (parts.isNotEmpty) return parts.join('\n');
    }
    final patterns = m['patterns'];
    if (patterns is List && patterns.isNotEmpty) {
      return patterns.map((e) => e.toString()).join('\n');
    }
    return '';
  }

  String _fallbackAdvice(String label) {
    return 'Слышу тебя. Сейчас важно не оценивать себя — просто заметь, что ты чувствуешь «$label». '
        'Попробуй один медленный выдох и мягко вернись к дыханию, когда будет тяжело.';
  }

  Future<void> _onUserPhrase(
    String text, {
    required String moodKey,
    required String moodLabel,
  }) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text.trim()));
      _moodKey = moodKey;
      _moodLabel = moodLabel;
      _thinking = true;
    });
    _input.clear();
    _scrollBottom();

    try {
      final map = await Backend.instance.analyzeMood(
        entries: [
          {
            'primary': moodKey,
            'intensity': 3,
            'secondary': <String>[],
            'note': text.trim(),
            'created_at': DateTime.now().toIso8601String(),
          },
        ],
        userGoals: const [],
      );
      final reply = _parseAuraReply(map);
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _messages.add(
          _ChatMessage(
            role: 'aura',
            content: reply.isNotEmpty ? reply : _fallbackAdvice(moodLabel),
            isNew: true,
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _messages.add(
          _ChatMessage(
            role: 'aura',
            content: _fallbackAdvice(moodLabel),
            isNew: true,
          ),
        );
      });
    }
    _scrollBottom();
  }

  void _onChip(Emotion e) {
    _onUserPhrase(e.label, moodKey: e.name, moodLabel: e.label);
  }

  void _sendTyped() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    _onUserPhrase(t, moodKey: _moodKey, moodLabel: _moodLabel);
  }

  void _handleSendTap() {
    if (_input.text.trim().isEmpty || _thinking) return;
    setState(() => _sendTapCount++);
    _sendTyped();
  }

  Future<void> _copyMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Сообщение скопировано')),
    );
  }

  Future<void> _createMeditation() async {
    setState(() => _meditationLoading = true);
    try {
      final res = await Backend.instance.generateMeditation(
        mood: _moodLabel,
        goal: 'поддержка и мягкое возвращение в тело',
        durationMinutes: 10,
      );
      if (!mounted) return;
      final id = res['id'] as String? ??
          res['meditationId'] as String? ??
          res['meditation_id'] as String? ??
          '';
      if (id.isEmpty) {
        context.push('/play');
      } else {
        context.push('/play?id=${Uri.encodeComponent(id)}');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось создать медитацию. Попробуй ещё раз.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _meditationLoading = false);
    }
  }

  double get _shimmerProgress {
    const delayRatio = 3000.0 / 3800.0;
    final v = _shimmerCtrl.value;
    if (v < delayRatio) return 0.0;
    return (v - delayRatio) / (1.0 - delayRatio);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBg(
        showStars: true,
        showAurora: false,
        intensity: 0.3,
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(child: _buildMessageList()),
            _buildChips(),
            _buildInputRow(),
            _buildMeditationButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.s, S.s, S.m, S.s),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: C.text),
            tooltip: 'Закрыть чат',
            onPressed: () => context.pop(),
          ),
          const Spacer(),
          Text(
            'Aura',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: C.text),
          ).animate().fadeIn(duration: 400.ms),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: S.m, vertical: S.s),
      itemCount: _messages.length + (_thinking ? 1 : 0),
      itemBuilder: (context, i) {
        if (_thinking && i == _messages.length) {
          return const _TypingDots().animate().fadeIn();
        }
        final m = _messages[i];
        final isAura = m.role == 'aura';
        return Padding(
          padding: const EdgeInsets.only(bottom: S.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment:
                isAura ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              if (isAura) ...[
                const _Avatar(isThinking: false),
                const SizedBox(width: S.s),
              ],
              Flexible(
                child: isAura
                    ? _buildAuraBubble(m, i)
                    : _buildUserBubble(m, i),
              ),
              if (!isAura) const SizedBox(width: S.s),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuraBubble(_ChatMessage m, int index) {
    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(R.l),
      bottomLeft: Radius.circular(R.l),
      bottomRight: Radius.circular(R.l),
    );

    return Semantics(
      label: 'Сообщение Aura',
      child: GestureDetector(
        onLongPress: () => _copyMessage(m.content),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: borderRadius,
                border: Border.all(color: C.surfaceBorder, width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: S.m, vertical: S.s),
              child: _TypewriterText(
                text: m.content,
                animate: m.isNew,
                onAnimationStarted: () => m.isNew = false,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: C.text,
                      height: 1.45,
                    ),
              ),
            ),
          ),
        ),
      ),
    )
        .animate(key: ValueKey('aura_$index'))
        .fadeIn(duration: Anim.normal)
        .slideY(
          begin: 0.06,
          end: 0,
          duration: Anim.normal,
          curve: Anim.curve,
        );
  }

  Widget _buildUserBubble(_ChatMessage m, int index) {
    return Semantics(
      label: 'Твоё сообщение',
      child: GestureDetector(
        onLongPress: () => _copyMessage(m.content),
        child: Container(
          decoration: const BoxDecoration(
            gradient: C.gradientPrimary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(R.l),
              topRight: Radius.circular(R.l),
              bottomLeft: Radius.circular(R.l),
              bottomRight: Radius.circular(4),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: S.m, vertical: S.s),
          child: Text(
            m.content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  height: 1.45,
                ),
          ),
        ),
      ),
    )
        .animate(key: ValueKey('user_$index'))
        .fadeIn(duration: Anim.normal)
        .slideX(
          begin: 0.1,
          end: 0,
          duration: Anim.normal,
          curve: Anim.curve,
        );
  }

  Widget _buildChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.m, 0, S.m, S.s),
      child: Wrap(
        spacing: S.s,
        runSpacing: S.s,
        children: [
          for (int i = 0; i < _quick.length; i++)
            EmotionChip(
              emoji: _quick[i].emoji,
              label: _quick[i].label,
              color: _quick[i].color,
              isSelected: false,
              onTap: () => _onChip(_quick[i]),
            )
                .animate(delay: Duration(milliseconds: 50 * i))
                .fadeIn(duration: Anim.normal)
                .slideY(
                  begin: 0.2,
                  end: 0,
                  duration: Anim.normal,
                  curve: Anim.curve,
                ),
        ],
      ),
    );
  }

  Widget _buildInputRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.m, 0, S.m, S.m),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _input,
                  focusNode: _focusNode,
                  style: const TextStyle(color: C.text),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Напиши, что чувствуешь…',
                  ),
                  onSubmitted: (_) => _handleSendTap(),
                ),
                AnimatedContainer(
                  duration: Anim.normal,
                  curve: Anim.curve,
                  height: _inputFocused ? 2 : 0,
                  decoration: const BoxDecoration(
                    gradient: C.gradientPrimary,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(R.m),
                      bottomRight: Radius.circular(R.m),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: S.s),
          _buildSendButton(),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    final enabled = !_thinking && _input.text.trim().isNotEmpty;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Отправить сообщение',
      child: GestureDetector(
        onTap: _thinking ? null : _handleSendTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: _thinking ? null : C.gradientPrimary,
            color: _thinking ? C.surfaceLight : null,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(_sendTapCount),
              tween: Tween(
                begin: _sendTapCount > 0 ? -pi / 4 : 0.0,
                end: 0.0,
              ),
              duration: Anim.fast,
              curve: Anim.curve,
              builder: (context, angle, child) =>
                  Transform.rotate(angle: angle, child: child),
              child: Icon(
                Icons.send_rounded,
                color: _thinking ? C.textDim : Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeditationButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.m, 0, S.m, S.l),
      child: SizedBox(
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (context, child) {
            final shimmerT = _shimmerProgress;
            return Stack(
              children: [
                child!,
                if (shimmerT > 0 && !_meditationLoading)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(R.xl),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(-1.0 + 3.0 * shimmerT, 0),
                              end: Alignment(-0.5 + 3.0 * shimmerT, 0),
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.12),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
          child: GlowButton(
            onPressed:
                _meditationLoading || _thinking ? null : _createMeditation,
            showGlow: true,
            width: double.infinity,
            semanticLabel: 'Создать персональную медитацию',
            child: _meditationLoading
                ? const _PulsatingOpacityText('Создаю...')
                : const Text('Создать медитацию'),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar — AuraAvatar with thinking state
// ---------------------------------------------------------------------------

class _Avatar extends StatelessWidget {
  const _Avatar({this.isThinking = false});
  final bool isThinking;

  @override
  Widget build(BuildContext context) {
    return AuraAvatar(size: 40, isThinking: isThinking);
  }
}

// ---------------------------------------------------------------------------
// Typewriter text — reveals characters one-by-one for new aura messages
// ---------------------------------------------------------------------------

class _TypewriterText extends StatefulWidget {
  const _TypewriterText({
    required this.text,
    required this.animate,
    required this.style,
    this.onAnimationStarted,
  });

  final String text;
  final bool animate;
  final TextStyle? style;
  final VoidCallback? onAnimationStarted;

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  int _charCount = 0;
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      widget.onAnimationStarted?.call();
      _runTypewriter();
    } else {
      _charCount = widget.text.length;
      _complete = true;
    }
  }

  Future<void> _runTypewriter() async {
    for (var i = 1; i <= widget.text.length; i++) {
      await Future.delayed(const Duration(milliseconds: 20));
      if (!mounted) return;
      setState(() => _charCount = i);
    }
    if (mounted) setState(() => _complete = true);
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _complete ? widget.text : widget.text.substring(0, _charCount),
      style: widget.style,
    );
  }
}

// ---------------------------------------------------------------------------
// Typing dots — shown while Aura is thinking
// ---------------------------------------------------------------------------

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(R.l),
      bottomLeft: Radius.circular(R.l),
      bottomRight: Radius.circular(R.l),
    );

    return Row(
      children: [
        const _Avatar(isThinking: true),
        const SizedBox(width: S.s),
        ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: S.m, vertical: S.m),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: borderRadius,
                border: Border.all(color: C.surfaceBorder, width: 0.5),
              ),
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final t = (_c.value + i * 0.2) % 1.0;
                      final o = 0.35 +
                          0.65 *
                              (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: C.accent.withValues(alpha: o),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pulsating opacity text — loading label for meditation creation
// ---------------------------------------------------------------------------

class _PulsatingOpacityText extends StatefulWidget {
  const _PulsatingOpacityText(this.text);
  final String text;

  @override
  State<_PulsatingOpacityText> createState() => _PulsatingOpacityTextState();
}

class _PulsatingOpacityTextState extends State<_PulsatingOpacityText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Opacity(
        opacity: 0.4 + 0.6 * _ctrl.value,
        child: Text(widget.text),
      ),
    );
  }
}
