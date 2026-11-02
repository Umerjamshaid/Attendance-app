import 'package:attendance/config/app_theme.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';

/// One notification row: unread dot, icon, rich title, description and time.
///
/// Follows the unread-dot-plus-time row used by Block Buzz's activity feed
/// instead of tinting the whole row grey.
class NotificationTile extends StatelessWidget {
  final List<TextSpan> titleSpans;
  final String description;
  final String time;
  final bool isUnread;

  const NotificationTile({
    super.key,
    required this.titleSpans,
    required this.description,
    required this.time,
    required this.isUnread,
  });

  @override
  Widget build(BuildContext context) {
    final plainTitle = TextSpan(children: titleSpans).toPlainText();

    return Semantics(
      container: true,
      label: '${isUnread ? 'Unread. ' : ''}$plainTitle. $description. $time',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ProfileUi.gutter,
          vertical: 14,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reserves the dot's width so read and unread rows line up.
            SizedBox(
              width: 8,
              height: 40,
              child: isUnread
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryNavy,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 20,
                color: AppTheme.primaryNavy,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: titleSpans),
                    style: ProfileUi.body(
                      weight: isUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(description, style: ProfileUi.small()),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(time, style: ProfileUi.caption()),
          ],
        ),
      ),
    );
  }
}
