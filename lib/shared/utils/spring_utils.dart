import 'package:flutter/physics.dart';

abstract class SpringUtils {
  static const gentle = SpringDescription(mass: 1, stiffness: 100, damping: 15);
  static const bouncy = SpringDescription(mass: 1, stiffness: 300, damping: 12);
  static const snappy = SpringDescription(mass: 1, stiffness: 500, damping: 25);

  static const soft = SpringDescription(mass: 1.2, stiffness: 80, damping: 18);
  static const responsive = SpringDescription(mass: 0.8, stiffness: 400, damping: 20);
  static const dramatic = SpringDescription(mass: 1.5, stiffness: 120, damping: 14);
  static const page = SpringDescription(mass: 1, stiffness: 200, damping: 22);
  static const dismiss = SpringDescription(mass: 1, stiffness: 350, damping: 28);

  // Micro-interaction springs
  static const button = SpringDescription(mass: 0.6, stiffness: 600, damping: 18);
  static const pill = SpringDescription(mass: 0.5, stiffness: 500, damping: 22);
  static const card = SpringDescription(mass: 1.2, stiffness: 180, damping: 20);
  static const indicator = SpringDescription(mass: 0.7, stiffness: 380, damping: 24);
  static const rubberBand = SpringDescription(mass: 1.4, stiffness: 60, damping: 12);
  static const morphing = SpringDescription(mass: 0.9, stiffness: 250, damping: 22);

  static SpringSimulation simulation(
    SpringDescription spring, {
    double start = 0.0,
    double end = 1.0,
    double velocity = 0.0,
  }) =>
      SpringSimulation(spring, start, end, velocity);
}
