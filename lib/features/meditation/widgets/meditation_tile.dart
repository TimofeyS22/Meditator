import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/features/home/meditation_playback_cache.dart';
import 'package:meditator/shared/models/meditation.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
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

    return GlassCard(
      onTap: () {
        HapticFeedback.lightImpact();
        MeditationPlaybackCache.byId[meditation.id] = meditation;
        context.push('/play?id=${Uri.encodeComponent(meditation.id)}');
      },
      semanticLabel:
          'Медитация ${meditation.title}, ${meditation.durationMinutes} минут',
      padding: const EdgeInsets.all(S.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meditation.category.emoji,
                style: const TextStyle(fontSize: 32),
              ),
              if (meditation.isPremium)
                Shimmer.fromColors(
                  baseColor: C.gold,
                  highlightColor: C.accentLight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: S.s, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: C.gradientGold,
                      borderRadius: BorderRadius.circular(R.s),
                    ),
                    child: Text(
                      'PRO',
                      style: t.labelSmall?.copyWith(
                        color: C.bg,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            meditation.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.titleMedium
                ?.copyWith(color: C.text, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: S.xs),
          Text(
            meditation.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.bodySmall?.copyWith(color: C.textDim, height: 1.3),
          ),
          const SizedBox(height: S.s),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: S.s, vertical: 3),
            decoration: BoxDecoration(
              color: meditation.category.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(R.full),
            ),
            child: Text(
              '${meditation.durationMinutes} мин',
              style: t.labelSmall?.copyWith(
                color: meditation.category.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
}
