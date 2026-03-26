import 'package:flutter/material.dart';

abstract class AccessibilityUtils {
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.of(context).disableAnimations;

  static double textScale(BuildContext context) =>
      MediaQuery.of(context).textScaler.scale(1.0);

  static Duration adjustedDuration(BuildContext context, Duration base) =>
      reduceMotion(context) ? Duration.zero : base;
}
