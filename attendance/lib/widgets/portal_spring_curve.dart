// Adapted from Portal Labs (MIT), copyright 2026 Luis Portal.
// See assets/licenses/PortalLabs-MIT.txt.
import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// A lightly damped spring for position changes, never opacity or color.
class PortalSpringCurve extends Curve {
  const PortalSpringCurve({
    this.mass = .5,
    this.stiffness = 200,
    this.damping = 18,
  });

  final double mass;
  final double stiffness;
  final double damping;

  @override
  double transformInternal(double t) => SpringSimulation(
    SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
    0,
    1,
    0,
  ).x(t).clamp(-.1, 1.1);
}
