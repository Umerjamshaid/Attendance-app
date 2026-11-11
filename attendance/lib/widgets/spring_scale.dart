import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../config/ui_tokens.dart';

/// Local spring feedback that never changes layout or the control's hit area.
class SpringScale extends StatefulWidget {
  const SpringScale({super.key, required this.pressed, required this.child});
  final bool pressed;
  final Widget child;

  @override
  State<SpringScale> createState() => _SpringScaleState();
}

class _SpringScaleState extends State<SpringScale>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController.unbounded(vsync: this, value: 1);
  double get _target => widget.pressed ? .97 : 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settle();
  }

  @override
  void didUpdateWidget(SpringScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pressed != widget.pressed) _settle();
  }

  void _settle() {
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _controller.stop();
      _controller.value = _target;
    } else if (_controller.isAnimating ||
        (_controller.value - _target).abs() > .0001) {
      _controller.animateWith(
        SpringSimulation(
          AppMotion.pressSpring,
          _controller.value,
          _target,
          _controller.velocity,
          snapToEnd: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (_, child) => Transform.scale(
      scale: _controller.value,
      transformHitTests: false,
      child: child,
    ),
  );
}
