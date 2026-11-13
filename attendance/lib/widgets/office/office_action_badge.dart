// Adapted from Block Buzz, Copyright 2026 Block, Inc., Apache-2.0.
// Modified for native controllers, Office actions and this app's theme.
// See docs/third-party-animations.md and assets/licenses/Buzz-Apache-2.0.txt.
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import '../../config/app_icons.dart';
import '../../config/app_theme.dart';

class OfficeActionBadge extends StatefulWidget {
  const OfficeActionBadge({
    super.key,
    required this.officeId,
    required this.name,
    required this.isActive,
    required this.isEditing,
    this.onRemove,
  });
  final String officeId, name;
  final bool isActive, isEditing;
  final VoidCallback? onRemove;
  @override
  State<OfficeActionBadge> createState() => _OfficeActionBadgeState();
}

class _OfficeActionBadgeState extends State<OfficeActionBadge>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: widget.isEditing ? 1 : 0,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(OfficeActionBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.isEditing ? 1 : 0;
    } else if (widget.isEditing) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final t = Curves.easeInOutCubic.transform(_controller.value);
      final colors = Theme.of(context).colorScheme;
      final size = widget.isActive ? lerpDouble(24, 36, t)! : 36.0;
      final foreground = widget.isActive
          ? Color.lerp(Colors.white, colors.onErrorContainer, t)!
          : colors.onErrorContainer;
      return SizedBox.square(
        dimension: 48,
        child: IconButton(
          key: ValueKey(
            'office-${widget.isEditing ? 'remove' : 'selection'}-${widget.officeId}',
          ),
          tooltip: widget.isEditing
              ? 'Remove ${widget.name} from switcher'
              : null,
          padding: EdgeInsets.zero,
          onPressed: widget.isEditing ? widget.onRemove : null,
          icon: Opacity(
            opacity: widget.isActive ? 1 : t,
            child: Transform.scale(
              scale: widget.isActive ? 1 : lerpDouble(.9, 1, t)!,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isActive
                      ? Color.lerp(
                          context.attendancePresent,
                          colors.errorContainer,
                          t,
                        )
                      : colors.errorContainer,
                  border: Border.all(color: colors.surface, width: 2),
                ),
                child: Center(
                  child: widget.isActive && t > 0 && t < 1
                      ? CustomPaint(
                          key: ValueKey(
                            'office-badge-morph-${widget.officeId}',
                          ),
                          size: Size.square(lerpDouble(14, 18, t)!),
                          painter: _ActionGlyphPainter(t, foreground),
                        )
                      : widget.isActive && t == 0
                      ? Icon(AppIcons.check, color: foreground, size: 14)
                      : t > 0
                      ? Icon(AppIcons.trash, color: foreground, size: 18)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Buzz's check-to-bin path interpolation, with Tabler glyphs at both endpoints.
class _ActionGlyphPainter extends CustomPainter {
  const _ActionGlyphPainter(this.progress, this.color);
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Offset point(Offset check, Offset trash) =>
        Offset.lerp(check, trash, progress)!;
    final start = point(const Offset(4, 12), const Offset(5, 6));
    final path = Path()..moveTo(start.dx, start.dy);
    void line(Offset check, Offset trash) {
      final p = point(check, trash);
      path.lineTo(p.dx, p.dy);
    }

    void curve(
      Offset checkControl,
      Offset checkEnd,
      Offset trashControl,
      Offset trashEnd,
    ) {
      final c = point(checkControl, trashControl);
      final p = point(checkEnd, trashEnd);
      path.quadraticBezierTo(c.dx, c.dy, p.dx, p.dy);
    }

    line(const Offset(7, 15), const Offset(5, 20));
    curve(
      const Offset(8, 16),
      const Offset(9, 17),
      const Offset(5, 22),
      const Offset(7, 22),
    );
    line(const Offset(14.5, 11.5), const Offset(17, 22));
    curve(
      const Offset(17.25, 8.75),
      const Offset(20, 6),
      const Offset(19, 22),
      const Offset(19, 20),
    );
    line(const Offset(20, 6), const Offset(19, 6));
    canvas.drawPath(path, paint);
    paint.color = color.withValues(alpha: progress);
    canvas.drawPath(
      Path()
        ..moveTo(3, 6)
        ..lineTo(21, 6)
        ..moveTo(9, 6)
        ..lineTo(9, 4)
        ..quadraticBezierTo(9, 2, 11, 2)
        ..lineTo(13, 2)
        ..quadraticBezierTo(15, 2, 15, 4)
        ..lineTo(15, 6)
        ..moveTo(10, 10)
        ..lineTo(10, 16)
        ..moveTo(14, 10)
        ..lineTo(14, 16),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ActionGlyphPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
