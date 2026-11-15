import 'package:flutter/material.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart';

/// One-shot selection/activation feedback; the parent owns gestures and semantics.
class AnimatedAppIcon extends StatefulWidget {
  const AnimatedAppIcon({
    super.key,
    required this.icon,
    required this.selected,
    this.activationCount = 0,
    this.size = 24,
    this.color,
  });
  final LucideAnimatedIconData icon;
  final bool selected;

  /// Increment on activation to replay an already-selected icon.
  final int activationCount;
  final double size;
  final Color? color;

  @override
  State<AnimatedAppIcon> createState() => _AnimatedAppIconState();
}

class _AnimatedAppIconState extends State<AnimatedAppIcon> {
  final _controller = LucideAnimatedIconController();
  bool get _reduced =>
      MediaQuery.disableAnimationsOf(context) ||
      !TickerMode.valuesOf(context).enabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduced) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void didUpdateWidget(AnimatedAppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected &&
        (!oldWidget.selected ||
            oldWidget.activationCount != widget.activationCount)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.selected && !_reduced) _controller.animate();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: LucideAnimatedIcon(
        icon: widget.icon,
        size: widget.size,
        color:
            widget.color ??
            IconTheme.of(context).color ??
            Theme.of(context).colorScheme.onSurfaceVariant,
        strokeWidth: 2.5,
        duration: const Duration(milliseconds: 360),
        trigger: AnimationTrigger.manual,
        controller: _controller,
      ),
    ),
  );
}
