import 'package:attendance/config/ui_tokens.dart';
import 'package:attendance/config/app_icons.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/office_check_in_activity.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/widgets/demo_mode_notice.dart';
import 'package:attendance/widgets/notification_tile.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdminNotificationScreen extends StatelessWidget {
  const AdminNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider?>();
    final backend = auth?.currentUser?.isAdmin == true ? auth?.backend : null;
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
      ),
      body: backend == null
          ? _FeedStatus(
              title: 'Check-in activity unavailable',
              detail: auth?.currentUser?.isAdmin == true
                  ? 'Company activity is not available in this build.'
                  : 'Check-in activity is only available to office admins.',
            )
          : _OfficeFeed(key: ValueKey(auth!.officeScopeKey), backend: backend),
    );
  }
}

class _OfficeFeed extends StatefulWidget {
  const _OfficeFeed({super.key, required this.backend});

  final CompanyBackend backend;

  @override
  State<_OfficeFeed> createState() => _OfficeFeedState();
}

class _OfficeFeedState extends State<_OfficeFeed> {
  late Future<List<OfficeCheckInActivity>> _request = widget.backend
      .checkInActivity();

  Future<void> _refresh() async {
    final request = widget.backend.checkInActivity();
    setState(() {
      _request = request;
    });
    try {
      await request;
    } catch (_) {
      // FutureBuilder displays the failure, including revoked access.
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _request,
    builder: (context, snapshot) {
      final rows = snapshot.data ?? const <OfficeCheckInActivity>[];
      final Widget? status;
      if (snapshot.connectionState != ConnectionState.done) {
        status = const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading check-ins'),
        );
      } else if (snapshot.hasError) {
        final error = snapshot.error;
        status = _FeedStatus(
          title: 'Could not load check-ins',
          detail: error is CompanyException
              ? error.message
              : 'Check your connection and try again.',
          retry: _refresh,
        );
      } else if (rows.isEmpty) {
        status = const _FeedStatus(
          title: 'No check-ins yet',
          detail: 'Successful check-ins for this office will appear here.',
        );
      } else {
        status = null;
      }

      return RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.backend.isPreview)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(ProfileUi.gutter),
                  child: DemoModeNotice(),
                ),
              ),
            if (status != null)
              SliverFillRemaining(hasScrollBody: false, child: status)
            else
              SliverPadding(
                padding: EdgeInsets.only(
                  top: 8,
                  bottom: 24 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: ProfileUi.gutter,
                    endIndent: ProfileUi.gutter,
                    color: context.colors.outlineVariant,
                  ),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return NotificationTile(
                      key: ValueKey(row.id),
                      titleSpans: [
                        TextSpan(
                          text: row.employeeName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(text: ' checked in'),
                      ],
                      description: DateFormat.yMMMd().format(row.receivedAt),
                      time: DateFormat.jm().format(row.receivedAt),
                      isUnread: false,
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
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
