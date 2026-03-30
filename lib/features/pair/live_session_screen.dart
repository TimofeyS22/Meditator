import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:meditator/core/api/api_client.dart';

enum _BreathPhase { idle, inhale, hold, exhale }

class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({super.key});

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen>
    with TickerProviderStateMixin {
  WebSocketChannel? _channel;
  bool _connected = false;
  bool _partnerPresent = false;
  bool _sessionActive = false;
  _BreathPhase _myPhase = _BreathPhase.idle;
  _BreathPhase _partnerPhase = _BreathPhase.idle;
  String? _partnerEmoji;
  Timer? _breathTimer;
  Timer? _emojiClearTimer;
  int _syncPercent = 0;
  int _totalBreaths = 0;
  int _syncedBreaths = 0;

  late final AnimationController _myOrbCtrl;
  late final AnimationController _partnerOrbCtrl;
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _myOrbCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _partnerOrbCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _connect();
  }

  @override
  void dispose() {
    _breathTimer?.cancel();
    _emojiClearTimer?.cancel();
    _channel?.sink.close();
    _myOrbCtrl.dispose();
    _partnerOrbCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    final token = await storage.read(key: 'auth_access_token');
    if (token == null || token.isEmpty) return;

    final baseUrl = ApiClient.instance.dio.options.baseUrl;
    final wsUrl = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws/live-session?token=$token'),
      );

      await _channel!.ready;
      setState(() => _connected = true);

      _channel!.stream.listen(
        _onMessage,
        onDone: () {
          if (mounted) setState(() => _connected = false);
        },
        onError: (_) {
          if (mounted) setState(() => _connected = false);
        },
      );
    } catch (e) {
      if (mounted) setState(() => _connected = false);
    }
  }

  void _onMessage(dynamic raw) {
    final data = json.decode(raw as String) as Map<String, dynamic>;
    final type = data['type'] as String?;

    switch (type) {
      case 'room_state':
        final count = data['partner_count'] as int? ?? 0;
        setState(() => _partnerPresent = count > 1);
      case 'partner_joined':
        HapticFeedback.mediumImpact();
        setState(() => _partnerPresent = true);
      case 'partner_left':
        setState(() => _partnerPresent = false);
      case 'partner_breathing':
        final phase = _parsePhase(data['phase'] as String?);
        setState(() => _partnerPhase = phase);
        _animatePartnerOrb(phase);
        if (phase == _BreathPhase.inhale) {
          HapticFeedback.lightImpact();
        }
        _checkSync();
      case 'partner_session_start':
        HapticFeedback.mediumImpact();
      case 'partner_session_end':
        HapticFeedback.heavyImpact();
      case 'partner_emoji':
        final emoji = data['emoji'] as String? ?? '';
        setState(() => _partnerEmoji = emoji);
        HapticFeedback.lightImpact();
        _emojiClearTimer?.cancel();
        _emojiClearTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _partnerEmoji = null);
        });
    }
  }

  _BreathPhase _parsePhase(String? p) => switch (p) {
        'inhale' => _BreathPhase.inhale,
        'hold' => _BreathPhase.hold,
        'exhale' => _BreathPhase.exhale,
        _ => _BreathPhase.idle,
      };

  void _animatePartnerOrb(_BreathPhase phase) {
    if (phase == _BreathPhase.inhale) {
      _partnerOrbCtrl.forward(from: 0);
    } else if (phase == _BreathPhase.exhale) {
      _partnerOrbCtrl.reverse(from: 1);
    }
  }

  void _send(Map<String, dynamic> msg) {
    _channel?.sink.add(json.encode(msg));
  }

  void _toggleSession() {
    HapticFeedback.mediumImpact();
    if (_sessionActive) {
      _breathTimer?.cancel();
      _send({'type': 'session_end'});
      setState(() {
        _sessionActive = false;
        _myPhase = _BreathPhase.idle;
      });
    } else {
      _send({'type': 'session_start'});
      setState(() {
        _sessionActive = true;
        _totalBreaths = 0;
        _syncedBreaths = 0;
        _syncPercent = 0;
      });
      _startBreathCycle();
    }
  }

  void _startBreathCycle() {
    _runPhase(_BreathPhase.inhale, 4, () {
      _runPhase(_BreathPhase.hold, 4, () {
        _runPhase(_BreathPhase.exhale, 4, () {
          _runPhase(_BreathPhase.hold, 2, () {
            if (_sessionActive && mounted) _startBreathCycle();
          });
        });
      });
    });
  }

  void _runPhase(_BreathPhase phase, int seconds, VoidCallback onDone) {
    setState(() => _myPhase = phase);
    _send({'type': 'breathing', 'phase': phase.name});

    if (phase == _BreathPhase.inhale) {
      _myOrbCtrl.forward(from: 0);
      _totalBreaths++;
    } else if (phase == _BreathPhase.exhale) {
      _myOrbCtrl.reverse(from: 1);
    }

    _breathTimer?.cancel();
    _breathTimer = Timer(Duration(seconds: seconds), () {
      if (_sessionActive && mounted) onDone();
    });
  }

  void _checkSync() {
    if (_myPhase == _partnerPhase && _myPhase != _BreathPhase.idle) {
      _syncedBreaths++;
    }
    if (_totalBreaths > 0) {
      setState(() {
        _syncPercent = ((_syncedBreaths / (_totalBreaths * 3)) * 100).round().clamp(0, 100);
      });
    }
  }

  void _sendEmoji(String emoji) {
    HapticFeedback.lightImpact();
    _send({'type': 'emoji', 'emoji': emoji});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: GradientBg(
        showStars: true,
        showAurora: true,
        intensity: 0.6,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: S.s, vertical: S.xs),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.pop();
                      },
                      icon: MIcon(MIconType.arrowBack, size: 22, color: context.cText),
                    ),
                    const SizedBox(width: S.xs),
                    Expanded(child: Text('Пространство для двоих', style: t.titleLarge)),
                    if (_connected)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: C.ok),
                      ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

              Expanded(
                child: _connected
                    ? _buildConnectedUI(t)
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: C.primary),
                            const SizedBox(height: S.m),
                            Text('Подключаемся...', style: t.bodyMedium),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedUI(TextTheme t) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final orbSize = (constraints.maxHeight * 0.38).clamp(160.0, 260.0);
        return Column(
          children: [
            const Spacer(),
            if (_partnerEmoji != null)
              Text(_partnerEmoji!, style: const TextStyle(fontSize: 40))
                  .animate().scale(begin: const Offset(0.5, 0.5), duration: 300.ms, curve: Anim.curveGentle),
            const SizedBox(height: S.s),
            SizedBox(
              height: orbSize,
              child: AnimatedBuilder(
                animation: Listenable.merge([_myOrbCtrl, _partnerOrbCtrl, _glowCtrl]),
                builder: (ctx, _) => CustomPaint(
                  size: Size(double.infinity, orbSize),
                  painter: _DualOrbPainter(
                    myPhase: _myPhase,
                    partnerPhase: _partnerPhase,
                    myAnim: _myOrbCtrl.value,
                    partnerAnim: _partnerOrbCtrl.value,
                    glowAnim: _glowCtrl.value,
                    partnerPresent: _partnerPresent,
                    syncPercent: _syncPercent,
                    dimColor: ctx.cTextDim,
                  ),
                ),
              ),
            ),
            const SizedBox(height: S.s),
            if (_sessionActive && _syncPercent > 0)
              Text(
                'Синхронность: $_syncPercent%',
                style: t.titleMedium?.copyWith(
                  color: _syncPercent > 60 ? C.accent : context.cTextSec,
                ),
              ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: S.xs),
            Text(
              _partnerPresent
                  ? (_sessionActive ? _phaseLabel(_myPhase) : 'Партнёр на связи')
                  : 'Ожидаем партнёра...',
              style: t.bodyMedium,
            ),
            const Spacer(),
            if (_partnerPresent) ...[
              _buildActionButton(t),
              const SizedBox(height: S.s),
              _buildEmojiRow(),
            ],
            const SizedBox(height: S.m),
          ],
        );
      },
    );
  }

  String _phaseLabel(_BreathPhase phase) => switch (phase) {
        _BreathPhase.inhale => 'Вдох...',
        _BreathPhase.hold => 'Задержка...',
        _BreathPhase.exhale => 'Выдох...',
        _BreathPhase.idle => 'Готовы начать',
      };

  Widget _buildActionButton(TextTheme t) {
    return GestureDetector(
      onTap: _toggleSession,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _sessionActive
              ? const LinearGradient(colors: [C.rose, C.warm])
              : C.gradientPrimary,
          boxShadow: [
            BoxShadow(
              color: (_sessionActive ? C.glowRose : C.glowPrimary).withValues(alpha: 0.5),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: MIcon(
            _sessionActive ? MIconType.close : MIconType.meditation,
            size: 28,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiRow() {
    const emojis = ['🙏', '❤️', '✨', '😌', '🌊'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: emojis
          .map((e) => GestureDetector(
                onTap: () => _sendEmoji(e),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(e, style: const TextStyle(fontSize: 28)),
                ),
              ))
          .toList(),
    );
  }
}

class _DualOrbPainter extends CustomPainter {
  _DualOrbPainter({
    required this.myPhase,
    required this.partnerPhase,
    required this.myAnim,
    required this.partnerAnim,
    required this.glowAnim,
    required this.partnerPresent,
    required this.syncPercent,
    required this.dimColor,
  });

  final _BreathPhase myPhase;
  final _BreathPhase partnerPhase;
  final double myAnim;
  final double partnerAnim;
  final double glowAnim;
  final bool partnerPresent;
  final int syncPercent;
  final Color dimColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final syncT = syncPercent / 100.0;
    final separation = 70.0 - 40.0 * syncT;

    _drawOrb(
      canvas,
      Offset(cx - separation, cy),
      35 + 15 * myAnim,
      C.primary,
      C.calm,
      glowAnim,
      myPhase != _BreathPhase.idle,
    );

    if (partnerPresent) {
      _drawOrb(
        canvas,
        Offset(cx + separation, cy),
        35 + 15 * partnerAnim,
        C.accent,
        C.primary,
        glowAnim,
        partnerPhase != _BreathPhase.idle,
      );

      if (syncT > 0.3) {
        _drawConnection(canvas, cx, cy, separation, syncT);
      }
    } else {
      _drawOrb(
        canvas,
        Offset(cx + separation, cy),
        25,
        dimColor.withValues(alpha: 0.3),
        dimColor.withValues(alpha: 0.1),
        glowAnim * 0.3,
        false,
      );
    }
  }

  void _drawOrb(
    Canvas canvas,
    Offset center,
    double radius,
    Color color1,
    Color color2,
    double glow,
    bool active,
  ) {
    canvas.drawCircle(
      center,
      radius + 20 + 8 * glow,
      Paint()
        ..shader = RadialGradient(
          colors: [color1.withValues(alpha: 0.15), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius + 20))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color2, color1.withValues(alpha: 0.6), Colors.transparent],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    canvas.drawCircle(
      center,
      radius * 0.4,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: active ? 0.9 : 0.4), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.4)),
    );
  }

  void _drawConnection(Canvas canvas, double cx, double cy, double separation, double syncT) {
    final p1 = Offset(cx - separation + 30, cy);
    final p2 = Offset(cx + separation - 30, cy);
    final mid = Offset(cx, cy - 10 * math.sin(glowAnim * math.pi));

    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, p2.dx, p2.dy);

    canvas.drawPath(
      path,
      Paint()
        ..color = C.accent.withValues(alpha: 0.3 * syncT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + 2 * syncT
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(covariant _DualOrbPainter old) => true;
}
