import 'package:attendance/models/office_location_model.dart';
import 'package:attendance/services/device_service.dart';
import 'package:attendance/services/office_service.dart';
import 'package:flutter/material.dart';
import '../services/attendance_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _service;
  final DeviceService _deviceService;
  final OfficeService _officeService;

  AttendanceProvider({
    AttendanceService? service,
    DeviceService? deviceService,
    OfficeService? officeService,
  }) : _service = service ?? AttendanceService(),
       _deviceService = deviceService ?? DeviceService(),
       _officeService = officeService ?? OfficeService();

  bool _isLoading = false;
  String? _error;
  String _deviceModel = 'Unknown';
  OfficeLocation? _officeLocation;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get deviceModel => _deviceModel;
  OfficeLocation? get officeLocation => _officeLocation;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _deviceModel = await _deviceService.getDeviceModel();
      _officeLocation = await _officeService.getOfficeLocation();
    } catch (e) {
      _error = 'Failed to initialize attendance data';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitAttendance({
    required String userId,
    required bool isPresent,
    required String device,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.submitAttendance(
        userId: userId,
        isPresent: isPresent,
        device: device,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to submit attendance';
      notifyListeners();
      return false;
    }
  }
}
