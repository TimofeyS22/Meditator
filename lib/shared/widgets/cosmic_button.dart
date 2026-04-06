import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meditator/shared/theme/cosmic.dart';

class CosmicButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double? width;
  final bool isLoading;
  final LinearGradient gradient;

  const CosmicButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.width,
    this.isLoading = false,
    this.gradient = Cosmic.gradientPrimary,
  });

  @override
  State<CosmicButton> createState() => _CosmicButtonState();
}

class _CosmicButtonState extends State<CosmicButton>
    with TickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  void _onTap() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pressCtrl, _glowCtrl]),
      builder: (_, __) {
        final scale = 1.0 - 0.04 * _pressCtrl.value;
        final glowAlpha = _enabled ? 0.25 + 0.2 * _glowCtrl.value : 0.0;
        final glowColor = widget.gradient.colors.first;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.width,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.lg),
              boxShadow: glowAlpha > 0
                  ? [
                      BoxShadow(
                        color: glowColor.withValues(alpha: glowAlpha),
                        blurRadius: 32,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _enabled ? _onTap : null,
                onTapDown: _enabled ? (_) => _pressCtrl.forward() : null,
                onTapUp: _enabled ? (_) => _pressCtrl.reverse() : null,
                onTapCancel: _enabled ? () => _pressCtrl.reverse() : null,
                borderRadius: BorderRadius.circular(Radii.lg),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: _enabled ? widget.gradient : null,
                    color: _enabled ? null : Cosmic.surfaceLight,
                    borderRadius: BorderRadius.circular(Radii.lg),
                  ),
                  child: Center(
                    child: widget.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : DefaultTextStyle.merge(
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              letterSpacing: 0.3,
                            ),
                            child: widget.child,
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
