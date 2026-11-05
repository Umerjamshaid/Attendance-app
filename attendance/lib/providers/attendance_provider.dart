import 'package:flutter/material.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/attendance_record_model.dart';
import '../services/company_backend.dart';
import '../services/device_service.dart';
import '../services/local_storage_service.dart';

class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider({this.backend})
    : _deviceService = DeviceService(
        useRealInfo: backend != null && !backend.isPreview,
      );
  final CompanyBackend? backend;
  final DeviceService _deviceService;
  bool _disposed = false;
  bool get isCompanyMode => backend != null;
  bool get isPreview => backend?.isPreview ?? false;
  String get companyTimezone => _timezone;
  String _timezone = 'Asia/Karachi';
  final LocalStorageService _storageService = LocalStorageService();

  bool _isLoading = false;
  String? _error;
  bool _isCheckedIn = false;
  String _checkInTime = '';
  String _deviceModel = 'Detecting...';

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

  String get windowMode => _windowMode;
  int get windowStartHour => _windowStartHour;
  int get windowEndHour => _windowEndHour;

  bool isUploadWindowOpen() {
    if (_windowMode == 'always') return true;
    final hour = (backend?.companyNow ?? DateTime.now()).hour;
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
    if (!isUploadWindowOpen()) {
      return "Upload open ${formatHour(_windowStartHour)} - ${formatHour(_windowEndHour)}";
    }
    return "Upload Image";
  }

  bool get isUploadEnabled => isUploadWindowOpen();

  Future<void> loadWindowConfig() async {
    if (backend != null) {
      final policy = await backend!.policy();
      _windowMode = policy.mode;
      _windowStartHour = policy.startHour;
      _windowEndHour = policy.endHour;
      _timezone = policy.timezone;
      notifyListeners();
      return;
    }
    final cfg = await _storageService.getAttendanceWindow();
    if (cfg != null) {
      _windowMode = (cfg['mode'] as String?) ?? 'period';
      _windowStartHour = (cfg['startHour'] as int?) ?? 7;
      _windowEndHour = (cfg['endHour'] as int?) ?? 13;
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _deviceModel = isPreview
          ? 'Sample Android device'
          : await _deviceService.getDeviceModel();
      await loadWindowConfig();
    } catch (e) {
      _error = 'Initialization failed';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveWindowConfig({
    required String mode,
    required int startHour,
    required int endHour,
  }) async {
    if (backend == null) {
      await _storageService.saveAttendanceWindow(
        mode: mode,
        startHour: startHour,
        endHour: endHour,
      );
    } else {
      await backend!.savePolicy(
        AttendancePolicy(
          mode: mode,
          startHour: startHour,
          endHour: endHour,
          timezone: _timezone,
        ),
      );
    }
    await loadWindowConfig();
  }

  Future<AttendanceRecord> submitPhoto({
    required String requestId,
    required String base64Image,
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime capturedAt,
  }) async {
    if (backend == null) {
      throw const CompanyException('Company connection unavailable.');
    }
    if (isPreview) throw PreviewUnavailable();
    final record = await backend!.submit(
      requestId: requestId,
      base64Image: base64Image,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      capturedAt: capturedAt,
      installationId: await _deviceService.getDeviceId(),
      deviceModel: _deviceModel,
      platform: Platform.isIOS ? 'ios' : 'android',
    );
    _isCheckedIn = true;
    _checkInTime =
        '${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}';
    notifyListeners();
    return record;
  }

  String newRequestId() => const Uuid().v4();

  Future<bool> attemptCheckIn(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
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

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class PreviewUnavailable extends CompanyException {
  PreviewUnavailable()
    : super('Read-only preview. Request an invitation to submit attendance.');
}
