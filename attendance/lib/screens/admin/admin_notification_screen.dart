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
      backgroundColor: ProfileUi.page,
      appBar: AppBar(
        backgroundColor: ProfileUi.page,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppTheme.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notifications',
          style: ProfileUi.body(weight: FontWeight.w600),
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
                color: ProfileUi.hairline,
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
              decoration: const BoxDecoration(
                color: ProfileUi.cardFill,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 32,
                color: AppTheme.textSecondary,
              ),
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
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New notifications will appear here.',
              textAlign: TextAlign.center,
              style: ProfileUi.small().copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
