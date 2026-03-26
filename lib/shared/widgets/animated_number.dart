import 'package:flutter/material.dart';

class AnimatedNumber extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final String? suffix;

  const AnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 600),
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animValue, _) {
        final display = animValue.round();
        return Text(
          suffix != null ? '$display$suffix' : '$display',
          style: style ?? Theme.of(context).textTheme.titleLarge,
        );
      },
    );
  }
}
