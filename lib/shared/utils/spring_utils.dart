import 'package:flutter/physics.dart';

abstract class SpringUtils {
  static const gentle = SpringDescription(mass: 1, stiffness: 100, damping: 15);
  static const bouncy = SpringDescription(mass: 1, stiffness: 300, damping: 12);
  static const snappy = SpringDescription(mass: 1, stiffness: 500, damping: 25);

  static SpringSimulation simulation(
    SpringDescription spring, {
    double start = 0.0,
    double end = 1.0,
    double velocity = 0.0,
  }) =>
      SpringSimulation(spring, start, end, velocity);
}
