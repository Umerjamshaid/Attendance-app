import 'package:attendance/config/app_theme.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Floating capsule navigation dock.
///
/// The visual language is borrowed from Block Buzz's floating tab bar: a 56dp
/// capsule that floats above the bottom edge (`max(safe area, 12)`), flat
/// fill with no shadow, and a transparent-to-page fade painted behind it so
/// content scrolls out underneath. Unlike Buzz's action dock, this one is a
/// destination bar: it shows 3 destinations (4 for admins), each with a label,
/// and a capsule that slides to the selected one.
///
/// The widget reports exactly [dockHeight] plus the bottom gap to the
/// [Scaffold], so the host must set `extendBody: true`. The page then runs
/// underneath and receives the dock height as bottom `MediaQuery` padding.
class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isAdmin;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isAdmin = false,
  });

  /// Height of the capsule.
  static const double dockHeight = 56;

  static const double _minBottomGap = 12;
  static const double _sideMargin = 16;
  static const double _slotWidth = 88;

  /// How far the page fade reaches above the dock's top edge.
  static const double _fadeExtent = 48;

  @override
  Widget build(BuildContext context) {
    // The destinations depend on the role; their order must match AppShell.
    const home = _NavItemData(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    );
    const history = _NavItemData(
      icon: Icons.access_time_rounded,
      selectedIcon: Icons.access_time_filled_rounded,
      label: 'History',
    );
    const admin = _NavItemData(
      icon: Icons.shield_outlined,
      selectedIcon: Icons.shield_rounded,
      label: 'Admin',
    );
    const profile = _NavItemData(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
    );
    final items = <_NavItemData>[home, history, if (isAdmin) admin, profile];

    // Guards against a stale index (e.g. the role changed while signed in).
    final selectedIndex = currentIndex < items.length ? currentIndex : 0;

    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final bottomGap = safeBottom > _minBottomGap ? safeBottom : _minBottomGap;

    // Intrinsic width per destination, capped to the screen so 4 tabs still
    // fit on narrow phones; 3 tabs stay a compact, centered capsule.
    final available = MediaQuery.sizeOf(context).width - _sideMargin * 2;
    final wanted = _slotWidth * items.length;
    final dockWidth = wanted < available ? wanted : available;

    return RepaintBoundary(
      child: SizedBox(
        height: dockHeight + bottomGap,
        child: Stack(
          // The fade deliberately paints above the bar's own bounds.
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: dockHeight + bottomGap + _fadeExtent,
              child: const IgnorePointer(child: _FooterFade()),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomGap,
              height: dockHeight,
              child: Center(
                child: SizedBox(
                  width: dockWidth,
                  height: dockHeight,
                  child: _Dock(
                    items: items,
                    selectedIndex: selectedIndex,
                    onSelected: (index) {
                      if (index != currentIndex) {
                        HapticFeedback.selectionClick();
                      }
                      onTap(index);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItemData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Transparent-to-page gradient so scrolling content fades out behind the
/// dock (same stops and opacities as Block Buzz's footer backdrop).
class _FooterFade extends StatelessWidget {
  const _FooterFade();

  static const List<double> _stops = [0, 0.18, 0.38, 0.6, 0.8, 1];
  static const List<double> _opacities = [0, 0.03, 0.12, 0.34, 0.7, 1];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: _stops,
          colors: [
            for (final opacity in _opacities)
              ProfileUi.page.withValues(alpha: opacity),
          ],
        ),
      ),
    );
  }
}

class _Dock extends StatelessWidget {
  final List<_NavItemData> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _Dock({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final count = items.length;
    // Maps the selected slot to an Alignment x in [-1, 1].
    final x = count <= 1 ? 0.0 : -1.0 + 2.0 * selectedIndex / (count - 1);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Main navigation',
      child: Material(
        color: ProfileUi.cardFill,
        shape: StadiumBorder(side: BorderSide(color: ProfileUi.hairline)),
        // Keeps ripples inside the capsule.
        clipBehavior: Clip.antiAlias,
        // The labels share the dock's fixed height, so cap their scaling.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Stack(
            children: [
              // Selection capsule that slides to the active destination.
              AnimatedAlign(
                alignment: Alignment(x, 0),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  heightFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: AppTheme.primaryNavy.withValues(alpha: 0.1),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < count; i++)
                      Expanded(
                        child: _DockItem(
                          data: items[i],
                          index: i,
                          count: count,
                          selected: i == selectedIndex,
                          onTap: () => onSelected(i),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final _NavItemData data;
  final int index;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _DockItem({
    required this.data,
    required this.index,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final color = selected ? AppTheme.primaryNavy : AppTheme.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: data.label,
      hint: 'Tab ${index + 1} of $count',
      // `excludeSemantics` drops the InkWell's own tap action, so the action
      // has to live on this node for screen readers to be able to activate it.
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        overlayColor: WidgetStatePropertyAll(
          AppTheme.primaryNavy.withValues(alpha: 0.08),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              child: Icon(
                selected ? data.selectedIcon : data.icon,
                key: ValueKey(selected),
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              style: ProfileUi.caption(
                color: color,
                weight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
