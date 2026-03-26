import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/features/home/meditation_playback_cache.dart';
import 'package:meditator/shared/models/meditation.dart';
import 'package:meditator/shared/utils/accessibility.dart';
import 'package:meditator/shared/widgets/aura_avatar.dart';
import 'package:meditator/shared/widgets/glass_card.dart';

class AuraCard extends StatefulWidget {
  const AuraCard({
    super.key,
    required this.meditation,
    required this.reason,
    this.loading = false,
  });

  final Meditation? meditation;
  final String reason;
  final bool loading;

  @override
  State<AuraCard> createState() => _AuraCardState();
}

class _AuraCardState extends State<AuraCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      if (_pulseCtrl.isAnimating) _pulseCtrl.stop();
    } else if (!_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final m = widget.meditation;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(R.l),
        gradient: C.gradientPrimary,
        boxShadow: [
          BoxShadow(
            color: C.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.5),
      child: GlassCard(
        useBlur: true,
        blur: 15,
        semanticLabel: widget.loading || m == null
            ? 'Aura подбирает медитацию'
            : 'Рекомендация Aura: ${m.title}',
        padding: const EdgeInsets.all(S.m),
        child: widget.loading || m == null
            ? _buildLoading(t)
            : _buildContent(context, t, m),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, curve: Curves.easeOut)
        .slideY(begin: 0.06, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildLoading(TextTheme t) {
    return SizedBox(
      height: 168,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListenableBuilder(
              listenable: _pulseCtrl,
              builder: (context, _) => _buildPulsatingDots(),
            ),
            const SizedBox(height: S.m),
            Text(
              'Aura подбирает практику…',
              style: t.bodyMedium?.copyWith(color: C.textSec),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsatingDots() {
    const colors = [C.primary, C.accent, C.primary];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final phase = i * 0.33;
        final t = ((_pulseCtrl.value + phase) % 1.0);
        final opacity = (0.3 + 0.7 * sin(t * pi)).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors[i],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildContent(BuildContext context, TextTheme t, Meditation m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: S.s, vertical: 4),
              decoration: BoxDecoration(
                color: C.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(R.s),
              ),
              child: Text(
                'Aura рекомендует',
                style: t.labelSmall?.copyWith(
                  color: C.accentLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: S.s),
            const AuraAvatar(size: 40),
            const Spacer(),
            Text(
              '${m.durationMinutes} мин',
              style: t.bodySmall?.copyWith(color: C.textDim),
            ),
          ],
        ),
        const SizedBox(height: S.m),
        Text(
          m.title,
          style: t.titleLarge?.copyWith(color: C.text, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: S.s),
        Text(
          widget.reason.isNotEmpty ? widget.reason : m.description,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: t.bodyMedium?.copyWith(color: C.textSec, height: 1.4),
        ),
        const SizedBox(height: S.m),
        Row(
          children: [
            ListenableBuilder(
              listenable: _pulseCtrl,
              builder: (context, _) => _buildPlayArea(context, m),
            ),
            const SizedBox(width: S.s),
            Expanded(
              child: Text(
                'Слушать',
                style: t.titleMedium?.copyWith(color: C.textSec),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayArea(BuildContext context, Meditation m) {
    final pulseScale =
        _reduceMotion ? 1.0 : (1.0 + 0.03 * sin(_pulseCtrl.value * 2 * pi));

    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < 3; i++) _buildRing(i),
          Transform.scale(
            scale: pulseScale,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  MeditationPlaybackCache.byId[m.id] = m;
                  context.push('/play?id=${Uri.encodeComponent(m.id)}');
                },
                customBorder: const CircleBorder(),
                borderRadius: BorderRadius.circular(R.full),
                child: Ink(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: C.gradientPrimary,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRing(int index) {
    final offset = index * 0.3;
    final progress = (_pulseCtrl.value + offset) % 1.0;
    final scale = 1.0 + 0.5 * progress;
    final opacity = (0.3 * (1.0 - progress)).clamp(0.0, 1.0);

    return Transform.scale(
      scale: scale,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: C.primary.withValues(alpha: opacity),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
