import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_icons.dart';
import '../config/app_theme.dart';

/// A single, left-aligned floating capsule, with no separate action button.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isAdmin = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isAdmin;

  static const double dockHeight = 64;

  static Color controlSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? context.colors.surfaceContainerHighest
      : const Color(0xFFF0F0F0);

  @override
  Widget build(BuildContext context) {
    final items = [
      (icon: AppIcons.home, label: 'Home'),
      (icon: AppIcons.clock, label: 'History'),
      if (isAdmin) (icon: AppIcons.shield, label: 'Admin'),
      (icon: AppIcons.user, label: 'Profile'),
    ];
    final selected = currentIndex >= 0 && currentIndex < items.length
        ? currentIndex
        : 0;
    final bottom = math.max(12.0, MediaQuery.viewPaddingOf(context).bottom);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final colors = context.colors;
    final glass = Theme.of(context).platform == TargetPlatform.iOS;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: dockHeight,
        child: SafeArea(
          top: false,
          bottom: false,
          minimum: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = math.min(
                  items.length * 64.0 + 8,
                  constraints.maxWidth,
                );
                return Semantics(
                  container: true,
                  explicitChildNodes: true,
                  label: 'Main navigation',
                  child: Container(
                    key: const ValueKey('floating-navigation'),
                    width: width,
                    height: dockHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: .10),
                          blurRadius: 24,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: BackdropFilter(
                        enabled: glass,
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Material(
                          color: glass
                              ? colors.surface.withValues(alpha: .86)
                              : colors.surface,
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: colors.outlineVariant.withValues(
                                alpha: .35,
                              ),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Stack(
                              children: [
                                AnimatedAlign(
                                  alignment: AlignmentDirectional(
                                    -1 + 2 * selected / (items.length - 1),
                                    0,
                                  ),
                                  duration: duration,
                                  curve: Curves.easeOutCubic,
                                  child: FractionallySizedBox(
                                    widthFactor: 1 / items.length,
                                    heightFactor: 1,
                                    child: DecoratedBox(
                                      key: const ValueKey(
                                        'navigation-selection',
                                      ),
                                      decoration: ShapeDecoration(
                                        color: controlSurface(context),
                                        shape: const StadiumBorder(),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Row(
                                    children: [
                                      for (var i = 0; i < items.length; i++)
                                        Expanded(
                                          child: _DockItem(
                                            label: items[i].label,
                                            icon: items[i].icon,
                                            selected: selected == i,
                                            onTap: () {
                                              if (selected != i) {
                                                HapticFeedback.selectionClick();
                                              }
                                              onTap(i);
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatefulWidget {
  const _DockItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DockItem> createState() => _DockItemState();
}

class _DockItemState extends State<_DockItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: widget.selected,
    inMutuallyExclusiveGroup: true,
    label: widget.label,
    onTap: widget.onTap,
    excludeSemantics: true,
    child: Tooltip(
      message: widget.label,
      excludeFromSemantics: true,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
        customBorder: const StadiumBorder(),
        child: Center(
          child: AnimatedScale(
            scale: _pressed ? .92 : 1,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 150),
            child: Icon(
              widget.icon,
              size: 24,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    ),
  );
}

class NavigationFooterBackdrop extends StatelessWidget {
  const NavigationFooterBackdrop({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, .18, .38, .6, .8, 1],
              colors: [
                for (final alpha in const [0.0, .03, .12, .34, .7, 1.0])
                  context.colors.surface.withValues(alpha: alpha),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
