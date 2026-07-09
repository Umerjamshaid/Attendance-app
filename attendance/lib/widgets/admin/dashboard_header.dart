import 'package:attendance/screens/admin/admin_notification_screen.dart';
import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/widgets/admin/state_cell.dart';
import 'package:attendance/widgets/admin/tab_row.dart';
import 'package:flutter/material.dart';

class DashboardHeader extends StatelessWidget {
  final int totalEmployees, presentToday, absentToday, activeTab;
  final TabController tab;
  final ValueChanged<int> onTabChanged;

  const DashboardHeader({
    required this.totalEmployees,
    required this.presentToday,
    required this.absentToday,
    required this.tab,
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: WC.black,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Dashboard',
                          style: TextStyle(
                            color: WC.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Live attendance overview',
                          style: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  HeaderIconButton(icon: Icons.notifications_none_rounded),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    StatCell(
                      value: '$totalEmployees',
                      label: 'Employees',
                      color: WC.white,
                    ),
                    StatDivider(),
                    StatCell(
                      value: '$presentToday',
                      label: 'Present Today',
                      color: WC.present,
                    ),
                    StatDivider(),
                    StatCell(
                      value: '$absentToday',
                      label: 'Absent Today',
                      color: WC.absent,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TabRow(activeTab: activeTab, onTap: onTabChanged),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  const HeaderIconButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminNotificationScreen(),
          ),
        );
      },
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: WC.white, size: 20),
      ),
    );
  }
}
