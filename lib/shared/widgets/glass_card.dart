import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:meditator/app/theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.showBorder = false,
    this.useBlur = false,
    this.blur = 12.0,
    this.opacity = 0.08,
    this.showGlow = false,
    this.glowColor,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool showBorder;
  final bool useBlur;
  final double blur;
  final double opacity;
  final bool showGlow;
  final Color? glowColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(R.l);
    final effectiveGlow = glowColor ?? C.glowPrimary;

    Widget inner = Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: Colors.white.withValues(alpha: 0.05),
          highlightColor: Colors.white.withValues(alpha: 0.03),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              borderRadius: radius,
              border: showBorder
                  ? Border.all(color: C.surfaceBorder, width: 0.5)
                  : null,
            ),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(S.m),
              child: child,
            ),
          ),
        ),
      ),
    );

    Widget card;
    if (useBlur) {
      card = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: inner,
        ),
      );
    } else {
      card = ClipRRect(borderRadius: radius, child: inner);
    }

    if (!showGlow) return card;

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
