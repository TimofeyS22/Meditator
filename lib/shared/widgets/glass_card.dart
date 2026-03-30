import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';

enum GlassCardVariant {
  surface,
  glass,
  hero,
}

class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.variant = GlassCardVariant.glass,
    this.padding,
    this.onTap,
    this.showBorder = false,
    this.useBlur = false,
    this.blur = 12.0,
    this.opacity = 0.08,
    this.showGlow = false,
    this.glowColor,
    this.semanticLabel,
    this.showAnimatedBorder = false,
    this.borderGradientColors,
    this.showLightSweep = false,
    this.heroGradient,
  });

  final Widget child;
  final GlassCardVariant variant;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool showBorder;
  final bool useBlur;
  final double blur;
  final double opacity;
  final bool showGlow;
  final Color? glowColor;
  final String? semanticLabel;
  final bool showAnimatedBorder;
  final List<Color>? borderGradientColors;
  final bool showLightSweep;
  final Gradient? heroGradient;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> with TickerProviderStateMixin {
  late final AnimationController _borderCtrl;
  late final AnimationController _sweepCtrl;
  late final AnimationController _pressCtrl;
  bool _reduceMotion = false;
  DateTime _lastTap = DateTime(0);

  @override
  void initState() {
    super.initState();
    _borderCtrl = AnimationController(
      vsync: this,
      duration: Anim.borderRotation,
    );
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: Anim.lightSweep,
    );
    _pressCtrl = AnimationController(
      vsync: this,
      duration: Anim.fast,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rm = AccessibilityUtils.reduceMotion(context);
    if (_reduceMotion != rm) {
      _reduceMotion = rm;
      _syncAnimations();
    }
  }

  @override
  void didUpdateWidget(covariant GlassCard old) {
    super.didUpdateWidget(old);
    _syncAnimations();
  }

  void _syncAnimations() {
    if (_reduceMotion) {
      if (_borderCtrl.isAnimating) _borderCtrl.stop();
      if (_sweepCtrl.isAnimating) _sweepCtrl.stop();
      return;
    }
    if (widget.showAnimatedBorder && !_borderCtrl.isAnimating) {
      _borderCtrl.repeat();
    } else if (!widget.showAnimatedBorder && _borderCtrl.isAnimating) {
      _borderCtrl.stop();
    }
    if (widget.showLightSweep && !_sweepCtrl.isCompleted && !_sweepCtrl.isAnimating) {
      _sweepCtrl.forward();
    }
  }

  @override
  void dispose() {
    _borderCtrl.dispose();
    _sweepCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (_reduceMotion) return;
    _pressCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressCtrl.reverse();
  }

  void _onTapCancel() {
    _pressCtrl.reverse();
  }

  void _handleTap() {
    final now = DateTime.now();
    if (now.difference(_lastTap).inMilliseconds < 350) return;
    _lastTap = now;
    HapticFeedback.lightImpact();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final radius = BorderRadius.circular(R.l);
    final effectiveGlow = widget.glowColor ??
        (isLight ? C.lGlowPrimary : C.glowPrimary);
    final hasBorderAnim = widget.showAnimatedBorder && !_reduceMotion;
    final hasSweep = widget.showLightSweep && !_reduceMotion;

    final isSurface = widget.variant == GlassCardVariant.surface;
    final isHero = widget.variant == GlassCardVariant.hero;

    final Color cardColor;
    if (isHero) {
      cardColor = Colors.transparent;
    } else if (isSurface) {
      cardColor = isLight ? C.lCard : C.card;
    } else {
      cardColor = isLight
          ? C.lCard
          : Colors.white.withValues(alpha: widget.opacity);
    }
    final borderColor = isLight ? C.lSurfaceBorder : C.surfaceBorder;
    final showBorderEffective = isSurface ? true : widget.showBorder;
    final splashColor = isLight
        ? Colors.black.withValues(alpha: 0.03)
        : Colors.white.withValues(alpha: 0.05);
    final highlightColor = isLight
        ? Colors.black.withValues(alpha: 0.02)
        : Colors.white.withValues(alpha: 0.03);

    Widget inner = Semantics(
      button: widget.onTap != null,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap != null ? _handleTap : null,
          onTapDown: widget.onTap != null ? _onTapDown : null,
          onTapUp: widget.onTap != null ? _onTapUp : null,
          onTapCancel: widget.onTap != null ? _onTapCancel : null,
          borderRadius: radius,
          splashColor: splashColor,
          highlightColor: highlightColor,
          child: Ink(
            decoration: BoxDecoration(
              color: isHero ? null : cardColor,
              gradient: isHero
                  ? (widget.heroGradient ?? C.gradientPrimary)
                  : null,
              borderRadius: radius,
              border: !hasBorderAnim && showBorderEffective
                  ? Border.all(
                      color: isSurface
                          ? borderColor
                          : borderColor,
                      width: isSurface ? 0.5 : 0.5,
                    )
                  : null,
              boxShadow: isHero
                  ? [
                      BoxShadow(
                        color: C.primary.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : isLight
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
            ),
            child: Stack(
              children: [
                Padding(
                  padding: widget.padding ?? const EdgeInsets.all(S.m),
                  child: widget.child,
                ),
                if (hasSweep) _LightSweepOverlay(animation: _sweepCtrl),
              ],
            ),
          ),
        ),
      ),
    );

    Widget card;
    if (widget.useBlur && !isSurface) {
      card = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
          child: inner,
        ),
      );
    } else {
      card = ClipRRect(borderRadius: radius, child: inner);
    }

    if (hasBorderAnim) {
      card = _AnimatedBorderWrap(
        animation: _borderCtrl,
        borderRadius: R.l,
        colors: widget.borderGradientColors ??
            const [C.primary, C.accent, C.calm, C.primary],
        child: card,
      );
    }

    if (widget.onTap != null && !_reduceMotion) {
      card = ListenableBuilder(
        listenable: _pressCtrl,
        builder: (context, child) => Transform.scale(
          scale: 1.0 - 0.04 * _pressCtrl.value,
          child: child,
        ),
        child: card,
      );
    }

    if (!widget.showGlow) return card;

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: effectiveGlow, blurRadius: 24, spreadRadius: -4),
        ],
      ),
      child: card,
    );
  }
}

class _AnimatedBorderWrap extends StatelessWidget {
  const _AnimatedBorderWrap({
    required this.animation,
    required this.borderRadius,
    required this.colors,
    required this.child,
  });

  final Animation<double> animation;
  final double borderRadius;
  final List<Color> colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _GradientBorderPainter(
            progress: animation.value,
            borderRadius: borderRadius,
            colors: colors,
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  _GradientBorderPainter({
    required this.progress,
    required this.borderRadius,
    required this.colors,
  });

  final double progress;
  final double borderRadius;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final innerRRect = rrect.deflate(1.0);

    final rotation = progress * 2 * math.pi;
    final gradient = SweepGradient(
      startAngle: rotation,
      endAngle: rotation + 2 * math.pi,
      colors: colors,
      tileMode: TileMode.clamp,
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRRect(rrect)
      ..addRRect(innerRRect);
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    final glowPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rrect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter old) =>
      old.progress != progress;
}

class _LightSweepOverlay extends StatelessWidget {
  const _LightSweepOverlay({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        return Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(R.l),
              child: Opacity(
                opacity: (1.0 - t).clamp(0.0, 1.0) * 0.6,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1.0 + 3.0 * t, -0.5),
                      end: Alignment(-0.5 + 3.0 * t, 0.5),
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.35, 0.65, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
