// Adapted from Portal Labs (MIT), copyright 2026 Luis Portal.
// See assets/licenses/PortalLabs-MIT.txt.
import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// A lightly damped spring for position changes, never opacity or color.
class PortalSpringCurve extends Curve {
  const PortalSpringCurve();

  @override
  double transformInternal(double t) => SpringSimulation(
    const SpringDescription(mass: .5, stiffness: 200, damping: 18),
    0,
    1,
    0,
  ).x(t).clamp(-.1, 1.1);
}
