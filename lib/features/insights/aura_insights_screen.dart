import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/api/api_service.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';

class AuraInsightsScreen extends StatefulWidget {
  const AuraInsightsScreen({super.key});

  @override
  State<AuraInsightsScreen> createState() => _AuraInsightsScreenState();
}

class _AuraInsightsScreenState extends State<AuraInsightsScreen> {
  String? _letter;
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDigest();
  }

  Future<void> _loadDigest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService.instance.getMonthlyDigest();
      if (result != null && mounted) {
        setState(() {
          _letter = result['letter'] as String?;
          _stats = result['stats'] as Map<String, dynamic>?;
          _loading = false;
        });
      } else if (mounted) {
        setState(() {
          _error = 'Не удалось загрузить дайджест';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Нет подключения к серверу';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: GradientBg(
        showStars: true,
        intensity: 0.4,
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
                    Text('Инсайты Ауры', style: t.titleLarge),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: _LoadingOrb())
                    : _error != null
                        ? _ErrorView(error: _error!, onRetry: _loadDigest)
                        : _ContentView(letter: _letter ?? '', stats: _stats ?? {}),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingOrb extends StatefulWidget {
  const _LoadingOrb();

  @override
  State<_LoadingOrb> createState() => _LoadingOrbState();
}

class _LoadingOrbState extends State<_LoadingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => CustomPaint(
            size: const Size(80, 80),
            painter: _PulsingOrbPainter(_ctrl.value),
          ),
        ),
        const SizedBox(height: S.m),
        Text(
          'Аура анализирует твой месяц...',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _PulsingOrbPainter extends CustomPainter {
  _PulsingOrbPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final pulse = 0.7 + 0.3 * math.sin(t * math.pi * 2);

    canvas.drawCircle(
      c,
      r * pulse,
      Paint()
        ..shader = RadialGradient(
          colors: [
            C.primary.withValues(alpha: 0.6),
            C.accent.withValues(alpha: 0.2),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    canvas.drawCircle(
      c,
      r * 0.3 * pulse,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, C.primary],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.3)),
    );
  }

  @override
  bool shouldRepaint(covariant _PulsingOrbPainter old) => true;
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(S.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MIcon(MIconType.star, size: 48, color: context.cTextDim),
            const SizedBox(height: S.m),
            Text(error, style: t.bodyLarge?.copyWith(color: context.cTextSec), textAlign: TextAlign.center),
            const SizedBox(height: S.m),
            TextButton(
              onPressed: onRetry,
              child: const Text('Попробовать снова'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentView extends StatelessWidget {
  const _ContentView({required this.letter, required this.stats});
  final String letter;
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final totalSessions = stats['total_sessions'] as int? ?? 0;
    final totalMinutes = stats['total_minutes'] as int? ?? 0;
    final practiceDays = stats['practice_days'] as int? ?? 0;
    final currentStreak = stats['current_streak'] as int? ?? 0;
    final topEmotions = (stats['top_emotions'] as List?)
            ?.map((e) => e as List)
            .toList() ??
        [];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: S.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: S.s),
          Row(
            children: [
              _StatChip(
                label: 'Сессий',
                value: '$totalSessions',
                color: C.primary,
              ),
              const SizedBox(width: S.s),
              _StatChip(
                label: 'Минут',
                value: '$totalMinutes',
                color: C.accent,
              ),
              const SizedBox(width: S.s),
              _StatChip(
                label: 'Дней',
                value: '$practiceDays',
                color: C.calm,
              ),
            ],
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
          const SizedBox(height: S.m),
          if (currentStreak > 0)
            GlassCard(
              showBorder: true,
              padding: const EdgeInsets.all(S.m),
              child: Row(
                children: [
                  const MIcon(MIconType.star, size: 24, color: C.gold),
                  const SizedBox(width: S.s),
                  Expanded(
                    child: Text(
                      'Текущая серия: $currentStreak дней',
                      style: t.titleMedium?.copyWith(color: C.gold),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
          if (currentStreak > 0) const SizedBox(height: S.m),
          if (topEmotions.isNotEmpty) ...[
            Text('Частые эмоции', style: t.titleMedium),
            const SizedBox(height: S.s),
            Wrap(
              spacing: S.xs,
              runSpacing: S.xs,
              children: topEmotions
                  .take(5)
                  .map((e) => _EmotionChip(
                        emotion: (e[0] as String?) ?? '',
                        count: (e[1] as int?) ?? 0,
                      ))
                  .toList(),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            const SizedBox(height: S.l),
          ],
          Text(
            'Письмо от Ауры',
            style: t.titleLarge?.copyWith(
              foreground: Paint()
                ..shader = C.gradientPrimary.createShader(
                  const Rect.fromLTWH(0, 0, 200, 40),
                ),
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
          const SizedBox(height: S.s),
          GlassCard(
            showBorder: true,
            showGlow: true,
            glowColor: C.glowPrimary,
            padding: const EdgeInsets.all(S.m),
            child: Text(
              letter,
              style: t.bodyLarge?.copyWith(
                color: context.cText,
                height: 1.7,
              ),
            ),
          ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.03),
          const SizedBox(height: S.xl),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: S.m, horizontal: S.s),
        child: Column(
          children: [
            Text(
              value,
              style: t.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: t.labelSmall?.copyWith(color: context.cTextSec)),
          ],
        ),
      ),
    );
  }
}

class _EmotionChip extends StatelessWidget {
  const _EmotionChip({required this.emotion, required this.count});
  final String emotion;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: C.surfaceGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.cSurfaceBorder),
      ),
      child: Text(
        '$emotion × $count',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.cTextSec),
      ),
    );
  }
}
