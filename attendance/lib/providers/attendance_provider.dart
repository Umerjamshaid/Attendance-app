import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/office_location_model.dart';
import '../services/location_service.dart';
import '../services/office_service.dart';
import '../services/device_service.dart';
import '../services/local_storage_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final OfficeService _officeService = OfficeService();
  final DeviceService _deviceService = DeviceService();
  final LocalStorageService _storageService = LocalStorageService();

  bool _isLoading = false;
  String? _error;
  bool _isCheckedIn = false;
  String _checkInTime = '';
  String _deviceModel = 'Detecting...';
  OfficeLocationModel? _officeLocation;
  bool _hasUploadedToday = false;

  // Admin-configurable upload window.
  // mode: 'always' (no time restriction) or 'period' (start..end hour).
  String _windowMode = 'period';
  int _windowStartHour = 7;
  int _windowEndHour = 13;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isCheckedIn => _isCheckedIn;
  String get checkInTime => _checkInTime;
  String get deviceModel => _deviceModel;
  OfficeLocationModel? get officeLocation => _officeLocation;
  bool get hasUploadedToday => _hasUploadedToday;

  String get windowMode => _windowMode;
  int get windowStartHour => _windowStartHour;
  int get windowEndHour => _windowEndHour;

  bool isUploadWindowOpen() {
    if (_windowMode == 'always') return true;
    final hour = DateTime.now().hour;
    return hour >= _windowStartHour && hour < _windowEndHour;
  }

  String formatHour(int hour) {
    final normalized = ((hour % 24) + 24) % 24;
    final period = normalized >= 12 ? 'PM' : 'AM';
    var h = normalized % 12;
    if (h == 0) h = 12;
    return '$h:00 $period';
  }

  String get uploadButtonLabel {
    if (_hasUploadedToday) return "Already Uploaded Today";
    if (!isUploadWindowOpen()) {
      return "Upload open ${formatHour(_windowStartHour)} - ${formatHour(_windowEndHour)}";
    }
    return "Upload Image";
  }

  bool get isUploadEnabled => !_hasUploadedToday && isUploadWindowOpen();

  Future<void> loadWindowConfig() async {
    final cfg = await _storageService.getAttendanceWindow();
    if (cfg != null) {
      _windowMode = (cfg['mode'] as String?) ?? 'period';
      _windowStartHour = (cfg['startHour'] as int?) ?? 7;
      _windowEndHour = (cfg['endHour'] as int?) ?? 13;
    }
    notifyListeners();
  }

  Future<void> checkUploadedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpload = prefs.getString('last_image_upload_date');
    final todayStr = _getTodayStr();
    _hasUploadedToday = (lastUpload == todayStr);
    notifyListeners();
  }

  Future<void> markImageUploaded() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = _getTodayStr();
    await prefs.setString('last_image_upload_date', todayStr);
    _hasUploadedToday = true;
    notifyListeners();
  }

  String _getTodayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _deviceModel = await _deviceService.getDeviceModel();
      _officeLocation = await _officeService.getOfficeLocation();
      await loadWindowConfig();
      await checkUploadedToday();
    } catch (e) {
      _error = 'Initialization failed';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> attemptCheckIn(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Get the office location data
      final office = await _officeService.getOfficeLocation();

      // 2. Get the user's real, non-faked location
      final userPosition = await _locationService.getVerifiedLocation();

      // 3. Calculate the distance
      final distance = _locationService.calculateDistanceInMeters(
        userPosition.latitude,
        userPosition.longitude,
        office.latitude,
        office.longitude,
      );

      // 4. The Geofence Rule (Radius check)
      if (distance > office.radiusInMeters) {
        throw Exception(
          'You are ${distance.toStringAsFixed(0)} meters away from the ${office.name}. Move closer.',
        );
      }

      // 5. Successful validation - Proceed with check-in
      // (Normally you would call an API here)
      final now = DateTime.now();
      _checkInTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
      _isCheckedIn = true;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      // Clean up error message for the UI
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _isCheckedIn = false;
    _checkInTime = '';
    _error = null;
    notifyListeners();
  }
}
