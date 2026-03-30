import 'package:flutter/material.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/widgets/shimmer_loading.dart';

class JournalSkeleton extends StatelessWidget {
  const JournalSkeleton({super.key, this.count = 5});
  final int count;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: S.m),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: S.m),
            child: _JournalEntrySkeleton(index: i),
          ),
          childCount: count,
        ),
      ),
    );
  }
}

class _JournalEntrySkeleton extends StatelessWidget {
  const _JournalEntrySkeleton({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(R.l),
        border: Border.all(color: context.cSurfaceBorder, width: 0.5),
      ),
      padding: const EdgeInsets.all(S.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLoading(width: 32, height: 32, borderRadius: R.full, organic: true),
          const SizedBox(width: S.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerLoading(width: 80, height: 14, organic: true),
                    ShimmerLoading(width: 50, height: 12, organic: true),
                  ],
                ),
                const SizedBox(height: S.s),
                ShimmerLoading(width: double.infinity, height: 12, organic: true),
                const SizedBox(height: S.xs),
                ShimmerLoading(width: 180, height: 12, organic: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LibrarySkeleton extends StatelessWidget {
  const LibrarySkeleton({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(S.m, 0, S.m, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: S.m,
        crossAxisSpacing: S.m,
        childAspectRatio: 0.75,
      ),
      itemCount: count,
      itemBuilder: (_, i) => const _MeditationTileSkeleton(),
    );
  }
}

class _MeditationTileSkeleton extends StatelessWidget {
  const _MeditationTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(R.l),
        border: Border.all(color: context.cSurfaceBorder, width: 0.5),
      ),
      padding: const EdgeInsets.all(S.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLoading(width: 36, height: 36, borderRadius: R.full, organic: true),
          const Spacer(),
          ShimmerLoading(width: double.infinity, height: 14, organic: true),
          const SizedBox(height: S.s),
          ShimmerLoading(width: 80, height: 12, organic: true),
          const SizedBox(height: S.s),
          ShimmerLoading(width: 60, height: 10, organic: true),
        ],
      ),
    );
  }
}

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: S.m),
      child: Column(
        children: [
          const SizedBox(height: S.xl),
          const ShimmerLoading(width: 80, height: 80, borderRadius: 40, organic: true),
          const SizedBox(height: S.m),
          const ShimmerLoading(width: 140, height: 18, organic: true),
          const SizedBox(height: S.s),
          const ShimmerLoading(width: 200, height: 14, organic: true),
          const SizedBox(height: S.l),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (_) => const _StatSkeleton()),
          ),
          const SizedBox(height: S.l),
          ...List.generate(
            3,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: S.m),
              child: ShimmerLoading(width: double.infinity, height: 64, organic: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatSkeleton extends StatelessWidget {
  const _StatSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        ShimmerLoading(width: 48, height: 48, borderRadius: 24, organic: true),
        SizedBox(height: S.xs),
        ShimmerLoading(width: 40, height: 10, organic: true),
      ],
    );
  }
}

class GardenSkeleton extends StatelessWidget {
  const GardenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(S.m),
      child: Column(
        children: [
          const ShimmerLoading(width: double.infinity, height: 200, borderRadius: R.l, organic: true),
          const SizedBox(height: S.m),
          Row(
            children: [
              Expanded(child: ShimmerLoading(width: double.infinity, height: 80, borderRadius: R.l, organic: true)),
              const SizedBox(width: S.m),
              Expanded(child: ShimmerLoading(width: double.infinity, height: 80, borderRadius: R.l, organic: true)),
            ],
          ),
        ],
      ),
    );
  }
}
