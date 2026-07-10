import 'package:attendance/providers/admin_provider.dart';
import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/widgets/admin/dashboard_header.dart';
import 'package:attendance/widgets/admin/employee_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/wc_tokens.dart';
import 'set_attendance_window_sheet.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => AdminDashboardScreenState();
}

class AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this, initialIndex: 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadDashboard();
      context.read<AttendanceProvider>().loadWindowConfig();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _openWindowSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SetAttendanceWindowSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();
    final isLoading = adminProvider.isLoading;
    final filteredList = adminProvider.filteredList;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: DashboardHeader(
              totalEmployees: adminProvider.totalEmployees,
              presentToday: adminProvider.presentToday,
              absentToday: adminProvider.absentToday,
              tab: _tab,
              activeTab: adminProvider.filter == 'present'
                  ? 1
                  : (adminProvider.filter == 'absent' ? 2 : 0),
              onTabChanged: (i) {
                final filter = i == 1 ? 'present' : (i == 2 ? 'absent' : 'all');
                adminProvider.setFilter(filter);
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: _AttendanceWindowCard(onEdit: _openWindowSheet),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  const Text(
                    'EMPLOYEES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${filteredList.length} shown',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8E8E93),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF1B1D1F)),
              ),
            )
          else if (filteredList.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                title: 'No employees found',
                subtitle: 'Try changing the filter or add new employees.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return EmployeeCard(data: filteredList[index]);
                  },
                  childCount: filteredList.length,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _AttendanceWindowCard extends StatelessWidget {
  final VoidCallback onEdit;

  const _AttendanceWindowCard({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final isAlways = provider.windowMode == 'always';
    final valueText = isAlways
        ? 'Always Open'
        : '${provider.formatHour(provider.windowStartHour)} - ${provider.formatHour(provider.windowEndHour)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WC.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFEFF4)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Color(0xFF1B1D1F),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attendance Window',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1D1F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valueText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1D1F),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, color: WC.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Set',
                    style: TextStyle(
                      color: WC.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_off_outlined,
              size: 36,
              color: Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1B1D1F),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
