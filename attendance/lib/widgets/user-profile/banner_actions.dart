// Adapted from Portal Labs Inline Delete Interaction (MIT), copyright 2026 Luis Portal.
// See assets/licenses/PortalLabs-MIT.txt.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_icons.dart';
import '../../config/ui_tokens.dart';
import '../portal_spring_curve.dart';
import 'profile_section_card.dart';

enum BannerAction { change, color, remove }

/// Banner-only menu: confirmation replaces its destructive row, not the route.
class BannerActions extends StatefulWidget {
  const BannerActions({
    super.key,
    required this.appearance,
    this.hasBanner = true,
  });

  final Animation<double> appearance;
  final bool hasBanner;

  static Future<BannerAction?> open(
    BuildContext context, {
    bool hasBanner = true,
  }) {
    final theme = ProfileUi.themeOf(context);
    return showGeneralDialog<BannerAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: .28),
      transitionDuration: AppMotion.duration(context, AppMotion.entrance),
      pageBuilder: (context, animation, _) => Theme(
        data: theme,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: BannerActions(
                  appearance: animation,
                  hasBanner: hasBanner,
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, _, child) => BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 2 * animation.value,
          sigmaY: 2 * animation.value,
        ),
        child: FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: animation.drive(
              Tween(
                begin: .9,
                end: 1.0,
              ).chain(CurveTween(curve: const Cubic(.23, 1, .32, 1))),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  State<BannerActions> createState() => _BannerActionsState();
}

class _BannerActionsState extends State<BannerActions>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final _confirm = _controller.drive(
    CurveTween(
      curve: const PortalSpringCurve(mass: 1, stiffness: 220, damping: 26),
    ),
  );
  bool _confirming = false;
  bool _finished = false;

  void _toggle(bool confirming) {
    setState(() => _confirming = confirming);
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = confirming ? 1 : 0;
    } else if (confirming) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _finish(BannerAction? action) {
    if (_finished) return;
    _finished = true;
    Navigator.of(context).pop(action);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _stagger(int index, Widget child) {
    final animation = widget.appearance.drive(
      CurveTween(
        curve: Interval(
          .1 + (index + 1) * .05,
          .6 + (index + 1) * .05,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 15 * (1 - animation.value)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rowHeight = math.max(
      52.0,
      MediaQuery.textScalerOf(context).scale(16) * 1.25 + 24,
    );
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ProfileUi.cardRadius),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stagger(
            -1,
            SizedBox(
              height: rowHeight,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 20, end: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Banner',
                        style: ProfileUi.body(context, weight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close banner options',
                      onPressed: () => _finish(null),
                      icon: const Icon(AppIcons.x, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          _stagger(
            0,
            SizedBox(
              height: rowHeight,
              child: _ActionButton(
                label: widget.hasBanner ? 'Change banner' : 'Upload banner',
                icon: AppIcons.photoPlus,
                onTap: () => _finish(BannerAction.change),
              ),
            ),
          ),
          _stagger(
            1,
            SizedBox(
              height: rowHeight,
              child: _ActionButton(
                label: 'Banner color',
                icon: AppIcons.palette,
                onTap: () => _finish(BannerAction.color),
              ),
            ),
          ),
          if (widget.hasBanner)
            _stagger(
              2,
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked =
                      MediaQuery.textScalerOf(context).scale(16) > 22;
                  final confirmHeight =
                      (stacked ? rowHeight * 2 + 8 : rowHeight) + 16;
                  final confirm = _ActionButton(
                    label: 'Remove',
                    color: colors.error,
                    foreground: colors.onError,
                    onTap: () => _finish(BannerAction.remove),
                  );
                  final cancel = _ActionButton(
                    label: 'Cancel',
                    color: colors.surfaceContainerHighest,
                    onTap: () => _toggle(false),
                  );
                  return AnimatedBuilder(
                    animation: _confirm,
                    builder: (context, _) {
                      final t = _confirm.value;
                      return ClipRect(
                        child: SizedBox(
                          height: lerpDouble(
                            rowHeight,
                            confirmHeight,
                            t.clamp(0, 1),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: -rowHeight * t,
                                left: 0,
                                right: 0,
                                height: rowHeight,
                                child: Offstage(
                                  offstage: t >= 1,
                                  child: ExcludeSemantics(
                                    excluding: _confirming,
                                    child: IgnorePointer(
                                      ignoring: _confirming,
                                      child: Opacity(
                                        opacity: (1 - t).clamp(0, 1),
                                        child: _ActionButton(
                                          label: 'Remove banner',
                                          icon: AppIcons.trash,
                                          foreground: colors.error,
                                          onTap: () => _toggle(true),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: confirmHeight * (1 - t),
                                left: 0,
                                right: 0,
                                height: confirmHeight,
                                child: Offstage(
                                  offstage: t <= 0,
                                  child: ExcludeSemantics(
                                    excluding: !_confirming,
                                    child: IgnorePointer(
                                      ignoring: !_confirming,
                                      child: Opacity(
                                        opacity: t.clamp(0, 1),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: stacked
                                              ? Column(
                                                  children: [
                                                    Expanded(child: confirm),
                                                    const SizedBox(height: 8),
                                                    Expanded(child: cancel),
                                                  ],
                                                )
                                              : Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    Expanded(
                                                      flex: 2,
                                                      child: confirm,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(child: cancel),
                                                  ],
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
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
    this.foreground,
  });
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;
  final Color? foreground;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedScale(
      scale: _pressed && !MediaQuery.disableAnimationsOf(context) ? .95 : 1,
      duration: AppMotion.duration(context, const Duration(milliseconds: 100)),
      child: Material(
        color: widget.color ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.icon == null ? 12 : 20,
            ),
            child: Row(
              mainAxisAlignment: widget.icon == null
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 20,
                    color: widget.foreground ?? colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 16),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    style: ProfileUi.body(
                      context,
                      color: widget.foreground ?? colors.onSurface,
                      weight: FontWeight.w500,
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
}
