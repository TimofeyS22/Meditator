import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';
import 'package:meditator/shared/utils/spring_utils.dart';

enum GlowButtonVariant { primary, secondary }

class GlowButton extends StatefulWidget {
  const GlowButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = GlowButtonVariant.primary,
    this.width,
    this.isLoading = false,
    this.showGlow = false,
    this.glowColor = C.glowPrimary,
    this.semanticLabel,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final GlowButtonVariant variant;
  final double? width;
  final bool isLoading;
  final bool showGlow;
  final Color glowColor;
  final String? semanticLabel;

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton>
    with TickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _shimmerCtrl;
  bool _reduceMotion = false;
  DateTime _lastTap = DateTime(0);

  @override
  void initState() {
    super.initState();

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.showGlow) _glowCtrl.repeat(reverse: true);

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _shimmerCtrl.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      if (_glowCtrl.isAnimating) _glowCtrl.stop();
      _glowCtrl.value = 0;
    } else if (widget.showGlow && !_glowCtrl.isAnimating) {
      _glowCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(GlowButton old) {
    super.didUpdateWidget(old);
    if (_reduceMotion) {
      if (_glowCtrl.isAnimating) _glowCtrl.stop();
      _glowCtrl.value = 0;
      return;
    }
    if (widget.showGlow && !_glowCtrl.isAnimating) {
      _glowCtrl.repeat(reverse: true);
    } else if (!widget.showGlow && _glowCtrl.isAnimating) {
      _glowCtrl.stop();
      _glowCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    _glowCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onPressed != null && !widget.isLoading;
  bool get _isSecondary => widget.variant == GlowButtonVariant.secondary;

  void _onTap() {
    if (!_enabled) return;
    final now = DateTime.now();
    if (now.difference(_lastTap).inMilliseconds < 400) return;
    _lastTap = now;
    HapticFeedback.lightImpact();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final semanticsValue = widget.isLoading ? 'Загрузка' : null;
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_pressCtrl, _glowCtrl, _shimmerCtrl]),
      builder: (context, _) {
        final scale = reduceMotion ? 1.0 : (1.0 - 0.05 * _pressCtrl.value);
        final glowT = reduceMotion ? 0.0 : _glowCtrl.value;

        return Semantics(
          button: true,
          enabled: _enabled,
          label: widget.semanticLabel,
          value: semanticsValue,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: widget.width,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(R.xl),
                boxShadow: widget.showGlow && !_isSecondary
                    ? [
                        BoxShadow(
                          color: widget.glowColor
                              .withValues(alpha: 0.3 + 0.3 * glowT),
                          blurRadius: 16 + 8 * glowT,
                          spreadRadius: -2 + 4 * glowT,
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _enabled ? _onTap : null,
                  onTapDown: _enabled ? (_) => _pressCtrl.forward() : null,
                  onTapUp: _enabled
                      ? (_) => _pressCtrl.animateWith(
                            SpringSimulation(
                              SpringUtils.bouncy,
                              _pressCtrl.value,
                              0.0,
                              0.0,
                            ),
                          )
                      : null,
                  onTapCancel: _enabled
                      ? () => _pressCtrl.animateWith(
                            SpringSimulation(
                              SpringUtils.bouncy,
                              _pressCtrl.value,
                              0.0,
                              0.0,
                            ),
                          )
                      : null,
                  borderRadius: BorderRadius.circular(R.xl),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: _isSecondary
                          ? null
                          : (_enabled ? C.gradientPrimary : null),
                      color: _isSecondary
                          ? Colors.transparent
                          : (_enabled ? null : (Theme.of(context).brightness == Brightness.light ? C.lSurfaceLight : C.surfaceLight)),
                      borderRadius: BorderRadius.circular(R.xl),
                      border: _isSecondary
                          ? Border.all(
                              color: _enabled
                                  ? C.primary.withValues(alpha: 0.4)
                                  : (Theme.of(context).brightness == Brightness.light ? C.lSurfaceBorder : C.surfaceBorder),
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(R.xl),
                      child: Stack(
                        children: [
                          if (!_isSecondary && !_shimmerCtrl.isCompleted && !reduceMotion)
                            Positioned.fill(child: _buildShimmer()),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: S.l),
                              child: widget.isLoading
                                  ? _PulsatingDots(reduceMotion: reduceMotion)
                                  : DefaultTextStyle.merge(
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: _isSecondary
                                            ? (_enabled ? C.primary : (Theme.of(context).brightness == Brightness.light ? C.lTextDim : C.textDim))
                                            : Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ) ?? const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                      child: widget.child,
                                    ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildShimmer() {
    final t = _shimmerCtrl.value;
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1.0 + 3.0 * t, 0),
            end: Alignment(-0.5 + 3.0 * t, 0),
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.15),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsatingDots extends StatefulWidget {
  const _PulsatingDots({this.reduceMotion = false});

  final bool reduceMotion;

  @override
  State<_PulsatingDots> createState() => _PulsatingDotsState();
}

class _PulsatingDotsState extends State<_PulsatingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (!widget.reduceMotion) _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: SizedBox(
            width: 8,
            height: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
        )),
      );
    }
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = i * 0.33;
            final t = ((_ctrl.value + phase) % 1.0);
            final s = (0.4 + 0.6 * sin(t * pi)).clamp(0.4, 1.0);
            final o = (0.3 + 0.7 * sin(t * pi)).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.scale(
                scale: s,
                child: Opacity(
                  opacity: o,
                  child: const SizedBox(
                    width: 8,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
