// ─────────────────────────────────────────────────────────────
//  SECTION 1 — MODELS
//  Plain Dart classes. No logic. Just data shapes.
// ─────────────────────────────────────────────────────────────

import 'employees_model.dart';

class AttendanceRecord {
  final String id;
  final String userId;
  final bool isPresent;
  final DateTime timestamp;
  final String device;

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.isPresent,
    required this.timestamp,
    required this.device,
  });

  // Converts raw map (from Firestore/API) → AttendanceRecord
  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      isPresent: map['isPresent'] ?? false,
      timestamp: DateTime.parse(map['timestamp']),
      device: map['device'] ?? 'unknown',
    );
  }
}

// Represents one employee + their latest attendance status
class EmployeeAttendance {
  final Employee employee;
  final AttendanceRecord? latestRecord; // null = never checked in

  EmployeeAttendance({required this.employee, this.latestRecord});

  bool get isPresent => latestRecord?.isPresent ?? false;
}

class AttendanceGroup {
  final String date;
  final List<AttendanceRecord> records;
  AttendanceGroup({required this.date, required this.records});
}
