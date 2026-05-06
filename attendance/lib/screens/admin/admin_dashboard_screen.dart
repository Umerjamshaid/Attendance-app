import 'package:attendance/widgets/admin/dashboard_header.dart';
import 'package:attendance/widgets/admin/employee_card.dart';
import 'package:attendance/widgets/admin/office_location_card.dart';

import 'package:flutter/material.dart';
import '../../config/wc_tokens.dart';
import 'set_office_location_sheet.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _activeTab = 1;

  final _employees = const [
    EmployeeData(
      'Alice Johnson',
      'Engineering',
      'EMP001',
      'Apr 22  03:15 PM',
      true,
    ),
    EmployeeData('Eva Martinez', 'Design', 'EMP002', 'Apr 22  02:48 PM', true),
    EmployeeData(
      'James Wilson',
      'Marketing',
      'EMP003',
      'Apr 22  09:01 AM',
      true,
    ),
    EmployeeData('Priya Sharma', 'Product', 'EMP004', '—', false),
    EmployeeData('David Kim', 'Engineering', 'EMP005', '—', false),
    EmployeeData('Sara Perez', 'HR', 'EMP006', '—', false),
    EmployeeData('Tom Nguyen', 'Sales', 'EMP007', '—', false),
    EmployeeData('Lena Brooks', 'Finance', 'EMP008', '—', false),
  ];

  List<EmployeeData> get _filtered {
    if (_activeTab == 1) return _employees.where((e) => e.isPresent).toList();
    if (_activeTab == 2) return _employees.where((e) => !e.isPresent).toList();
    return _employees;
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this, initialIndex: 1);
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
    final present = _employees.where((e) => e.isPresent).length;
    final absent = _employees.length - present;

    return Scaffold(
      backgroundColor: WC.bg,
      body: Column(
        children: [
          DashboardHeader(
            totalEmployees: _employees.length,
            presentToday: present,
            absentToday: absent,
            tab: _tab,
            activeTab: _activeTab,
            onTabChanged: (i) => setState(() => _activeTab = i),
          ),
          Expanded(
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
                        '${_filtered.length} shown',
                        style: const TextStyle(fontSize: 12, color: WC.muted),
                      ),
                    ],
                  ),
                ),
                ..._filtered.map((e) => EmployeeCard(data: e)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmployeeData {
  final String name, department, id, time;
  final bool isPresent;
  const EmployeeData(
    this.name,
    this.department,
    this.id,
    this.time,
    this.isPresent,
  );
}
