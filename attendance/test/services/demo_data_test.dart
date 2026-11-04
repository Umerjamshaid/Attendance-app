import 'package:attendance/services/attendance_service.dart';
import 'package:attendance/services/employees_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sample attendance records are identified as demo data', () async {
    final service = AttendanceService();

    expect(service.isDemoMode, isTrue);
    expect(
      (await service.getUserAttendance('EMP001')).map((record) => record.id),
      containsAll(['1', '2']),
    );
    expect(
      (await service.getTodayAllAttendance()).map((record) => record.userId),
      containsAll(['EMP001', 'EMP002']),
    );
  });

  test('sample employees are identified as demo data', () async {
    final service = EmployeeService();

    expect(service.isDemoMode, isTrue);
    expect((await service.getAllEmployees()).map((employee) => employee.id), [
      'EMP001',
      'EMP002',
      'EMP003',
    ]);
  });
}
