abstract class AttendanceSubmissionService {
  bool get isAvailable;

  String get unavailableMessage;

  Future<void> submit({
    required String employeeId,
    required double latitude,
    required double longitude,
    required String base64Image,
    DateTime? attendanceDateTime,
  });
}
