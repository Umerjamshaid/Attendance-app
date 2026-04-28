// ─────────────────────────────────────────────────────────────
//  SECTION 3 — PROVIDERS
//  Providers hold state for the UI.
//  They call services, store results, and notify the UI to rebuild.
//  The UI listens to providers using Consumer<T> or context.watch<T>()
// ─────────────────────────────────────────────────────────────

// ── 3A. AttendanceHistoryProvider  →  powers the History Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance_model.dart';
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

  // ── Records grouped by date, ready for the UI to display
  //    Returns: { 'Wed, Apr 22': [record1, record2], 'Tue, Apr 21': [...] }
  Map<String, List<AttendanceRecord>> get groupedByDate {
    final Map<String, List<AttendanceRecord>> grouped = {};
    for (final record in _records) {
      final dateKey = _formatDateKey(record.timestamp);
      grouped.putIfAbsent(dateKey, () => []).add(record);
    }
    return grouped;
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

  // ── Actions (UI calls these)
  Future<void> loadHistory(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners(); // tells UI: "start showing loading spinner"

    try {
      _records = await _service.getUserAttendance(userId);
    } catch (e) {
      _error = 'Failed to load attendance. Try again.';
    } finally {
      _isLoading = false;
      notifyListeners(); // tells UI: "done, rebuild with new data"
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
