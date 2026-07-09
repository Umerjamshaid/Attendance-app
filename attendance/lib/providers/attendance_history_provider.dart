// ─────────────────────────────────────────────────────────────
//  SECTION 3 — PROVIDERS
//  Providers hold state for the UI.
//  They call services, store results, and notify the UI to rebuild.
//  The UI listens to providers using Consumer<T> or context.watch<T>()
// ─────────────────────────────────────────────────────────────

// ── 3A. AttendanceHistoryProvider  →  powers the History Screen
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/attendance_record_model.dart';
import '../services/attendance_service.dart';

class AttendanceHistoryProvider extends ChangeNotifier {
  final AttendanceService _service;

  AttendanceHistoryProvider({AttendanceService? service})
    : _service = service ?? AttendanceService();

  // ── State variables (what the UI reads)
  List<AttendanceRecord> _records = [];
  bool _isLoading = false;
  String? _error;

  // ── Getters (UI reads these, never the private vars directly)
  List<AttendanceRecord> get records => _records;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Computed stats (derived from records, no extra storage needed)
  int get presentCount => _records.where((r) => r.isPresent).length;
  int get absentCount => _records.where((r) => !r.isPresent).length;
  int get totalCount => _records.length;

  int get currentStreak {
    if (_records.isEmpty) return 0;
    final presentDays = _records
        .where((r) => r.isPresent)
        .map((r) => DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // sorted descending (newest first)

    if (presentDays.isEmpty) return 0;

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final yesterday = today.subtract(const Duration(days: 1));

    // If neither today nor yesterday has a present record, the streak has been broken.
    if (!presentDays.contains(today) && !presentDays.contains(yesterday)) {
      return 0;
    }

    int streak = 0;
    DateTime currentDay = presentDays.contains(today) ? today : yesterday;

    while (presentDays.contains(currentDay)) {
      streak++;
      currentDay = currentDay.subtract(const Duration(days: 1));
    }

    return streak;
  }

  double get monthlyRate {
    if (_records.isEmpty) return 0.0;
    final now = DateTime.now();
    final presentThisMonth = _records
        .where((r) =>
            r.isPresent &&
            r.timestamp.year == now.year &&
            r.timestamp.month == now.month)
        .map((r) => DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day))
        .toSet()
        .length;

    if (now.day == 0) return 0.0;
    final rate = presentThisMonth / now.day;
    return rate.clamp(0.0, 1.0);
  }

  int get presentThisMonthCount {
    final now = DateTime.now();
    return _records
        .where((r) =>
            r.isPresent &&
            r.timestamp.year == now.year &&
            r.timestamp.month == now.month)
        .map((r) => DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day))
        .toSet()
        .length;
  }

  // ── Records grouped by date, ready for the UI to display
  //    Returns: [ AttendanceGroup(date: 'Wed, Apr 22', records: [...]), ... ]
  List<AttendanceGroup> get groups {
    final Map<String, List<AttendanceRecord>> grouped = {};
    for (final record in _records) {
      final dateKey = _formatDateKey(record.timestamp);
      grouped.putIfAbsent(dateKey, () => []).add(record);
    }
    return grouped.entries
        .map((e) => AttendanceGroup(date: e.key, records: e.value))
        .toList();
  }

  String _formatDateKey(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  // Add this inside AttendanceHistoryProvider
  Future<bool> markAttendanceNow({
    required String userId,
    required bool isPresent,
    required String device,
  }) async {
    // 1. Create the new record locally (The "Optimistic" part)
    final newRecord = AttendanceRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      isPresent: isPresent,
      timestamp: DateTime.now(),
      device: device,
    );

    // 2. Inject it at the TOP of the list so it shows first
    _records.insert(0, newRecord);

    // 3. Tell the UI to rebuild instantly with the new stat counts and list
    notifyListeners();

    // 4. Send it to the backend silently
    try {
      await _service.submitAttendance(
        userId: userId,
        isPresent: isPresent,
        device: device,
      );
      return true;
    } catch (e) {
      // If the internet fails, you would handle offline storage here.
      // For now, if it fails, we remove the fake record and notify UI.

      _records.removeWhere((r) => r.id == newRecord.id);
      _error = 'Failed to submit attendance. Connection lost.';
      notifyListeners();
      return false;
    }
  }

  // Inside AttendanceHistoryProvider class
Future<void> addRecordOptimistically(AttendanceRecord record) async {
  // 1. Insert at the beginning of the list (index 0)
  _records.insert(0, record);
  
  // 2. Notify all listeners (like the HistoryScreen) to rebuild
  notifyListeners();
}

  // ── Actions (UI calls these)
  Future<void> loadHistory(String userId, {bool force = false}) async {
    // Optimization: Don't reload if we already have data for THIS user, unless forced
    if (_records.isNotEmpty && 
        _records.every((r) => r.userId == userId) && 
        !force && 
        !_isLoading) return;

    _isLoading = true;
    _error = null;
    // Clear old records so they don't show briefly for the new user
    _records = []; 
    notifyListeners(); 

    try {
      final remoteRecords = await _service.getUserAttendance(userId);
      _records = remoteRecords;
    } catch (e) {
      _error = 'Failed to load attendance. Try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check if the user has already checked in today
  bool get isPresentToday {
    if (_records.isEmpty) return false;
    final now = DateTime.now();
    return _records.any((r) =>
        r.isPresent &&
        r.timestamp.year == now.year &&
        r.timestamp.month == now.month &&
        r.timestamp.day == now.day);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
