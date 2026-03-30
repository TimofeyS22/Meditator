import 'dart:math';

import 'package:flutter/material.dart';

class RubberBandScrollPhysics extends BouncingScrollPhysics {
  const RubberBandScrollPhysics({super.parent});

  @override
  RubberBandScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return RubberBandScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double frictionFactor(double overscrollFraction) {
    return 0.52 * pow(1 - overscrollFraction, 2);
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.3,
        stiffness: 75.0,
        damping: 1.1,
      );
}
