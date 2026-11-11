import 'package:attendance/config/app_icons.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/widgets/notification_tile.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminNotificationScreen extends StatelessWidget {
  const AdminNotificationScreen({super.key});

  /// There is no notification data source yet, so this is empty and the screen
  /// shows its empty state. Populate it (newest first) once one exists; the
  /// list below renders them as-is.
  static const List<NotificationTile> _items = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(AppIcons.chevronLeft, size: 24),
          color: context.colors.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notifications',
          style: ProfileUi.body(context, weight: FontWeight.w600),
        ),
      ),
      body: _items.isEmpty
          ? const _EmptyNotifications()
          : ListView.separated(
              padding: EdgeInsets.only(
                top: 8,
                bottom: 24 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: _items.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                thickness: 1,
                indent: ProfileUi.gutter,
                endIndent: ProfileUi.gutter,
                color: context.colors.outlineVariant,
              ),
              itemBuilder: (_, index) => _items[index],
            ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ProfileUi.gutter + 4,
          ProfileUi.gutter + 4,
          ProfileUi.gutter + 4,
          ProfileUi.gutter + 4 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(AppIcons.bell, size: 24),
            ),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(
                'You’re all caught up',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: context.colors.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New notifications will appear here.',
              textAlign: TextAlign.center,
              style: ProfileUi.small(context).copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
