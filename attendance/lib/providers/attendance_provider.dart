import 'package:flutter/material.dart';
import '../models/office_location_model.dart';
import '../services/location_service.dart';
import '../services/office_service.dart';
import '../services/device_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final OfficeService _officeService = OfficeService();
  final DeviceService _deviceService = DeviceService();

  bool _isLoading = false;
  String? _error;
  bool _isCheckedIn = false;
  String _checkInTime = '';
  String _deviceModel = 'Detecting...';
  OfficeLocationModel? _officeLocation;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isCheckedIn => _isCheckedIn;
  String get checkInTime => _checkInTime;
  String get deviceModel => _deviceModel;
  OfficeLocationModel? get officeLocation => _officeLocation;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _deviceModel = await _deviceService.getDeviceModel();
      _officeLocation = await _officeService.getOfficeLocation();
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
