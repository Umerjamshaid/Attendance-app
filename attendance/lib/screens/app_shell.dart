import 'package:attendance/screens/attendance_screen.dart';
import 'package:attendance/screens/history/history_screen.dart';
import 'package:attendance/screens/admin/admin_dashboard_screen.dart';
import 'package:attendance/screens/profile_screen.dart';
import 'package:attendance/widgets/bottom_nav.dart';
import 'package:flutter/material.dart';

class AppShell extends StatefulWidget {
  const AppShell({Key? key}) : super(key: key);

  @override
  _AppShellState createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  Widget _homeScreen() {
    // Lightweight wrapper to provide sample user data for the AttendanceScreen
    return const AttendanceScreen(
      employeeName: 'Demo User',
      employeeId: 'EMP001',
      department: 'Operations',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _homeScreen(),
      const HistoryScreen(),
      const AdminDashboardScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() {
          _currentIndex = idx;
        }),
      ),
    );
  }
}
