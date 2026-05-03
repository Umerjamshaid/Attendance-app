import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/screens/home/attendance_screen.dart';
import 'package:attendance/screens/history/history_screen.dart';
import 'package:attendance/screens/admin/admin_dashboard_screen.dart';
import 'package:attendance/screens/profile/profile_screen.dart';
import 'package:attendance/widgets/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  _AppShellState createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    final pages = [
      AttendanceScreen(
        employeeName: user?.name ?? 'Unknown',
        employeeId: user?.id ?? '',
        department: user?.department ?? 'General',
      ),
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
