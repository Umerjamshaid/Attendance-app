import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocalStorageService {
  static const String _attendanceWindowKey = 'attendance_window';

  // Save the admin-configured attendance upload window.
  // mode: 'always' (no time restriction) or 'period' (startHour..endHour).
  Future<void> saveAttendanceWindow({
    required String mode,
    required int startHour,
    required int endHour,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final data = {
      'mode': mode,
      'startHour': startHour,
      'endHour': endHour,
    };

    await prefs.setString(_attendanceWindowKey, jsonEncode(data));
  }

  // Load the admin-configured attendance upload window.
  Future<Map<String, dynamic>?> getAttendanceWindow() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_attendanceWindowKey);

    if (data == null) return null;
    return jsonDecode(data);
  }
}
