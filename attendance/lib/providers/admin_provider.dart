// ── 3B. AdminProvider  →  powers the Admin Screen
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/attendance_record_model.dart';
import '../models/employees_model.dart';

import '../services/attendance_service.dart';
import '../services/employees_service.dart';

class AdminProvider extends ChangeNotifier {
  final AttendanceService _attendanceService;
  final EmployeeService _employeeService;
  bool _disposed = false;
  int _generation = 0;
  Future<void>? _dashboardFuture;
  bool get usesCheckInLog => _attendanceService.backend != null;

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
  bool get isDemoMode =>
      _attendanceService.isDemoMode || _employeeService.isDemoMode;

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

  Future<void> loadDashboard() {
    if (_disposed) return Future<void>.value();
    final pending = _dashboardFuture;
    if (pending != null) return pending;
    final generation = ++_generation;
    _isLoading = true;
    _error = null;
    late final Future<void> request;
    request = Future<void>.microtask(() => _loadDashboard(generation))
        .whenComplete(() {
          if (identical(_dashboardFuture, request)) _dashboardFuture = null;
        });
    _dashboardFuture = request;
    notifyListeners();
    return request;
  }

  Future<void> _loadDashboard(int generation) async {
    if (_disposed || generation != _generation) return;
    try {
      // Load employees and today's attendance at the same time (faster)
      final results = await Future.wait([
        _employeeService.getAllEmployees(),
        _attendanceService.getTodayAllAttendance(),
      ]);
      if (_disposed || generation != _generation) return;

      final employees = (results[0] as List<Employee>).where((e) => e.isActive);
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
      unawaited(_loadAvatars(employees.toList(), generation));
    } catch (e) {
      if (_disposed || generation != _generation) return;
      _error = 'Failed to load dashboard. Try again.';
    } finally {
      if (!_disposed && generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadAvatars(List<Employee> employees, int generation) async {
    final backend = _employeeService.backend;
    if (backend == null || employees.isEmpty) return;
    try {
      final avatars = await backend
          .employeeAvatars(employees)
          .timeout(const Duration(seconds: 10));
      if (_disposed || generation != _generation || avatars.isEmpty) return;
      _allEmployeeAttendance = _allEmployeeAttendance
          .map(
            (data) => EmployeeAttendance(
              employee: data.employee.copyWith(
                avatarUrl: avatars[data.employee.authUserId],
              ),
              latestRecord: data.latestRecord,
            ),
          )
          .toList();
      notifyListeners();
    } catch (_) {
      // Names, status and attendance remain usable when photos are unavailable.
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
