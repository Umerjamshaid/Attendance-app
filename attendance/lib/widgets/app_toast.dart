// Toast motion and capsule reveal adapted from Block Buzz (Apache-2.0).
// Copyright 2026 Block, Inc. See docs/third-party-animations.md.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ToastKind { generic, success, error }

final _coordinators = Expando<_ToastCoordinator>();

class _ToastCoordinator {
  int generation = 0;
  VoidCallback? remove;

  void invalidate() {
    generation++;
    remove?.call();
  }
}

/// Presents existing action feedback above routes and modal sheets.
/// Capture before awaiting an action; expired account/office scopes are ignored.
class AppToast {
  AppToast._(this._overlay, this._coordinator)
    : _generation = _coordinator.generation;

  final OverlayState _overlay;
  final _ToastCoordinator _coordinator;
  final int _generation;

  static AppToast of(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);
    return AppToast._(overlay, _coordinators[overlay] ??= _ToastCoordinator());
  }

  bool get _isCurrent =>
      _overlay.mounted && _generation == _coordinator.generation;

  void hideCurrentSnackBar() {
    if (_isCurrent) _coordinator.remove?.call();
  }

  /// Reuses the existing message, action and timeout, not SnackBar styling.
  void showSnackBar(SnackBar notice, {ToastKind kind = ToastKind.generic}) {
    if (!_isCurrent) return;
    _coordinator.remove?.call();
    var removed = false;
    late final OverlayEntry entry;
    void remove() {
      if (removed) return;
      removed = true;
      entry.remove();
      entry.dispose();
      if (_coordinator.remove == remove) _coordinator.remove = null;
    }

    entry = OverlayEntry(
      builder: (_) => _ToastBubble(notice: notice, onDismiss: remove),
    );
    _coordinator.remove = remove;
    _overlay.insert(entry);
    unawaited(_feedback(kind));
  }

  static Future<void> _feedback(ToastKind kind) async {
    try {
      await switch (kind) {
        ToastKind.generic => HapticFeedback.lightImpact(),
        ToastKind.success => HapticFeedback.mediumImpact(),
        ToastKind.error => HapticFeedback.heavyImpact(),
      };
    } on PlatformException {
      // Feedback must remain usable when a platform has no haptic support.
    } on MissingPluginException {
      // Widget previews and unsupported platforms have no native haptic plugin.
    }
  }
}

/// Keeps feedback above the navigator without replacing it on office changes.
class AppToastHost extends StatefulWidget {
  const AppToastHost({super.key, required this.scopeKey, required this.child});

  final String scopeKey;
  final Widget child;

  @override
  State<AppToastHost> createState() => _AppToastHostState();
}

class _AppToastHostState extends State<AppToastHost> {
  OverlayState? _overlay;

  @override
  void didUpdateWidget(AppToastHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scopeKey != widget.scopeKey) {
      final overlay = _overlay;
      if (overlay != null) _coordinators[overlay]?.invalidate();
    }
  }

  @override
  Widget build(BuildContext context) => Overlay.wrap(
    child: Builder(
      builder: (context) {
        _overlay = Overlay.of(context, rootOverlay: true);
        return widget.child;
      },
    ),
  );
}

class _ToastBubble extends StatefulWidget {
  const _ToastBubble({required this.notice, required this.onDismiss});

  final SnackBar notice;
  final VoidCallback onDismiss;

  @override
  State<_ToastBubble> createState() => _ToastBubbleState();
}

class _ToastBubbleState extends State<_ToastBubble>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 240),
  );
  Timer? _timer;
  bool? _reduceMotion;
  bool? _accessible;
  bool _closing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final accessible = MediaQuery.accessibleNavigationOf(context);
    if (_reduceMotion == reduceMotion && _accessible == accessible) return;
    _reduceMotion = reduceMotion;
    _accessible = accessible;
    _timer?.cancel();
    if (_closing) {
      if (reduceMotion) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onDismiss();
        });
      }
      return;
    }
    if (reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
    final action = widget.notice.action;
    if (accessible && action != null) return;
    final duration = widget.notice.duration;
    final timeout = (accessible || action != null) && duration.inSeconds < 6
        ? const Duration(seconds: 6)
        : duration;
    _timer = Timer(
      timeout + (reduceMotion ? Duration.zero : _controller.duration!),
      _dismiss,
    );
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (!_reduceMotion!) {
      try {
        await _controller.reverse().orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final background = theme.brightness == Brightness.dark
        ? colors.surfaceContainer
        : colors.inverseSurface;
    final foreground = theme.brightness == Brightness.dark
        ? colors.onSurface
        : colors.onInverseSurface;
    final style = theme.textTheme.bodyMedium!.copyWith(
      color: foreground,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    final content = widget.notice.content;
    final message = content is Text && content.data != null
        ? Text(content.data!, style: style, textAlign: TextAlign.center)
        : DefaultTextStyle(style: style, child: content);
    final action = widget.notice.action;
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 14 * 1.3;
    final actionButton = action == null
        ? null
        : TextButton(
            style: TextButton.styleFrom(
              foregroundColor: background,
              backgroundColor: foreground,
              minimumSize: const Size(48, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: const StadiumBorder(),
              textStyle: style,
            ),
            onPressed: () {
              if (_closing) return;
              _closing = true;
              widget.onDismiss();
              action.onPressed();
            },
            child: Text(action.label),
          );
    final body = Padding(
      padding: EdgeInsets.fromLTRB(20, 12, action == null ? 20 : 8, 12),
      child: actionButton == null
          ? message
          : stacked
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [message, const SizedBox(height: 12), actionButton],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: message),
                const SizedBox(width: 12),
                actionButton,
              ],
            ),
    );
    return Positioned(
      top: MediaQuery.viewPaddingOf(context).top + 8,
      left: 20,
      right: 20,
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedBuilder(
          animation: _controller,
          child: Semantics(
            liveRegion: true,
            onDismiss: _dismiss,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight:
                    (MediaQuery.sizeOf(context).height -
                            MediaQuery.viewPaddingOf(context).vertical -
                            32)
                        .clamp(48, double.infinity),
              ),
              child: SingleChildScrollView(child: body),
            ),
          ),
          builder: (context, child) {
            final value = _controller.value;
            final exiting = _controller.status == AnimationStatus.reverse;
            final progress = exiting
                ? Curves.easeOutQuad.transform(value)
                : const Cubic(0.2, 1.1, 0.4, 1).transform(value);
            final reveal = exiting
                ? Curves.easeInCubic.transform(value)
                : Curves.easeOutCubic.transform(value);
            return IgnorePointer(
              ignoring: _closing,
              child: FractionalTranslation(
                translation: Offset(0, -(1 - progress)),
                child: PhysicalShape(
                  clipper: _ToastRevealClipper(reveal, stacked: stacked),
                  clipBehavior: Clip.antiAlias,
                  color: background,
                  elevation: 4,
                  shadowColor: Colors.black.withValues(alpha: 0.18),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Opacity(
                      opacity: exiting ? value * value : 1,
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ToastRevealClipper extends CustomClipper<Path> {
  const _ToastRevealClipper(this.progress, {required this.stacked});

  final double progress;
  final bool stacked;

  @override
  Path getClip(Size size) {
    final collapsed = size.height.clamp(0.0, size.width);
    final width = collapsed + (size.width - collapsed) * progress;
    return RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(stacked ? 28 : size.height / 2),
    ).getOuterPath(
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: width,
        height: size.height,
      ),
    );
  }

  @override
  bool shouldReclip(_ToastRevealClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.stacked != stacked;
}
