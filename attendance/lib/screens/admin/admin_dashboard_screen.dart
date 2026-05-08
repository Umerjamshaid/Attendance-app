import 'package:attendance/models/employees_model.dart';
import 'package:attendance/services/employees_service.dart';
import 'package:attendance/widgets/admin/dashboard_header.dart';
import 'package:attendance/widgets/admin/employee_card.dart';
import 'package:attendance/widgets/admin/office_location_card.dart';

import 'package:flutter/material.dart';
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
  int _activeTab = 1;

  // ✅ Use EmployeeModel instead of EmployeeData
  final employees = [
    Employee(
      id: 'E001',
      name: 'Alice Johnson',
      email: 'alice.johnson@example.com',
      department: 'Engineering',
      time: 'Apr 22  03:15 PM',
      isPresentToday: true,
      role: 'admin', // Example of an admin user
    ),
    Employee(
      id: 'E002',
      name: 'Eva Martinez',
      email: 'eva.martinez@example.com',
      department: 'Design',
      time: 'Apr 22  02:48 PM',
      isPresentToday: true,
      role: 'employee', // Example of a regular employee
    ),
    Employee(
      id: 'E003',
      name: 'James Wilson',
      email: 'james.wilson@example.com',
      department: 'Marketing',
      time: 'Apr 22  09:01 AM',
      isPresentToday: false,
      role: 'employee',
    ),
    Employee(
      id: 'E004',
      name: 'Priya Sharma',
      email: 'priya.sharma@example.com',
      department: 'Product',
      time: '—',
      isPresentToday: true,
      role: 'employee',
    ),
  ];

  List<Employee> get _filtered {
    if (_activeTab == 1) {
      return employees.where((e) => e.isPresentToday).toList();
    }
    if (_activeTab == 2) {
      return employees.where((e) => !e.isPresentToday).toList();
    }
    return employees;
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
    final present = employees.where((e) => e.isPresentToday).length;
    final absent = employees.length - present;

    return Scaffold(
      backgroundColor: WC.bg,
      body: Column(
        children: [
          DashboardHeader(
            totalEmployees: employees.length,
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
