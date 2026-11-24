import 'package:attendance/config/ui_tokens.dart';
import 'package:attendance/config/app_icons.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/office_check_in_activity.dart';
import 'package:attendance/providers/admin_activity_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/widgets/app_toast.dart';
import 'package:attendance/widgets/demo_mode_notice.dart';
import 'package:attendance/widgets/notification_tile.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/network_status.dart';

class AdminNotificationScreen extends StatelessWidget {
  const AdminNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider?>();
    final offline = context.select(
      (NetworkStatus? status) => status?.offline ?? false,
    );
    if (offline && auth?.isPreview != true) {
      return const _InboxLayout(
        body: _FeedStatus(
          title: 'Check-in activity is offline',
          detail: 'Available when you’re back online.',
        ),
      );
    }
    final backend = auth?.currentUser?.isAdmin == true ? auth?.backend : null;
    if (backend == null) {
      return _InboxLayout(
        body: _FeedStatus(
          title: 'Check-in activity unavailable',
          detail: auth?.currentUser?.isAdmin == true
              ? 'Company activity is not available in this build.'
              : 'Check-in activity is only available to office admins.',
        ),
      );
    }
    if (context.read<AdminActivityProvider?>() != null) {
      return const _OfficeFeed();
    }
    return ChangeNotifierProvider(
      key: ValueKey(auth!.officeScopeKey),
      create: (_) => AdminActivityProvider(
        backend,
        viewer: auth.currentUser?.authUserId,
        office: auth.currentUser?.organizationId,
      ),
      child: const _OfficeFeed(),
    );
  }
}

class _InboxLayout extends StatelessWidget {
  const _InboxLayout({required this.body, this.markAllRead});
  final Widget body;
  final VoidCallback? markAllRead;

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
          'Check-in activity',
          style: ProfileUi.body(context, weight: FontWeight.w600),
        ),
        actions: [
          if (markAllRead != null)
            IconButton(
              tooltip: 'Mark all as read',
              icon: const Icon(AppIcons.check),
              onPressed: markAllRead,
            ),
        ],
      ),
      body: body,
    );
  }
}

class _OfficeFeed extends StatefulWidget {
  const _OfficeFeed();

  @override
  State<_OfficeFeed> createState() => _OfficeFeedState();
}

class _OfficeFeedState extends State<_OfficeFeed> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<AdminActivityProvider>();
    final rows = _unreadOnly
        ? feed.rows.where(feed.isUnread).toList()
        : feed.rows;
    final error = feed.error;
    final Widget? status;
    if (feed.loading && feed.rows.isEmpty) {
      status = const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Loading check-ins'),
      );
    } else if (error != null) {
      status = _FeedStatus(
        title: 'Could not load check-ins',
        detail: error is CompanyException
            ? error.message
            : 'Check your connection and try again.',
        retry: feed.refresh,
      );
    } else if (feed.rows.isEmpty) {
      status = const _FeedStatus(
        title: 'No check-ins yet',
        detail: 'Successful check-ins for this office will appear here.',
      );
    } else if (rows.isEmpty) {
      status = const _FeedStatus(
        title: 'You’re caught up',
        detail: 'No unread check-ins.',
      );
    } else {
      status = null;
    }

    final now = feed.backend.companyNow;
    final today = <OfficeCheckInActivity>[];
    final earlier = <OfficeCheckInActivity>[];
    for (final row in rows) {
      (DateUtils.isSameDay(row.receivedAt, now) ? today : earlier).add(row);
    }
    return _InboxLayout(
      markAllRead: !feed.hasUnread || feed.saving
          ? null
          : () async {
              final saved = await feed.markAllRead();
              if (!saved && context.mounted) {
                AppToast.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not save read status.')),
                );
              }
            },
      body: RefreshIndicator(
        onRefresh: feed.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (feed.backend.isPreview)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(ProfileUi.gutter),
                  child: DemoModeNotice(),
                ),
              ),
            if (feed.rows.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ProfileUi.gutter,
                    vertical: 4,
                  ),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: !_unreadOnly,
                        onSelected: (_) => setState(() => _unreadOnly = false),
                      ),
                      ChoiceChip(
                        label: const Text('Unread'),
                        selected: _unreadOnly,
                        onSelected: (_) => setState(() => _unreadOnly = true),
                      ),
                    ],
                  ),
                ),
              ),
            if (status != null)
              SliverFillRemaining(hasScrollBody: false, child: status)
            else ...[
              for (final (title, group) in [
                ('Today', today),
                ('Earlier', earlier),
              ])
                if (group.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        ProfileUi.gutter,
                        16,
                        ProfileUi.gutter,
                        4,
                      ),
                      child: Semantics(
                        header: true,
                        child: Text(title, style: ProfileUi.small(context)),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 8),
                    sliver: SliverList.separated(
                      itemCount: group.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: ProfileUi.gutter,
                        endIndent: ProfileUi.gutter,
                        color: context.colors.outlineVariant,
                      ),
                      itemBuilder: (context, index) {
                        final row = group[index];
                        return NotificationTile(
                          key: ValueKey(row.id),
                          titleSpans: [
                            TextSpan(
                              text: row.employeeName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: ' checked in'),
                          ],
                          description: DateFormat.yMMMd().format(
                            row.receivedAt,
                          ),
                          time: DateFormat.jm().format(row.receivedAt),
                          isUnread: feed.isUnread(row),
                        );
                      },
                    ),
                  ),
                ],
              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedStatus extends StatelessWidget {
  const _FeedStatus({required this.title, required this.detail, this.retry});

  final String title;
  final String detail;
  final VoidCallback? retry;

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
                title,
                textAlign: TextAlign.center,
                style: AppTypography.inter(
                  fontSize: 18,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: context.colors.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: ProfileUi.small(context).copyWith(height: 1.45),
            ),
            if (retry != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: retry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
