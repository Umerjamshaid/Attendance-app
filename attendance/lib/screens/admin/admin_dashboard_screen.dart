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
    _EmployeeData(
      'Alice Johnson',
      'Engineering',
      'EMP001',
      'Apr 22  03:15 PM',
      true,
    ),
    _EmployeeData('Eva Martinez', 'Design', 'EMP002', 'Apr 22  02:48 PM', true),
    _EmployeeData(
      'James Wilson',
      'Marketing',
      'EMP003',
      'Apr 22  09:01 AM',
      true,
    ),
    _EmployeeData('Priya Sharma', 'Product', 'EMP004', '—', false),
    _EmployeeData('David Kim', 'Engineering', 'EMP005', '—', false),
    _EmployeeData('Sara Perez', 'HR', 'EMP006', '—', false),
    _EmployeeData('Tom Nguyen', 'Sales', 'EMP007', '—', false),
    _EmployeeData('Lena Brooks', 'Finance', 'EMP008', '—', false),
  ];

  List<_EmployeeData> get _filtered {
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
          _DashboardHeader(
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
                _OfficeLocationCard(onEdit: _openLocationSheet),
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
                ..._filtered.map((e) => _EmployeeCard(data: e)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final int totalEmployees, presentToday, absentToday, activeTab;
  final TabController tab;
  final ValueChanged<int> onTabChanged;

  const _DashboardHeader({
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
      color: WC.black,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Admin Dashboard',
                          style: TextStyle(
                            color: WC.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Live attendance overview',
                          style: TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HeaderIconButton(icon: Icons.notifications_none_rounded),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: WC.r16,
                  border: Border.all(color: const Color(0xFF222222)),
                ),
                child: Row(
                  children: [
                    _StatCell(
                      value: '$totalEmployees',
                      label: 'Employees',
                      color: WC.white,
                    ),
                    _StatDivider(),
                    _StatCell(
                      value: '$presentToday',
                      label: 'Present Today',
                      color: WC.present,
                    ),
                    _StatDivider(),
                    _StatCell(
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
              child: _TabRow(activeTab: activeTab, onTap: onTabChanged),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  const _HeaderIconButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Icon(icon, color: WC.white, size: 20),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatCell({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: const Color(0xFF2A2A2A));
  }
}

class _TabRow extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTap;
  const _TabRow({required this.activeTab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabItem(label: 'All', index: 0, activeTab: activeTab, onTap: onTap),
        _TabItem(
          label: 'Present',
          index: 1,
          activeTab: activeTab,
          onTap: onTap,
        ),
        _TabItem(label: 'Absent', index: 2, activeTab: activeTab, onTap: onTap),
      ],
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final int index, activeTab;
  final ValueChanged<int> onTap;
  const _TabItem({
    required this.label,
    required this.index,
    required this.activeTab,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == activeTab;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? WC.white : const Color(0xFF555555),
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ),
          Container(
            height: 2.5,
            width: isActive ? 28 : 0,
            decoration: BoxDecoration(color: WC.white, borderRadius: WC.rFull),
          ),
        ],
      ),
    );
  }
}

class _OfficeLocationCard extends StatelessWidget {
  final VoidCallback onEdit;
  const _OfficeLocationCard({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WC.card,
        borderRadius: WC.r16,
        border: Border.all(color: WC.border),
        boxShadow: WC.shadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: WC.bg, borderRadius: WC.r12),
            child: const Icon(
              Icons.business_rounded,
              color: WC.black,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Office Location',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: WC.black,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Osquare',
                  style: TextStyle(fontSize: 12, color: WC.muted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _MiniChip(
                      icon: Icons.location_on_rounded,
                      label: '24.00, 67.00',
                    ),
                    const SizedBox(width: 6),
                    _MiniChip(icon: Icons.radar_rounded, label: '100 m'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: WC.black,
                borderRadius: WC.rFull,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, color: WC.white, size: 13),
                  SizedBox(width: 5),
                  Text(
                    'Edit',
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

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: WC.bg,
        borderRadius: WC.r8,
        border: Border.all(color: WC.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 10, color: WC.muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: WC.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeData {
  final String name, department, id, time;
  final bool isPresent;
  const _EmployeeData(
    this.name,
    this.department,
    this.id,
    this.time,
    this.isPresent,
  );
}

class _EmployeeCard extends StatelessWidget {
  final _EmployeeData data;
  const _EmployeeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = data.isPresent ? WC.present : WC.absent;
    final initial = data.name[0];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WC.card,
        borderRadius: WC.r16,
        border: Border.all(color: WC.border),
        boxShadow: WC.shadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: WC.bg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: WC.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: WC.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${data.department} · ${data.id}',
                  style: const TextStyle(fontSize: 12, color: WC.muted),
                ),
                if (data.time != '—') ...[
                  const SizedBox(height: 2),
                  Text(
                    data.time,
                    style: const TextStyle(fontSize: 11, color: WC.muted),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.09),
              borderRadius: WC.rFull,
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  data.isPresent ? 'Present' : 'Absent',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
