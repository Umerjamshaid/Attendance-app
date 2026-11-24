import 'dart:async';

import 'package:attendance/models/office_check_in_activity.dart';
import 'package:attendance/providers/admin_activity_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/screens/home/attendance_screen.dart';
import 'package:attendance/screens/history/history_screen.dart';
import 'package:attendance/screens/admin/admin_dashboard_screen.dart';
import 'package:attendance/screens/admin/admin_notification_screen.dart';
import 'package:attendance/screens/profile/profile_screen.dart';
import 'package:attendance/widgets/bottom_nav.dart';
import 'package:attendance/widgets/in_app_notification.dart';
import 'package:attendance/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/ui_tokens.dart';
import '../providers/attendance_provider.dart';
import '../providers/attendance_history_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/admin_provider.dart';
import '../services/network_status.dart';
import 'splash/offline_home_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  AppShellState createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  bool? _wasAdmin;
  bool _roleJumpPending = false;
  bool _wasBackgrounded = false;
  bool _wasOffline = false;
  Future<void>? _refreshFuture;
  late final AppLifecycleListener _lifecycle;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final offline = context.watch<NetworkStatus?>()?.offline ?? false;
    if (_wasOffline && !offline) unawaited(_refresh());
    _wasOffline = offline;
    final isAdmin = context.watch<AuthProvider>().currentUser?.isAdmin;
    if (isAdmin == null) return;
    final previous = _wasAdmin;
    _wasAdmin = isAdmin;
    if (previous == null || previous == isAdmin) return;

    // Keep Profile selected when its index moves; leave a removed Admin page.
    if (_currentIndex == (previous ? 3 : 2)) {
      _currentIndex = isAdmin ? 3 : 2;
    } else if (previous && _currentIndex == 2) {
      _currentIndex = 0;
    }
    _roleJumpPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _roleJumpPending = false;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
    });
  }

  void _selectTab(int index) {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (_roleJumpPending ||
        user == null ||
        index < 0 ||
        index >= (user.isAdmin ? 4 : 3) ||
        index == _currentIndex) {
      return;
    }
    setState(() => _currentIndex = index);
    if (!_wasOffline && auth.isPublicBuild && user.isAdmin && index == 2) {
      context.read<AdminProvider>().loadDashboard();
    }
  }

  void _onTabTapped(int index) {
    _selectTab(index);
    if (!_roleJumpPending &&
        index == _currentIndex &&
        _pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
  }

  Widget _tab(String id, int index, Widget child) => _KeptAliveTab(
    key: ValueKey(id),
    child: TickerMode(enabled: _currentIndex == index, child: child),
  );

  void _onLifecycleChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) return;
    if (state != AppLifecycleState.resumed) {
      _wasBackgrounded = true;
    } else if (_wasBackgrounded) {
      _wasBackgrounded = false;
      _refresh();
    }
  }

  Future<void> _refresh() =>
      _refreshFuture ??= Future<void>.microtask(_refreshData).whenComplete(() {
        _refreshFuture = null;
      });

  Future<void> _refreshData() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isPublicBuild || auth.isPreview || _wasOffline) return;
    await auth.refreshSession();
    if (!mounted || auth.currentUser == null) return;
    final user = auth.currentUser!;
    await context.read<AttendanceHistoryProvider>().loadHistory(
      user.id,
      force: true,
    );
    if (!mounted) return;
    await context.read<ProfileProvider>().loadProfileData(user.id);
    if (!mounted) return;
    try {
      await context.read<AttendanceProvider>().loadWindowConfig();
    } catch (_) {
      /* The server still enforces the last policy. */
    }
    if (mounted && user.isAdmin) {
      unawaited(context.read<AdminActivityProvider?>()?.refresh());
      await context.read<AdminProvider>().loadDashboard();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    // Handle null user case (e.g., during logout or initial load)
    if (user == null) {
      return Scaffold(body: LoadingWidget(message: 'Loading session...'));
    }

    final isAdmin = user.role == 'admin';
    final offline =
        !authProvider.isPreview &&
        context.select((NetworkStatus? status) => status?.offline ?? false);

    final pages = [
      _tab('home-page', 0, AttendanceScreen(employee: user)),
      _tab(
        'history-page',
        1,
        offline
            ? const OfflineOfficePane(title: 'History')
            : const HistoryScreen(),
      ),
      if (isAdmin)
        _tab(
          'admin-page',
          2,
          offline
              ? const OfflineOfficePane(title: 'Admin')
              : const AdminDashboardScreen(),
        ),
      _tab('profile-page', isAdmin ? 3 : 2, const ProfileScreen()),
    ];

    return Scaffold(
      // The dock floats over the page; extendBody lets pages run underneath it
      // and gives them the dock's height as bottom MediaQuery padding.
      extendBody: true,
      body: SafeArea(
        top: false,
        bottom: false,
        child: InAppNotificationHost(
          scopeKey: authProvider.officeScopeKey,
          child: _LiveCheckInBanners(
            activity: context.select(
              (AdminActivityProvider? provider) => provider,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: PageView(
                    key: const PageStorageKey('main-pages'),
                    controller: _pageController,
                    physics: MediaQuery.disableAnimationsOf(context)
                        ? const PageScrollPhysics()
                        : const _NavigationPagePhysics(),
                    onPageChanged: _selectTab,
                    children: pages,
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: NavigationFooterBackdrop(),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        // Ensure the BottomNav knows which items to show
        isAdmin: isAdmin,
      ),
    );
  }
}

class _LiveCheckInBanners extends StatefulWidget {
  const _LiveCheckInBanners({required this.activity, required this.child});

  final AdminActivityProvider? activity;
  final Widget child;

  @override
  State<_LiveCheckInBanners> createState() => _LiveCheckInBannersState();
}

class _LiveCheckInBannersState extends State<_LiveCheckInBanners> {
  StreamSubscription<OfficeCheckInActivity>? _subscription;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(_LiveCheckInBanners oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity != widget.activity) _listen();
  }

  void _listen() {
    unawaited(_subscription?.cancel());
    _subscription = widget.activity?.arrivals.listen((checkIn) {
      if (!mounted) return;
      InAppNotification.show(
        context,
        InAppNotification(
          title: '${checkIn.employeeName} checked in',
          actionLabel: 'View activity',
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const AdminNotificationScreen()),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Preserves visited screens and their scroll/form state between swipes.
class _KeptAliveTab extends StatefulWidget {
  const _KeptAliveTab({super.key, required this.child});
  final Widget child;

  @override
  State<_KeptAliveTab> createState() => _KeptAliveTabState();
}

class _KeptAliveTabState extends State<_KeptAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Settles swipes with a light spring while retaining normal page snapping.
class _NavigationPagePhysics extends PageScrollPhysics {
  const _NavigationPagePhysics({super.parent});

  @override
  SpringDescription get spring => AppMotion.pageSpring;

  @override
  _NavigationPagePhysics applyTo(ScrollPhysics? ancestor) =>
      _NavigationPagePhysics(parent: buildParent(ancestor));
}
