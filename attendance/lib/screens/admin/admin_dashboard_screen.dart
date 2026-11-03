import 'package:attendance/config/app_theme.dart';
import 'package:attendance/providers/admin_provider.dart';
import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/screens/admin/admin_notification_screen.dart';
import 'package:attendance/widgets/admin/admin_filter_bar.dart';
import 'package:attendance/widgets/admin/admin_overview_card.dart';
import 'package:attendance/widgets/admin/employee_card.dart';
import 'package:attendance/widgets/user-profile/profile_menu_item.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'set_attendance_window_sheet.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => AdminDashboardScreenState();
}

class AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const double _contentMaxWidth = 560;

  // Scroll-driven app bar divider. Only the divider rebuilds.
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<bool> _scrolled = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadDashboard();
      context.read<AttendanceProvider>().loadWindowConfig();
    });
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _scrolled.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    _scrolled.value = _scroll.offset > 4;
  }

  void _openWindowSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: ProfileUi.page,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ProfileUi.sheetRadius),
        ),
      ),
      builder: (_) => const SetAttendanceWindowSheet(),
    );
  }

  void _openNotifications() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminNotificationScreen()),
    );
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    await Future.wait([
      context.read<AdminProvider>().loadDashboard(),
      context.read<AttendanceProvider>().loadWindowConfig(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();
    final isLoading = adminProvider.isLoading;
    final filteredList = adminProvider.filteredList;
    final total = adminProvider.totalEmployees;
    final error = adminProvider.error;
    final showFullError = error != null && !isLoading && total == 0;
    final showInlineError = error != null && !isLoading && total > 0;

    final width = MediaQuery.sizeOf(context).width;
    final sidePad = width > _contentMaxWidth
        ? (width - _contentMaxWidth) / 2
        : 0.0;

    return Scaffold(
      backgroundColor: ProfileUi.page,
      body: RefreshIndicator(
        color: AppTheme.primaryNavy,
        backgroundColor: Colors.white,
        // Start the spinner below the pinned app bar.
        edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            _buildSliverAppBar(),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: sidePad),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AdminOverviewCard(
                      total: total,
                      present: adminProvider.presentToday,
                      absent: adminProvider.absentToday,
                      isLoading: isLoading && total == 0,
                    ),
                    _buildWindowSection(),
                    AdminFilterBar(
                      selected: adminProvider.filter,
                      onSelected: adminProvider.setFilter,
                      total: total,
                      present: adminProvider.presentToday,
                      absent: adminProvider.absentToday,
                    ),
                    if (error != null && showInlineError)
                      _InlineError(
                        message: error,
                        onRetry: adminProvider.loadDashboard,
                      ),
                    _SectionLabel(
                      isLoading && total == 0
                          ? 'Employees'
                          : 'Employees · ${filteredList.length}',
                    ),
                  ],
                ),
              ),
            ),
            if (isLoading && total == 0)
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: sidePad + ProfileUi.gutter,
                ),
                sliver: const SliverToBoxAdapter(child: _LoadingRows()),
              )
            else if (error != null && showFullError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _StateView(
                  icon: Icons.error_outline_rounded,
                  title: 'Couldn’t load employees',
                  subtitle: error,
                  isError: true,
                  actionLabel: 'Retry',
                  onAction: adminProvider.loadDashboard,
                ),
              )
            else if (filteredList.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyStateFor(adminProvider.filter, total),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: sidePad + ProfileUi.gutter,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => EmployeeCard(
                      key: ValueKey(filteredList[index].employee.id),
                      data: filteredList[index],
                      isFirst: index == 0,
                      isLast: index == filteredList.length - 1,
                    ),
                    childCount: filteredList.length,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                  ),
                ),
              ),
            // Clears the floating navigation dock.
            SliverToBoxAdapter(
              child: SizedBox(
                height: 32 + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: ProfileUi.page,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: true,
      title: Text('Admin', style: ProfileUi.body(weight: FontWeight.w600)),
      actions: [
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none_rounded),
          color: AppTheme.textPrimary,
          onPressed: _openNotifications,
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: ValueListenableBuilder<bool>(
          valueListenable: _scrolled,
          builder: (_, scrolled, _) => AnimatedOpacity(
            opacity: scrolled ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Divider(height: 1, thickness: 1, color: ProfileUi.hairline),
          ),
        ),
      ),
    );
  }

  /// Only this row listens to the attendance provider, so check-ins elsewhere
  /// do not rebuild the whole dashboard.
  Widget _buildWindowSection() {
    return Consumer<AttendanceProvider>(
      builder: (context, attendance, _) {
        final always = attendance.windowMode == 'always';
        final title = always
            ? 'Always open'
            : '${attendance.formatHour(attendance.windowStartHour)} – '
                  '${attendance.formatHour(attendance.windowEndHour)}';

        return ProfileSectionCard(
          label: 'Attendance window',
          children: [
            ProfileMenuItem(
              icon: Icons.schedule_rounded,
              title: title,
              subtitle: always
                  ? 'No time restriction'
                  : 'Employees can mark attendance in these hours',
              onTap: _openWindowSheet,
              trailing: Text(
                'Edit',
                style: ProfileUi.small(
                  color: AppTheme.primaryNavy,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyStateFor(String filter, int total) {
    if (total == 0) {
      return const _StateView(
        icon: Icons.person_off_outlined,
        title: 'No employees yet',
        subtitle: 'Employees will appear here once they are added.',
      );
    }
    if (filter == 'absent') {
      return const _StateView(
        icon: Icons.verified_outlined,
        title: 'No absences',
        subtitle: 'Everyone has checked in today.',
      );
    }
    return const _StateView(
      icon: Icons.person_off_outlined,
      title: 'Nobody is present yet',
      subtitle: 'Check-ins will show up here as employees mark attendance.',
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileUi.gutter + 4,
        12,
        ProfileUi.gutter,
        8,
      ),
      child: Semantics(
        header: true,
        child: Text(text, style: ProfileUi.small(weight: FontWeight.w600)),
      ),
    );
  }
}

/// Shown when a refresh fails but earlier data is still on screen.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileUi.gutter + 4,
        4,
        ProfileUi.gutter,
        0,
      ),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: AppTheme.errorRed,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: ProfileUi.caption(color: AppTheme.errorRed),
              ),
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                onRetry();
              },
              child: Text(
                'Retry',
                style: ProfileUi.small(
                  color: AppTheme.primaryNavy,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Static placeholder rows while the first load is in flight.
class _LoadingRows extends StatelessWidget {
  const _LoadingRows();

  static const int _rowCount = 6;

  @override
  Widget build(BuildContext context) {
    final bar = AppTheme.textPrimary;

    Widget block(double width, double height, double alpha) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bar.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(4),
      ),
    );

    return Semantics(
      label: 'Loading employees',
      excludeSemantics: true,
      child: Material(
        color: ProfileUi.cardFill,
        borderRadius: BorderRadius.circular(ProfileUi.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < _rowCount; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: ProfileUi.rowInset + 40 + ProfileUi.rowInset,
                  endIndent: ProfileUi.rowInset,
                  color: ProfileUi.hairline,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ProfileUi.rowInset,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: bar.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: ProfileUi.rowInset),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          block(140, 12, 0.1),
                          const SizedBox(height: 8),
                          block(100, 10, 0.06),
                        ],
                      ),
                    ),
                    block(52, 20, 0.06),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isError = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isError;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final action = onAction;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ProfileUi.gutter + 4,
        ProfileUi.gutter + 4,
        ProfileUi.gutter + 4,
        ProfileUi.gutter + 4 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: ProfileUi.cardFill,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: isError ? AppTheme.errorRed : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              title,
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
          Semantics(
            liveRegion: isError,
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: ProfileUi.small().copyWith(height: 1.45),
            ),
          ),
          if (action != null && actionLabel != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                action();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(actionLabel!),
              style: FilledButton.styleFrom(
                backgroundColor: ProfileUi.cardFill,
                foregroundColor: AppTheme.textPrimary,
                elevation: 0,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: const StadiumBorder(),
                textStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
