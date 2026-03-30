import 'package:flutter/material.dart';

class StickerIcon extends StatelessWidget {
  const StickerIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 28,
    this.iconSize,
    this.showBackground = true,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final iSize = iconSize ?? size * 0.6;

    if (!showBackground) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withValues(alpha: 0.7)],
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Icon(icon, size: iSize, color: Colors.white),
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Colors.white, 0.3)!],
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Icon(icon, size: iSize, color: Colors.white),
        ),
      ),
    );
  }
}
