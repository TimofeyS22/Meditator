import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/subscription/subscription_service.dart';
import 'package:meditator/features/home/meditation_playback_cache.dart';
import 'package:meditator/shared/models/meditation.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/download_button.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/sticker_icon.dart';
import 'package:shimmer/shimmer.dart';

class MeditationTile extends StatelessWidget {
  const MeditationTile({
    super.key,
    required this.meditation,
    this.index = 0,
  });

  final Meditation meditation;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final delay = (60 * index).ms;

    final card = GlassCard(
      variant: GlassCardVariant.surface,
      onTap: () {
        if (meditation.isPremium && !SubscriptionService.instance.isPremium.value) {
          context.push('/paywall');
          return;
        }
        MeditationPlaybackCache.byId[meditation.id] = meditation;
        context.push('/play?id=${Uri.encodeComponent(meditation.id)}');
      },
      semanticLabel:
          'Медитация ${meditation.title}, ${meditation.durationMinutes} минут',
      padding: const EdgeInsets.all(S.m),
      child: SizedBox.expand(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StickerIcon(
                  icon: meditation.category.iconData,
                  color: meditation.category.color,
                  size: 18,
                  showBackground: false,
                ),
                if (meditation.isPremium)
                  Shimmer.fromColors(
                    baseColor: C.gold,
                    highlightColor: C.accentLight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: S.s, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: C.gradientGold,
                        borderRadius: BorderRadius.circular(R.s),
                      ),
                      child: Text(
                        'PRO',
                        style: t.labelSmall?.copyWith(
                          color: C.bg,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Flexible(
              child: Hero(
                tag: 'med_title_${meditation.id}',
                flightShuttleBuilder: (_, anim, __, ___, ____) =>
                    DefaultTextStyle(
                  style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600) ??
                      const TextStyle(),
                  child: Text(
                    meditation.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                child: Text(
                  meditation.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              meditation.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall?.copyWith(height: 1.3),
            ),
            const SizedBox(height: S.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: S.s, vertical: 2),
                  decoration: BoxDecoration(
                    color: meditation.category.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(R.full),
                  ),
                  child: Text(
                    '${meditation.durationMinutes} мин',
                    style: t.labelSmall?.copyWith(
                      color: meditation.category.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (meditation.audioUrl != null && meditation.audioUrl!.isNotEmpty)
                  DownloadButton(meditation: meditation, size: 28, iconSize: 16),
              ],
            ),
          ],
        ),
      ),
    );
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showPreview(context);
      },
      child: card,
    )
        .animate()
        .fadeIn(delay: delay, duration: Anim.normal)
        .scaleXY(
            begin: 0.92,
            end: 1.0,
            delay: delay,
            duration: Anim.normal,
            curve: Anim.curve);
  }

  void _showPreview(BuildContext context) {
    final t = Theme.of(context).textTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: ctx.cSurface.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(R.xl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(S.l, S.m, S.l, S.l),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ctx.cTextDim.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: S.l),
                Row(
                  children: [
                    StickerIcon(
                      icon: meditation.category.iconData,
                      color: meditation.category.color,
                      size: 36,
                    ),
                    const SizedBox(width: S.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meditation.title,
                            style: t.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${meditation.category.label} · ${meditation.durationMinutes} мин',
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: S.l),
                Text(
                  meditation.description,
                  style: t.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: S.xl),
                  SizedBox(
                  width: double.infinity,
                  child: GlowButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (meditation.isPremium && !SubscriptionService.instance.isPremium.value) {
                        context.push('/paywall');
                        return;
                      }
                      MeditationPlaybackCache.byId[meditation.id] = meditation;
                      context.push(
                        '/play?id=${Uri.encodeComponent(meditation.id)}',
                      );
                    },
                    showGlow: true,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MIcon(MIconType.play, size: 20, color: Colors.white),
                        SizedBox(width: S.s),
                        Text('Слушать'),
                      ],
                    ),
                  ),
                ),
              ],
            )
                .animate()
                .slideY(
                  begin: 0.15,
                  end: 0,
                  duration: 500.ms,
                  curve: Anim.curveGentle,
                )
                .fadeIn(duration: 300.ms),
          ),
        ),
      ),
    );
  }
}
