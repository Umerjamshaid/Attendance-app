import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/screens/home/attendance_screen.dart';
import 'package:attendance/screens/history/history_screen.dart';
import 'package:attendance/screens/admin/admin_dashboard_screen.dart';
import 'package:attendance/screens/profile/profile_screen.dart';
import 'package:attendance/widgets/bottom_nav.dart';
import 'package:attendance/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  AppShellState createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _currentIndex = 0;

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
      AttendanceScreen(employee: user),
      const HistoryScreen(),
      if (isAdmin) const AdminDashboardScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() {
          _currentIndex = idx;
        }),
        // Ensure the BottomNav knows which items to show
        isAdmin: isAdmin, 
      ),
    );
  }
}
