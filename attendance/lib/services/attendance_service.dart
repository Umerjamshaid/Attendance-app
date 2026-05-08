// ─────────────────────────────────────────────────────────────
//  SECTION 2 — SERVICES
//  Services talk to Firebase, REST APIs, device GPS, etc.
//  They have NO idea about Flutter or UI.
//  They just fetch, post, and return data.
// ─────────────────────────────────────────────────────────────

// ── 2A. AttendanceService
//    Responsible for: fetching attendance records
import 'package:attendance/models/attendance_record_model.dart';

class AttendanceService {
  // Replace these methods' internals with your Firebase/API calls.
  // The method signatures stay the same regardless of backend.

  // Get attendance history for one user (for History screen)
  Future<List<AttendanceRecord>> getUserAttendance(String userId) async {
    // Example with Firebase:
    // final snapshot = await FirebaseFirestore.instance
    //     .collection('attendance')
    //     .where('userId', isEqualTo: userId)
    //     .orderBy('timestamp', descending: true)
    //     .get();
    // return snapshot.docs
    //     .map((doc) => AttendanceRecord.fromMap({...doc.data(), 'id': doc.id}))
    //     .toList();

    // --- MOCK DATA (replace this with real call above) ---
    await Future.delayed(const Duration(seconds: 1));
    return [
      AttendanceRecord(
        id: '1',
        userId: userId,
        isPresent: false,
        timestamp: DateTime.now(),
        device: 'web-browser',
      ),
      AttendanceRecord(
        id: '2',
        userId: userId,
        isPresent: true,
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        device: 'mobile',
      ),
    ];
  }

  // Get today's attendance for ALL employees (for Admin screen)
  Future<List<AttendanceRecord>> getTodayAllAttendance() async {
    // final today = DateTime.now();
    // final startOfDay = DateTime(today.year, today.month, today.day);
    // final snapshot = await FirebaseFirestore.instance
    //     .collection('attendance')
    //     .where('timestamp', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
    //     .orderBy('timestamp', descending: true)
    //     .get();

    await Future.delayed(const Duration(seconds: 1));
    return []; // replace with real data
  }

  // Mark user as present or absent (called on check-in)
  Future<void> submitAttendance({
    required String userId,
    required bool isPresent,
    required String device,
  }) async {
    // await FirebaseFirestore.instance.collection('attendance').add({
    //   'userId': userId,
    //   'isPresent': isPresent,
    //   'timestamp': DateTime.now().toIso8601String(),
    //   'device': device,
    // });

    await Future.delayed(const Duration(milliseconds: 500));
  }
}
