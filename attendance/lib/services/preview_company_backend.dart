import 'dart:typed_data';

import '../models/attendance_record_model.dart';
import '../models/employees_model.dart';
import '../models/office_model.dart';
import 'company_backend.dart';

/// No network client, persistent writes, camera, or location access in previews.
class _PreviewOffices {
  String active = 'preview-studio';
}

class PreviewCompanyBackend extends CompanyBackend {
  PreviewCompanyBackend({this.available = true}) : _offices = _PreviewOffices();
  PreviewCompanyBackend._scoped(this.available, this._offices, this._officeId);
  final bool available;
  final _PreviewOffices _offices;
  String? _officeId;
  @override
  bool get supportsOffices => available;
  @override
  CompanyBackend forOffice(Employee employee) => PreviewCompanyBackend._scoped(
    available,
    _offices,
    employee.organizationId,
  );
  @override
  Future<List<Office>> offices() async => available
      ? const [
          Office(id: 'preview-studio', name: 'Design Studio', role: 'employee'),
          Office(id: 'preview-hub', name: 'City Hub', role: 'employee'),
        ]
      : [];
  @override
  Future<Employee> switchOffice(String officeId) async {
    if (!(await offices()).any((office) => office.id == officeId)) {
      throw readOnly;
    }
    _offices.active = officeId;
    return _employee;
  }

  @override
  void validateContext() {
    if (_officeId != null && _officeId != _offices.active) {
      throw const CompanyException('The preview office changed.');
    }
  }

  @override
  bool get isPreview => available;
  @override
  bool get isConfigured => available;

  static const unavailable = CompanyException(
    'Company sign-in is not configured in this build.',
  );
  static const readOnly = CompanyException(
    'This is a read-only preview. Request an invitation for a real trial.',
  );

  Employee get _employee => Employee(
    authUserId: 'preview-user',
    organizationId: _officeId ?? _offices.active,
    officeName: (_officeId ?? _offices.active) == 'preview-studio'
        ? 'Design Studio'
        : 'City Hub',
    id: 'DEMO001',
    name: 'Alex Morgan',
    email: 'alex@example.com',
    role: 'employee',
    department: 'Product',
    time: '',
    headline: 'Building a better workday',
    chips: ['Teamwork', 'Design'],
  );
  @override
  Future<Employee?> restoreSession() async => available ? _employee : null;
  @override
  Future<Employee> signIn(String email, String password) async =>
      throw unavailable;
  @override
  Future<void> signOut() async {}
  @override
  Future<List<Employee>> employees() async => available ? [_employee] : [];
  @override
  Future<List<AttendanceRecord>> history({
    String? employeeId,
    bool todayOnly = false,
  }) async {
    if (!available) return [];
    final now = DateTime.now();
    return [
      for (var i = 0; i < (todayOnly ? 1 : 8); i++)
        AttendanceRecord(
          id: 'preview-${_officeId ?? _offices.active}-$i',
          userId: _employee.id,
          isPresent: true,
          timestamp: DateTime(now.year, now.month, now.day - i, 9, 5),
          device: 'Sample Android device',
        ),
    ];
  }

  @override
  Future<AttendancePolicy> policy() async =>
      const AttendancePolicy(mode: 'always');
  @override
  Future<Map<String, String?>> profileMedia() async => {};
  @override
  Future<Employee> updateProfile({
    String? name,
    String? headline,
    List<String>? chips,
  }) async => throw readOnly;
  @override
  Future<void> resetPassword(String email) async => throw unavailable;
  @override
  Future<void> setPassword(String password) async => throw unavailable;
  @override
  Future<void> changeEmail(String email) async => throw readOnly;
  @override
  Future<void> savePolicy(AttendancePolicy policy) async => throw readOnly;
  @override
  Future<void> saveMedia(String kind, Uint8List? bytes) async => throw readOnly;
  @override
  Future<void> invite({
    required String email,
    required String name,
    required String employeeCode,
    required String department,
  }) async => throw readOnly;
  @override
  Future<void> setEmployeeActive(String employeeId, bool active) async =>
      throw readOnly;
  @override
  Future<Map<String, dynamic>> evidence(String recordId) async =>
      throw readOnly;
  @override
  Future<AttendanceRecord> submit({
    required String requestId,
    required String base64Image,
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime capturedAt,
    required String installationId,
    required String deviceModel,
    required String platform,
  }) async => throw readOnly;
}
