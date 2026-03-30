import 'package:flutter/services.dart';

abstract class Haptics {
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void heavy() => HapticFeedback.heavyImpact();
  static void selection() => HapticFeedback.selectionClick();

  static void tap() => lightImpact();
  static void buttonPress() => mediumImpact();
  static void success() => HapticFeedback.heavyImpact();

  static void lightImpact() => HapticFeedback.lightImpact();
  static void mediumImpact() => HapticFeedback.mediumImpact();
}
