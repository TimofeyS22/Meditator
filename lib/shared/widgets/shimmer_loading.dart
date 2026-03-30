import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';

class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool organic;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = R.m,
    this.organic = false,
  });

  @override
  Widget build(BuildContext context) {
    if (AccessibilityUtils.reduceMotion(context)) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.cShimmerBase,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      );
    }
    if (organic) {
      return _OrganicShimmer(width: width, height: height);
    }
    return Shimmer.fromColors(
      baseColor: context.cShimmerBase,
      highlightColor: context.cShimmerHL,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.cShimmerBase,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class BreathingLoader extends StatefulWidget {
  const BreathingLoader({
    super.key,
    this.size = 60,
    this.color = C.primary,
    this.secondaryColor = C.accent,
    this.message,
  });

  final double size;
  final Color color;
  final Color secondaryColor;
  final String? message;

  @override
  State<BreathingLoader> createState() => _BreathingLoaderState();
}

class _BreathingLoaderState extends State<BreathingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rm = AccessibilityUtils.reduceMotion(context);
    if (_reduceMotion != rm) {
      _reduceMotion = rm;
      if (_reduceMotion) {
        _ctrl.stop();
      } else if (!_ctrl.isAnimating) {
        _ctrl.repeat();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      label: widget.message ?? 'Загрузка',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => CustomPaint(
                  painter: _BreathingLoaderPainter(
                    progress: _reduceMotion ? 0.5 : _ctrl.value,
                    color: widget.color,
                    secondaryColor: widget.secondaryColor,
                  ),
                ),
              ),
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: S.m),
            Text(
              widget.message!,
              style: t.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _BreathingLoaderPainter extends CustomPainter {
  _BreathingLoaderPainter({
    required this.progress,
    required this.color,
    required this.secondaryColor,
  });

  final double progress;
  final Color color;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final t = progress * 2 * math.pi;

    final breathScale = 0.6 + 0.4 * ((math.sin(t) + 1) / 2);
    final r = maxR * breathScale;

    canvas.drawCircle(
      center,
      r * 1.3,
      Paint()
        ..color = color.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    canvas.drawCircle(
      center,
      r * 1.1,
      Paint()
        ..color = secondaryColor.withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final gradient = RadialGradient(
      colors: [
        color.withValues(alpha: 0.5 + 0.2 * breathScale),
        secondaryColor.withValues(alpha: 0.3),
        color.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    canvas.drawCircle(
      center,
      r,
      Paint()..shader = gradient.createShader(Rect.fromCircle(center: center, radius: r)),
    );

    for (var i = 0; i < 3; i++) {
      final ringProgress = (progress + i * 0.33) % 1.0;
      final ringScale = 0.5 + ringProgress * 0.8;
      final ringAlpha = (0.3 * (1.0 - ringProgress)).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        maxR * ringScale,
        Paint()
          ..color = color.withValues(alpha: ringAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BreathingLoaderPainter old) =>
      old.progress != progress;
}

class _OrganicShimmer extends StatefulWidget {
  const _OrganicShimmer({required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<_OrganicShimmer> createState() => _OrganicShimmerState();
}

class _OrganicShimmerState extends State<_OrganicShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => CustomPaint(
            painter: _OrganicShimmerPainter(
              progress: _ctrl.value,
              shimmerBase: context.cShimmerBase,
              shimmerHL: context.cShimmerHL,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrganicShimmerPainter extends CustomPainter {
  _OrganicShimmerPainter({
    required this.progress,
    required this.shimmerBase,
    required this.shimmerHL,
  });

  final double progress;
  final Color shimmerBase;
  final Color shimmerHL;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(R.l));
    canvas.drawRRect(rrect, Paint()..color = shimmerBase);

    final t = progress;
    final sweepGradient = LinearGradient(
      begin: Alignment(-1.0 + 3.0 * t, -0.3),
      end: Alignment(-0.3 + 3.0 * t, 0.3),
      colors: [
        Colors.transparent,
        shimmerHL.withValues(alpha: 0.4),
        C.primary.withValues(alpha: 0.06),
        shimmerHL.withValues(alpha: 0.4),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
    );

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(rect, Paint()..shader = sweepGradient.createShader(rect));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrganicShimmerPainter old) =>
      old.progress != progress ||
      old.shimmerBase != shimmerBase ||
      old.shimmerHL != shimmerHL;
}
