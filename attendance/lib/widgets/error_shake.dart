// Adapted from Block Buzz, Copyright 2026 Block, Inc., Apache-2.0.
// Source: features/pairing/pairing_page/pairing_error_shake.dart.
import 'package:flutter/material.dart';

/// Inline error feedback. Increment [revision] to repeat an unchanged error.
class ErrorShake extends StatefulWidget {
  const ErrorShake({
    super.key,
    required this.child,
    this.error,
    this.revision = 0,
  });

  final Widget child;
  final String? error;
  final int revision;

  @override
  State<ErrorShake> createState() => _ErrorShakeState();
}

class _ErrorShakeState extends State<ErrorShake>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final _offset = TweenSequence<double>([
    for (final (begin, end, weight) in [
      (0.0, 6.0, 80.0),
      (6.0, -6.0, 80.0),
      (-6.0, 4.0, 60.0),
      (4.0, 0.0, 60.0),
    ])
      TweenSequenceItem(
        tween: Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: const Cubic(0.22, 1, 0.36, 1))),
        weight: weight,
      ),
  ]).animate(_controller);
  bool get _enabled =>
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.valuesOf(context).enabled;
  bool _initialized = false;

  @override
  void didUpdateWidget(covariant ErrorShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.error == null || !_enabled) {
      _controller.reset();
    } else if (widget.error != oldWidget.error ||
        widget.revision != oldWidget.revision) {
      _controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_enabled) {
      _controller.reset();
    } else if (!_initialized && widget.error != null && widget.revision > 0) {
      _controller.forward(from: 0);
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _offset,
    builder: (_, child) => Transform.translate(
      offset: Offset(_enabled ? _offset.value : 0, 0),
      child: child,
    ),
    child: widget.child,
  );
}
