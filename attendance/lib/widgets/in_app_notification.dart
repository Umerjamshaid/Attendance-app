import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_icons.dart';
import '../config/ui_tokens.dart';

enum InAppNotificationKind { information, success, warning }

class InAppNotification {
  const InAppNotification({
    required this.title,
    this.detail,
    this.kind = InAppNotificationKind.information,
    this.actionLabel,
    this.onTap,
    this.duration = const Duration(seconds: 5),
  });

  final String title;
  final String? detail;
  final InAppNotificationKind kind;
  final String? actionLabel;
  final VoidCallback? onTap;
  final Duration duration;

  static bool show(BuildContext context, InAppNotification notification) {
    final host = context.getInheritedWidgetOfExactType<_NotificationScope>();
    return host?.enqueue(notification) ?? false;
  }
}

/// A route-owned queue, below modal routes and separate from top-edge toasts.
class InAppNotificationHost extends StatefulWidget {
  const InAppNotificationHost({super.key, required this.child, this.scopeKey});

  final Widget child;
  final String? scopeKey;

  @override
  State<InAppNotificationHost> createState() => _InAppNotificationHostState();
}

class _InAppNotificationHostState extends State<InAppNotificationHost>
    with SingleTickerProviderStateMixin {
  final _queue = Queue<InAppNotification>();
  late final _animation = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
    reverseDuration: AppMotion.fast,
  );
  late final _slide = _animation.drive(
    Tween(
      begin: const Offset(0, .25),
      end: Offset.zero,
    ).chain(CurveTween(curve: AppMotion.enterCurve)),
  );
  InAppNotification? _current;
  Timer? _timer;
  bool _visible = false,
      _reduceMotion = false,
      _accessible = false,
      _closing = false;
  int _serial = 0;

  @override
  void didUpdateWidget(InAppNotificationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scopeKey == widget.scopeKey) return;
    _timer?.cancel();
    _animation.stop();
    _queue.clear();
    _current = null;
    _closing = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        (ModalRoute.isCurrentOf(context) ?? true) &&
        MediaQuery.viewInsetsOf(context).bottom == 0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final accessible = MediaQuery.accessibleNavigationOf(context);
    if ((_visible, _reduceMotion, _accessible) ==
        (visible, reduceMotion, accessible)) {
      return;
    }
    _visible = visible;
    _reduceMotion = reduceMotion;
    _accessible = accessible;
    if (reduceMotion && !_closing) _animation.value = 1;
    _startTimer();
  }

  bool _enqueue(InAppNotification notification) {
    if (!mounted) return false;
    if (_queue.length == 8) _queue.removeFirst();
    _queue.add(notification);
    if (_current == null) _advance();
    return true;
  }

  void _advance() {
    _timer?.cancel();
    setState(() {
      _closing = false;
      _serial++;
      _current = _queue.isEmpty ? null : _queue.removeFirst();
    });
    if (_current case final notification?) {
      if (_reduceMotion) {
        _animation.value = 1;
      } else {
        _animation.forward(from: 0);
      }
      if (_visible && !_reduceMotion) unawaited(_feedback(notification.kind));
      _startTimer();
    }
  }

  static Future<void> _feedback(InAppNotificationKind kind) async {
    try {
      await switch (kind) {
        InAppNotificationKind.information => HapticFeedback.lightImpact(),
        InAppNotificationKind.success => HapticFeedback.mediumImpact(),
        InAppNotificationKind.warning => HapticFeedback.selectionClick(),
      };
    } on PlatformException {
      // Haptics are optional.
    } on MissingPluginException {
      // Haptics are optional.
    }
  }

  void _startTimer() {
    _timer?.cancel();
    final notification = _current;
    if (notification == null || _closing || !_visible || _accessible) return;
    _timer = Timer(notification.duration, _dismiss);
  }

  Future<void> _dismiss({bool animate = true, VoidCallback? action}) async {
    if (_closing || _current == null) return;
    _closing = true;
    _timer?.cancel();
    if (animate && !_reduceMotion) {
      try {
        await _animation.reverse().orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    _advance();
    if (_visible) action?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notification = _current;
    return _NotificationScope(
      enqueue: _enqueue,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (notification != null && _visible)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 8,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 480,
                    maxHeight: MediaQuery.sizeOf(context).height * .45,
                  ),
                  child: SlideTransition(
                    position: _slide,
                    child: FadeTransition(
                      opacity: _animation,
                      child: Dismissible(
                        key: ValueKey(_serial),
                        direction: DismissDirection.horizontal,
                        movementDuration: _reduceMotion
                            ? Duration.zero
                            : AppMotion.fast,
                        resizeDuration: null,
                        onDismissed: (_) => unawaited(_dismiss(animate: false)),
                        child: _NotificationCard(
                          notification: notification,
                          onDismiss: () => unawaited(_dismiss()),
                          onAction: notification.onTap == null
                              ? null
                              : () => unawaited(
                                  _dismiss(
                                    animate: false,
                                    action: notification.onTap,
                                  ),
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
    );
  }
}

class _NotificationScope extends InheritedWidget {
  const _NotificationScope({required this.enqueue, required super.child});

  final bool Function(InAppNotification) enqueue;

  @override
  bool updateShouldNotify(_NotificationScope oldWidget) => false;
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onDismiss,
    this.onAction,
  });

  final InAppNotification notification;
  final VoidCallback onDismiss;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (icon, color) = switch (notification.kind) {
      InAppNotificationKind.information => (
        AppIcons.infoCircle,
        colors.primary,
      ),
      InAppNotificationKind.success => (AppIcons.check, colors.primary),
      InAppNotificationKind.warning => (AppIcons.alertCircle, colors.error),
    };
    return Semantics(
      liveRegion: true,
      child: Material(
        color: colors.surfaceContainerHigh,
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 12, 0),
                child: Icon(icon, color: color, size: 20),
              ),
              Expanded(
                child: InkWell(
                  onTap: onAction,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: theme.textTheme.titleSmall,
                        ),
                        if (notification.detail case final detail?)
                          Text(detail, style: theme.textTheme.bodySmall),
                        if (notification.actionLabel case final label?
                            when onAction != null)
                          TextButton(onPressed: onAction, child: Text(label)),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                tooltip: 'Dismiss notification',
                icon: const Icon(AppIcons.x, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
