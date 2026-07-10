import 'attendance_submission_service.dart';
import 'mobile_attendance_service.dart';

AttendanceSubmissionService _attendanceSubmissionService =
    MobileAttendanceService.fromEnvironment();

AttendanceSubmissionService get attendanceSubmissionService =>
    _attendanceSubmissionService;

void configureAttendanceSubmissionService(AttendanceSubmissionService service) {
  _attendanceSubmissionService = service;
}
