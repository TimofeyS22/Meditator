import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/api/api_service.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:share_plus/share_plus.dart';

class ConsciousnessMapScreen extends StatefulWidget {
  const ConsciousnessMapScreen({super.key});

  @override
  State<ConsciousnessMapScreen> createState() => _ConsciousnessMapScreenState();
}

class _ConsciousnessMapScreenState extends State<ConsciousnessMapScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _repaintKey = GlobalKey();
  late final AnimationController _revealCtrl;
  List<_SessionNode> _nodes = [];
  List<_MoodNode> _moods = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _loadData();
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final uid = AuthService.instance.currentUser?.id ?? '';
    final sessions = await ApiService.instance.getSessionsForUser(uid, limit: 200);
    final moods = await ApiService.instance.getMoodEntries(uid, limit: 200);

    final nodes = <_SessionNode>[];
    for (final s in sessions) {
      final completed = s['completed'] == true;
      if (!completed) continue;
      final createdAt = DateTime.tryParse(s['created_at']?.toString() ?? '');
      final duration = (s['duration_seconds'] as num?)?.toInt() ?? 0;
      final moodBefore = s['mood_before'] as String?;
      nodes.add(_SessionNode(
        createdAt: createdAt ?? DateTime.now(),
        durationSeconds: duration,
        moodBefore: moodBefore,
      ));
    }

    final moodNodes = <_MoodNode>[];
    for (final m in moods) {
      final createdAt = DateTime.tryParse(m['created_at']?.toString() ?? '');
      final emotion = m['primary_emotion'] as String? ?? '';
      final intensity = (m['intensity'] as num?)?.toInt() ?? 3;
      moodNodes.add(_MoodNode(
        createdAt: createdAt ?? DateTime.now(),
        emotion: emotion,
        intensity: intensity,
      ));
    }

    if (mounted) {
      setState(() {
        _nodes = nodes;
        _moods = moodNodes;
        _loading = false;
      });
      _revealCtrl.forward();
    }
  }

  Future<void> _shareMap() async {
    HapticFeedback.mediumImpact();
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png', name: 'consciousness_map.png')],
          text: 'Моя карта сознания — Meditator',
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: GradientBg(
        showStars: true,
        intensity: 0.5,
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
                    Expanded(
                      child: Text('Карта сознания', style: t.titleLarge),
                    ),
                    if (!_loading)
                      IconButton(
                        onPressed: _shareMap,
                        icon: MIcon(MIconType.send, size: 20, color: context.cTextSec),
                        tooltip: 'Поделиться',
                      ),
                  ],
                ),
              ),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: C.primary)))
              else if (_nodes.isEmpty && _moods.isEmpty)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(S.l),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MIcon(MIconType.meditation, size: 48, color: context.cTextDim),
                          const SizedBox(height: S.m),
                          Text(
                            'Карта пока пуста.\nЗаверши первую медитацию — и она начнёт расти.',
                            style: t.bodyLarge?.copyWith(color: context.cTextSec),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(S.s),
                    child: Column(
                      children: [
                        Expanded(
                          child: RepaintBoundary(
                            key: _repaintKey,
                            child: GlassCard(
                              padding: EdgeInsets.zero,
                              showBorder: true,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(R.l),
                                child: AnimatedBuilder(
                                  animation: _revealCtrl,
                                  builder: (ctx, _) => CustomPaint(
                                    size: Size.infinite,
                                    painter: _ConsciousnessMapPainter(
                                      sessions: _nodes,
                                      moods: _moods,
                                      reveal: CurvedAnimation(
                                        parent: _revealCtrl,
                                        curve: Curves.easeOutCubic,
                                      ).value,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: S.s),
                        _Legend().animate().fadeIn(delay: 600.ms, duration: 400.ms),
                        const SizedBox(height: S.s),
                        Text(
                          'Каждая точка — сессия. Цвет — настроение. Размер — длительность.\n'
                          'Пропущенные дни — просто пустое пространство.',
                          style: t.bodySmall,
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 800.ms, duration: 400.ms),
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
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      ('Спокойствие', C.calm),
      ('Радость', C.happy),
      ('Тревога', C.anxious),
      ('Грусть', C.sad),
      ('Энергия', C.energy),
      ('Благодарность', C.grateful),
    ];
    return Wrap(
      spacing: S.s,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: items
          .map((e) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: e.$2),
                  ),
                  const SizedBox(width: 4),
                  Text(e.$1, style: Theme.of(context).textTheme.labelSmall),
                ],
              ))
          .toList(),
    );
  }
}

class _SessionNode {
  _SessionNode({required this.createdAt, required this.durationSeconds, this.moodBefore});
  final DateTime createdAt;
  final int durationSeconds;
  final String? moodBefore;
}

class _MoodNode {
  _MoodNode({required this.createdAt, required this.emotion, required this.intensity});
  final DateTime createdAt;
  final String emotion;
  final int intensity;
}

Color _emotionColor(String? emotion) {
  if (emotion == null || emotion.isEmpty) return C.primary;
  final e = emotion.toLowerCase();
  if (e.contains('спокой') || e.contains('calm') || e.contains('peace')) return C.calm;
  if (e.contains('радост') || e.contains('happy') || e.contains('joy')) return C.happy;
  if (e.contains('тревог') || e.contains('anxious') || e.contains('stress') || e.contains('стресс')) {
    return C.anxious;
  }
  if (e.contains('груст') || e.contains('sad') || e.contains('печаль')) return C.sad;
  if (e.contains('энерг') || e.contains('energy') || e.contains('бодр')) return C.energy;
  if (e.contains('благодар') || e.contains('grateful') || e.contains('счаст')) return C.grateful;
  return C.primary;
}

class _ConsciousnessMapPainter extends CustomPainter {
  _ConsciousnessMapPainter({
    required this.sessions,
    required this.moods,
    required this.reveal,
  });

  final List<_SessionNode> sessions;
  final List<_MoodNode> moods;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = math.min(cx, cy) * 0.85;
    final rng = math.Random(42);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF020617),
    );

    _drawSpiral(canvas, cx, cy, maxR, rng);

    _drawSessionNodes(canvas, cx, cy, maxR, rng);

    _drawMoodOrbs(canvas, cx, cy, maxR, rng);
  }

  void _drawSpiral(Canvas canvas, double cx, double cy, double maxR, math.Random rng) {
    final spiralPath = Path();
    final totalPoints = 360;
    final visiblePoints = (totalPoints * reveal).toInt();

    for (int i = 0; i < visiblePoints; i++) {
      final t = i / totalPoints;
      final angle = t * math.pi * 6;
      final r = t * maxR;
      final x = cx + math.cos(angle) * r;
      final y = cy + math.sin(angle) * r;
      if (i == 0) {
        spiralPath.moveTo(x, y);
      } else {
        spiralPath.lineTo(x, y);
      }
    }

    canvas.drawPath(
      spiralPath,
      Paint()
        ..color = C.primary.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  void _drawSessionNodes(Canvas canvas, double cx, double cy, double maxR, math.Random rng) {
    if (sessions.isEmpty) return;

    final sorted = List<_SessionNode>.from(sessions)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final earliest = sorted.first.createdAt;
    final latest = sorted.last.createdAt;
    final span = latest.difference(earliest).inSeconds.toDouble();

    for (int i = 0; i < sorted.length; i++) {
      final node = sorted[i];
      final progress = span > 0
          ? node.createdAt.difference(earliest).inSeconds / span
          : (i / sorted.length.toDouble());

      if (progress > reveal) continue;

      final angle = progress * math.pi * 5 + node.createdAt.hour * 0.1;
      final r = 20 + progress * (maxR - 30);

      final goldenAngle = i * 2.3999;
      final x = cx + math.cos(angle + goldenAngle) * r;
      final y = cy + math.sin(angle + goldenAngle) * r;

      final color = _emotionColor(node.moodBefore);
      final dotR = 3.0 + (node.durationSeconds / 600).clamp(0.0, 8.0);

      canvas.drawCircle(
        Offset(x, y),
        dotR + 4,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      canvas.drawCircle(
        Offset(x, y),
        dotR,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0.3)],
          ).createShader(Rect.fromCircle(center: Offset(x, y), radius: dotR)),
      );
    }
  }

  void _drawMoodOrbs(Canvas canvas, double cx, double cy, double maxR, math.Random rng) {
    if (moods.isEmpty) return;

    final sorted = List<_MoodNode>.from(moods)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final earliest = sorted.first.createdAt;
    final latest = sorted.last.createdAt;
    final span = latest.difference(earliest).inSeconds.toDouble();

    for (int i = 0; i < sorted.length; i++) {
      final mood = sorted[i];
      final progress = span > 0
          ? mood.createdAt.difference(earliest).inSeconds / span
          : (i / sorted.length.toDouble());

      if (progress > reveal) continue;

      final angle = progress * math.pi * 4 + 1.0;
      final r = 30 + progress * (maxR - 40);
      final shift = rng.nextDouble() * 0.5;

      final x = cx + math.cos(angle + shift) * r * 0.9;
      final y = cy + math.sin(angle + shift) * r * 0.9;

      final color = _emotionColor(mood.emotion);
      final dotR = 2.0 + mood.intensity * 1.5;

      canvas.drawCircle(
        Offset(x, y),
        dotR + 6,
        Paint()
          ..color = color.withValues(alpha: 0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );

      canvas.drawCircle(
        Offset(x, y),
        dotR * 0.6,
        Paint()..color = color.withValues(alpha: 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConsciousnessMapPainter old) =>
      old.reveal != reveal || old.sessions.length != sessions.length;
}
