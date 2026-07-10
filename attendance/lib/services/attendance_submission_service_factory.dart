import 'attendance_submission_service.dart';
import 'public_attendance_submission_service.dart';

AttendanceSubmissionService _attendanceSubmissionService =
    PublicAttendanceSubmissionService();

AttendanceSubmissionService get attendanceSubmissionService =>
    _attendanceSubmissionService;

void configureAttendanceSubmissionService(AttendanceSubmissionService service) {
  _attendanceSubmissionService = service;
}
