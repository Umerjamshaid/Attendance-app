import 'package:attendance/config/app_icons.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A flush settings row: leading icon, wrapping title, optional badge and a
/// trailing chevron. Lives inside a [ProfileSectionCard], which supplies the
/// surface and separators.
///
/// A null [onTap] renders a non-interactive row (no ripple, no chevron).
class ProfileMenuItem extends StatelessWidget {
  const ProfileMenuItem({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.textColor,
    this.badge,
    this.badgeColor,
    this.trailing,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color? textColor;
  final String? badge;
  final Color? badgeColor;
  final Widget? trailing;

  /// Optional secondary line under the title.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ProfileUi.rowInset,
        vertical: 14,
      ),
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: ProfileUi.rowInset),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wrap lets a long title and badge take a second line on
                // narrow screens instead of overflowing.
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: ProfileUi.body(context, color: textColor),
                    ),
                    if (badge != null)
                      _Badge(
                        label: badge!,
                        color: badgeColor ?? context.attendancePresent,
                      ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: ProfileUi.small(context)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ] else if (tap != null) ...[
            const SizedBox(width: 8),
            Icon(AppIcons.chevronRight, size: 20),
          ],
        ],
      ),
    );

    if (tap == null) return row;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            tap();
          },
          child: row,
        ),
      ),
    );
  }
}

/// A row with a trailing switch. The whole row toggles, not just the switch.
class ProfileSwitchItem extends StatelessWidget {
  const ProfileSwitchItem({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  void _set(bool next) {
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: () => _set(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ProfileUi.rowInset,
            vertical: 8,
          ),
          child: Row(
            children: [
              Icon(icon, size: 24),
              const SizedBox(width: ProfileUi.rowInset),
              Expanded(child: Text(title, style: ProfileUi.body(context))),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: value,
                onChanged: _set,
                activeTrackColor: context.colors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                thumbIcon: switch (Theme.of(context).platform) {
                  TargetPlatform.iOS || TargetPlatform.macOS => null,
                  _ => const WidgetStateProperty<Icon?>.fromMap({
                    WidgetState.selected: Icon(AppIcons.check, size: 18),
                    WidgetState.any: Icon(AppIcons.x, size: 18),
                  }),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: ProfileUi.caption(
          context,
          color: color,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}
