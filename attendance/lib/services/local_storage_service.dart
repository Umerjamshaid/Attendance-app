import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocalStorageService {
  static const String _officeLocationKey = 'office_location';

  // Save office location
  Future<void> saveOfficeLocation({
    required String name,
    required double latitude,
    required double longitude,
    required int radius,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final data = {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
    };

    await prefs.setString(_officeLocationKey, jsonEncode(data));
  }

  // Load office location
  Future<Map<String, dynamic>?> getOfficeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_officeLocationKey);

    if (data == null) return null;
    return jsonDecode(data);
  }

  // Clear office location
  Future<void> clearOfficeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_officeLocationKey);
  }
}
