import 'dart:typed_data';

import '../models/attendance_record_model.dart';
import '../models/employees_model.dart';

class CompanyException implements Exception {
  const CompanyException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A confirmed loss of session or active company membership.
class CompanyAccessException extends CompanyException {
  const CompanyAccessException(super.message);
}

class AttendancePolicy {
  const AttendancePolicy({
    this.mode = 'period',
    this.startHour = 7,
    this.endHour = 13,
    this.timezone = 'Asia/Karachi',
  });
  final String mode;
  final int startHour;
  final int endHour;
  final String timezone;
}

/// Company integrations are injected; the private entrypoint keeps legacy services.
abstract class CompanyBackend {
  bool get isPreview => false;
  bool get isConfigured => true;
  bool get needsPasswordSetup => false;
  Stream<void> get authChanges => const Stream.empty();
  DateTime get companyNow => DateTime.now();

  /// Restores an active member, or returns `null` when no session exists.
  ///
  /// Throws [CompanyAccessException] for confirmed access loss, not outages.
  Future<Employee?> restoreSession();
  Future<Employee> signIn(String email, String password);
  Future<void> signOut();
  Future<Employee> updateProfile({
    String? name,
    String? headline,
    List<String>? chips,
  });
  Future<void> resetPassword(String email);
  Future<void> setPassword(String password);
  Future<void> changeEmail(String email);
  Future<List<Employee>> employees();
  Future<List<AttendanceRecord>> history({
    String? employeeId,
    bool todayOnly = false,
  });
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
  });
  Future<AttendancePolicy> policy();
  Future<void> savePolicy(AttendancePolicy policy);
  Future<Map<String, String?>> profileMedia();
  Future<void> saveMedia(String kind, Uint8List? bytes);
  Future<void> invite({
    required String email,
    required String name,
    required String employeeCode,
    required String department,
  });
  Future<void> setEmployeeActive(String employeeId, bool active);
  Future<Map<String, dynamic>> evidence(String recordId);
}
