import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/screens/home/attendance_screen.dart';
import 'package:attendance/screens/history/history_screen.dart';
import 'package:attendance/screens/admin/admin_dashboard_screen.dart';
import 'package:attendance/screens/profile/profile_screen.dart';
import 'package:attendance/widgets/bottom_nav.dart';
import 'package:attendance/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/attendance_history_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/admin_provider.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  AppShellState createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  late final AppLifecycleListener _lifecycle;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isPublicBuild || auth.isPreview) return;
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
      await context.read<AdminProvider>().loadDashboard();
    }
  }

  @override
  void dispose() {
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

    final pages = [
      AttendanceScreen(employee: user, isActive: _currentIndex == 0),
      const HistoryScreen(),
      if (isAdmin) const AdminDashboardScreen(),
      const ProfileScreen(),
    ];
    if (_currentIndex >= pages.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      // The dock floats over the page; extendBody lets pages run underneath it
      // and gives them the dock's height as bottom MediaQuery padding.
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(index: _currentIndex, children: pages),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: NavigationFooterBackdrop(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() {
          _currentIndex = idx;
          if (authProvider.isPublicBuild && user.isAdmin && idx == 2) {
            context.read<AdminProvider>().loadDashboard();
          }
        }),
        // Ensure the BottomNav knows which items to show
        isAdmin: isAdmin,
      ),
    );
  }
}
