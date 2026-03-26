import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:meditator/app/theme.dart';

class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = R.m,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: C.shimmerBase,
      highlightColor: C.shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: C.shimmerBase,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
