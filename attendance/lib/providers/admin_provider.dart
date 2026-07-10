// ── 3B. AdminProvider  →  powers the Admin Screen
import 'package:flutter/material.dart';

import '../models/attendance_record_model.dart';
import '../models/employees_model.dart';

import '../services/attendance_service.dart';
import '../services/employees_service.dart';

class AdminProvider extends ChangeNotifier {
  final AttendanceService _attendanceService;
  final EmployeeService _employeeService;

  AdminProvider({
    AttendanceService? attendanceService,
    EmployeeService? employeeService,
  }) : _attendanceService = attendanceService ?? AttendanceService(),
       _employeeService = employeeService ?? EmployeeService();

  // ── State
  List<EmployeeAttendance> _allEmployeeAttendance = [];
  bool _isLoading = false;
  String? _error;

  // ── Selected tab: 'all', 'present', 'absent'
  String _filter = 'present';

  // ── Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get filter => _filter;

  int get totalEmployees => _allEmployeeAttendance.length;
  int get presentToday =>
      _allEmployeeAttendance.where((e) => e.isPresent).length;
  int get absentToday =>
      _allEmployeeAttendance.where((e) => !e.isPresent).length;

  // Filtered list based on selected tab
  List<EmployeeAttendance> get filteredList {
    switch (_filter) {
      case 'present':
        return _allEmployeeAttendance.where((e) => e.isPresent).toList();
      case 'absent':
        return _allEmployeeAttendance.where((e) => !e.isPresent).toList();
      default:
        return _allEmployeeAttendance;
    }
  }

  // ── Actions
  void setFilter(String filter) {
    _filter = filter;
    notifyListeners(); // UI rebuilds list instantly, no new API call needed
  }

  Future<void> loadDashboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load employees and today's attendance at the same time (faster)
      final results = await Future.wait([
        _employeeService.getAllEmployees(),
        _attendanceService.getTodayAllAttendance(),
      ]);

      final employees = results[0] as List<Employee>;
      final todayRecords = results[1] as List<AttendanceRecord>;

      // Match each employee to their latest attendance record
      _allEmployeeAttendance = employees.map((emp) {
        final latestRecord = todayRecords
            .where((r) => r.userId == emp.id)
            .fold<AttendanceRecord?>(null, (prev, r) {
              if (prev == null) return r;
              return r.timestamp.isAfter(prev.timestamp) ? r : prev;
            });
        return EmployeeAttendance(employee: emp, latestRecord: latestRecord);
      }).toList();
    } catch (e) {
      _error = 'Failed to load dashboard. Try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
