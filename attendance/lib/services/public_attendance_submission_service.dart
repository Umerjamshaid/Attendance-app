import 'attendance_submission_service.dart';

class PublicAttendanceSubmissionService implements AttendanceSubmissionService {
  @override
  bool get isAvailable => false;

  @override
  String get unavailableMessage => 'Upload unavailable';

  @override
  Future<void> submit({
    required String employeeId,
    required double latitude,
    required double longitude,
    required String base64Image,
    DateTime? attendanceDateTime,
  }) async {
    throw Exception(unavailableMessage);
  }
}
