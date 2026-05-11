import 'package:attendance/providers/admin_provider.dart';
import 'package:attendance/widgets/admin/dashboard_header.dart';
import 'package:attendance/widgets/admin/employee_card.dart';
import 'package:attendance/widgets/admin/office_location_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/wc_tokens.dart';
import 'set_office_location_sheet.dart';

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
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _openLocationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SetOfficeLocationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();
    final isLoading = adminProvider.isLoading;
    final filteredList = adminProvider.filteredList;

    return Scaffold(
      backgroundColor: WC.bg,
      body: Column(
        children: [
          DashboardHeader(
            totalEmployees: adminProvider.totalEmployees,
            presentToday: adminProvider.presentToday,
            absentToday: adminProvider.absentToday,
            tab: _tab,
            activeTab: adminProvider.filter == 'present' ? 1 : (adminProvider.filter == 'absent' ? 2 : 0),
            onTabChanged: (i) {
              final filter = i == 1 ? 'present' : (i == 2 ? 'absent' : 'all');
              adminProvider.setFilter(filter);
            },
          ),
          Expanded(
            child: isLoading 
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => adminProvider.loadDashboard(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    children: [
                      OfficeLocationCard(onEdit: _openLocationSheet),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            const Text(
                              'EMPLOYEES',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                                color: WC.muted,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${filteredList.length} shown',
                              style: const TextStyle(fontSize: 12, color: WC.muted),
                            ),
                          ],
                        ),
                      ),
                      if (filteredList.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Text('No employees found', style: TextStyle(color: WC.muted)),
                          ),
                        )
                      else
                        ...filteredList.map((e) => EmployeeCard(data: e.employee)),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
