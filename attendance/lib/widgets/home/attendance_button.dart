import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motor/motor.dart';

import '../../config/app_icons.dart';
import '../../config/app_theme.dart';
import '../../config/ui_tokens.dart';

/// Round check-in action with a halo that runs only while ready and visible.
class AttendanceButton extends StatefulWidget {
  const AttendanceButton({
    super.key,
    required this.isLoading,
    required this.onTap,
    required this.isUploadEnabled,
    required this.uploadLabel,
    this.pulseEnabled = true,
  });

  final bool isLoading;
  final VoidCallback onTap;
  final bool isUploadEnabled;
  final String uploadLabel;
  final bool pulseEnabled;

  @override
  State<AttendanceButton> createState() => _AttendanceButtonState();
}

class _AttendanceButtonState extends State<AttendanceButton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  );
  late final _ringScale = _pulse.drive(
    Tween(begin: .84, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic)),
  );
  late final _ringOpacity = _pulse.drive(Tween(begin: .8, end: 0.0));
  late final AppLifecycleListener _lifecycle;

  bool _pressed = false;
  bool _animate = false;
  bool get _enabled => widget.isUploadEnabled && !widget.isLoading;
  bool get _hasPulse => _enabled && _animate && widget.pulseEnabled;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: (_) => _syncPulse());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    _syncPulse();
  }

  @override
  void didUpdateWidget(AttendanceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) _pressed = false;
    _syncPulse();
  }

  void _syncPulse() {
    final state = WidgetsBinding.instance.lifecycleState;
    if (_hasPulse && (state == null || state == AppLifecycleState.resumed)) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else if (_pulse.isAnimating) {
      _pulse.reset();
    }
  }

  void _setPressed(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final busy = widget.isUploadEnabled && widget.isLoading;
    final background = _enabled
        ? colors.primary
        : busy
        ? colors.primaryContainer
        : colors.surfaceContainer;
    final foreground = _enabled
        ? colors.onPrimary
        : busy
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    final glyph = busy
        ? AppIcons.clock
        : widget.isUploadEnabled
        ? AppIcons.camera
        : AppIcons.lock;
    const shape = CircleBorder();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.gutter),
      child: SizedBox(
        width: 208,
        child: AspectRatio(
          aspectRatio: 1,
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_enabled)
                  FractionallySizedBox(
                    widthFactor: .92,
                    heightFactor: .92,
                    child: _ring(colors.primary.withValues(alpha: .22)),
                  ),
                if (_hasPulse)
                  FadeTransition(
                    opacity: _ringOpacity,
                    child: ScaleTransition(
                      key: const ValueKey('check-in-pulse'),
                      scale: _ringScale,
                      child: _ring(colors.primary.withValues(alpha: .52)),
                    ),
                  ),
                FractionallySizedBox(
                  widthFactor: .82,
                  heightFactor: .82,
                  child: Semantics(
                    button: true,
                    enabled: _enabled,
                    liveRegion: busy,
                    child: SingleMotionBuilder(
                      motion:
                          const MaterialSpringMotion.expressiveSpatialFast(),
                      active: _animate,
                      value: _pressed && _animate ? .96 : 1.0,
                      builder: (_, scale, child) => Transform.scale(
                        key: const ValueKey('check-in-press'),
                        scale: scale,
                        transformHitTests: false,
                        child: child,
                      ),
                      child: Material(
                        shape: shape,
                        color: background,
                        clipBehavior: Clip.antiAlias,
                        textStyle: AppTypography.inter(
                          fontSize: 17,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: foreground,
                        ),
                        child: InkWell(
                          customBorder: shape,
                          canRequestFocus: _enabled,
                          onTapDown: _enabled ? (_) => _setPressed(true) : null,
                          onTapUp: _enabled ? (_) => _setPressed(false) : null,
                          onTapCancel: _enabled
                              ? () => _setPressed(false)
                              : null,
                          onTap: _enabled ? _activate : null,
                          overlayColor: WidgetStatePropertyAll(
                            foreground.withValues(alpha: .12),
                          ),
                          child: LayoutBuilder(
                            builder: (context, box) => Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: foreground.withValues(alpha: .14),
                                    ),
                                    child: SizedBox.square(
                                      dimension: 44,
                                      child: Center(
                                        child: SizedBox.square(
                                          dimension: AppLayout.iconSize,
                                          child: busy && _animate
                                              ? CircularProgressIndicator(
                                                  color: foreground,
                                                  strokeWidth: 2,
                                                )
                                              : Icon(glyph, color: foreground),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: box.maxHeight * .42,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: SizedBox(
                                        width: box.maxWidth * .74,
                                        child: Text(
                                          busy
                                              ? 'Please wait...'
                                              : widget.uploadLabel,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ring(Color color) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
    ),
  );

  void _activate() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }
}
