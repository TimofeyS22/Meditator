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
import 'package:meditator/shared/widgets/custom_icons.dart';

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
      duration: const Duration(seconds: 3),
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
    final tod = C.timeOfDay();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(R.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tod.blob1.withValues(alpha: 0.12),
            tod.blob2.withValues(alpha: 0.08),
            tod.blob3.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: tod.blob1.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Semantics(
        label: widget.loading || m == null
            ? 'Aura подбирает медитацию'
            : 'Рекомендация Aura: ${m.title}',
        child: Padding(
          padding: const EdgeInsets.all(S.l),
          child: widget.loading
              ? _buildLoading(t)
              : m == null
                  ? _buildEmpty(t)
                  : _buildContent(context, t, m),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, curve: Anim.curveMeditative)
        .slideY(begin: 0.04, duration: 500.ms, curve: Anim.curve);
  }

  Widget _buildLoading(TextTheme t) {
    return SizedBox(
      height: 140,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListenableBuilder(
              listenable: _pulseCtrl,
              builder: (context, _) => _buildPulsatingDots(),
            ),
            const SizedBox(height: S.m),
            Text('Aura подбирает практику…', style: t.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(TextTheme t) {
    return SizedBox(
      height: 140,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AuraAvatar(size: 40),
            const SizedBox(height: S.m),
            Text('Aura пока думает…', style: t.bodyMedium),
            const SizedBox(height: S.s),
            Text('Потяни вниз для обновления', style: t.bodySmall),
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
              width: 8,
              height: 8,
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
            const Hero(
              tag: 'aura_avatar_home',
              child: AuraAvatar(size: 28),
            ),
            const SizedBox(width: S.s),
            Text(
              'Aura рекомендует',
              style: t.labelSmall?.copyWith(
                color: context.cTextSec,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${m.durationMinutes} мин',
              style: t.labelSmall?.copyWith(color: context.cTextDim),
            ),
          ],
        ),
        const SizedBox(height: S.m),
        Text(
          m.title,
          style: t.displayMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.reason.isNotEmpty || m.description.isNotEmpty) ...[
          const SizedBox(height: S.s),
          Text(
            widget.reason.isNotEmpty ? widget.reason : m.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
        const SizedBox(height: S.l),
        Center(
          child: _PlayButton(
            pulseCtrl: _pulseCtrl,
            reduceMotion: _reduceMotion,
            onTap: () {
              HapticFeedback.mediumImpact();
              MeditationPlaybackCache.byId[m.id] = m;
              context.push('/play?id=${Uri.encodeComponent(m.id)}');
            },
          ),
        ),
        const SizedBox(height: S.m),
        Center(
          child: GestureDetector(
            onTap: () => context.push('/library'),
            child: Text(
              'или выбрать из библиотеки',
              style: t.bodySmall?.copyWith(
                color: C.primary,
                decoration: TextDecoration.underline,
                decorationColor: C.primary.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.pulseCtrl,
    required this.reduceMotion,
    required this.onTap,
  });

  final AnimationController pulseCtrl;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pulseCtrl,
      builder: (context, _) {
        final glowOpacity = reduceMotion
            ? 0.15
            : (0.1 + 0.1 * sin(pulseCtrl.value * 2 * pi));
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: C.gradientPrimary,
              boxShadow: [
                BoxShadow(
                  color: C.primary.withValues(alpha: glowOpacity),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: MIcon(MIconType.play, color: Colors.white, size: 32),
            ),
          ),
        );
      },
    );
  }
}
