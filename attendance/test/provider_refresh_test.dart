import 'dart:async';
import 'dart:typed_data';

import 'package:attendance/models/attendance_record_model.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/admin_provider.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/services/attendance_service.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/services/employees_service.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _flush() => Future<void>.delayed(Duration.zero);

AttendanceRecord _record(String id, {String user = 'EMP001'}) =>
    AttendanceRecord(
      id: id,
      userId: user,
      isPresent: true,
      timestamp: DateTime(2026, 11, 15, 9),
      device: 'Test phone',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'concurrent profile reads share one future and failures can retry',
    () async {
      final backend = _Backend();
      final profile = ProfileProvider(backend: backend);
      addTearDown(profile.dispose);
      final first = profile.loadProfileData('EMP001');
      expect(profile.loadProfileData('EMP001'), same(first));
      await _flush();
      expect(backend.media.length, 1);
      backend.media[0].complete({'avatar': 'old.png', 'banner': 'banner.gif'});
      await first;
      final failed = profile.loadProfileData('EMP001');
      await _flush();
      backend.media[1].completeError(const CompanyException('Offline'));
      await failed;
      expect(profile.pfpPath, 'old.png');
      final retry = profile.loadProfileData('EMP001');
      await _flush();
      backend.media[2].complete({'avatar': 'new.gif'});
      await retry;
      expect(profile.pfpPath, 'new.gif');
    },
  );

  test('a fresh post-mutation profile read wins over an older read', () async {
    final backend = _Backend();
    final profile = ProfileProvider(backend: backend);
    addTearDown(profile.dispose);
    final old = profile.loadProfileData('EMP001');
    await _flush();
    final removal = profile.removeBanner('EMP001');
    await _flush();
    expect(backend.media.length, 2);
    backend.media[1].complete({'avatar': 'new.png', 'banner': null});
    await removal;
    backend.media[0].complete({'avatar': 'old.png', 'banner': 'old.gif'});
    await old;
    expect(profile.pfpPath, 'new.png');
    expect(profile.bannerPath, isNull);
  });

  test('cleared profile state cannot be restored by a late response', () async {
    final backend = _Backend();
    final profile = ProfileProvider(backend: backend);
    addTearDown(profile.dispose);
    final old = profile.loadProfileData('EMP001');
    await _flush();
    await profile.clearProfileData();
    final next = profile.loadProfileData('EMP002');
    await _flush();
    backend.media[0].complete({'avatar': 'private-old.png'});
    await old;
    expect(profile.pfpPath, isNull);
    expect(profile.loadProfileData('EMP002'), same(next));
    backend.media[1].complete({'avatar': 'current.png'});
    await next;
    expect(profile.pfpPath, 'current.png');
  });

  test(
    'history refreshes coalesce even when forced and retain cache semantics',
    () async {
      final backend = _Backend();
      final history = AttendanceHistoryProvider(
        service: AttendanceService(backend: backend),
      );
      addTearDown(history.dispose);
      final first = history.loadHistory('EMP001');
      expect(history.loadHistory('EMP001', force: true), same(first));
      await _flush();
      expect(backend.records.length, 1);
      backend.records[0].complete([_record('first')]);
      await first;
      await history.loadHistory('EMP001');
      expect(backend.records.length, 1);
      final refresh = history.loadHistory('EMP001', force: true);
      await _flush();
      backend.records[1].complete([_record('latest')]);
      await refresh;
      expect(history.records.single.id, 'latest');
    },
  );

  test(
    'a previous user read cannot clear or replace the next user refresh',
    () async {
      final backend = _Backend();
      final history = AttendanceHistoryProvider(
        service: AttendanceService(backend: backend),
      );
      addTearDown(history.dispose);
      final old = history.loadHistory('EMP001');
      await _flush();
      final next = history.loadHistory('EMP002');
      await _flush();
      backend.records[0].complete([_record('old')]);
      await old;
      expect(history.isLoading, isTrue);
      expect(history.records, isEmpty);
      expect(history.loadHistory('EMP002'), same(next));
      backend.records[1].complete([_record('next', user: 'EMP002')]);
      await next;
      expect(history.records.single.userId, 'EMP002');
    },
  );

  test(
    'accepted check-in retires old reads and permits a fresh request',
    () async {
      final backend = _Backend();
      final history = AttendanceHistoryProvider(
        service: AttendanceService(backend: backend),
      );
      addTearDown(history.dispose);
      final old = history.loadHistory('EMP001');
      await _flush();
      final saved = _record('saved');
      history.acceptSubmittedRecord(saved);
      final fresh = history.loadHistory('EMP001', force: true);
      await _flush();
      backend.records[0].complete([]);
      await old;
      expect(history.records.single.id, 'saved');
      expect(history.isLoading, isTrue);
      expect(history.loadHistory('EMP001'), same(fresh));
      backend.records[1].complete([saved]);
      await fresh;
      expect(history.records.single.id, 'saved');
      expect(history.isLoading, isFalse);
    },
  );

  test('a failed history refresh retains records and allows retry', () async {
    final backend = _Backend();
    final history = AttendanceHistoryProvider(
      service: AttendanceService(backend: backend),
    );
    addTearDown(history.dispose);
    history.acceptSubmittedRecord(_record('saved'));
    final failed = history.loadHistory('EMP001', force: true);
    await _flush();
    backend.records[0].completeError(const CompanyException('Offline'));
    await failed;
    expect(history.records.single.id, 'saved');
    expect(history.error, isNotNull);
    final retry = history.loadHistory('EMP001', force: true);
    await _flush();
    backend.records[1].complete([_record('fresh')]);
    await retry;
    expect(history.error, isNull);
    expect(history.records.single.id, 'fresh');
  });

  test(
    'dashboard loads share requests, including a synchronous listener',
    () async {
      final backend = _Backend();
      final admin = AdminProvider(
        attendanceService: AttendanceService(backend: backend),
        employeeService: EmployeeService(backend: backend),
      );
      addTearDown(admin.dispose);
      Future<void>? fromListener;
      admin.addListener(() {
        if (admin.isLoading) fromListener ??= admin.loadDashboard();
      });
      final first = admin.loadDashboard();
      expect(fromListener, same(first));
      expect(admin.loadDashboard(), same(first));
      await _flush();
      expect(backend.staff.length, 1);
      expect(backend.records.length, 1);
      backend.staff[0].complete([]);
      backend.records[0].complete([]);
      await first;
      expect(admin.isLoading, isFalse);
      final retry = admin.loadDashboard();
      await _flush();
      backend.staff[1].completeError(const CompanyException('Offline'));
      backend.records[1].complete([]);
      await retry;
      expect(admin.error, isNotNull);
      final fresh = admin.loadDashboard();
      await _flush();
      backend.staff[2].complete([]);
      backend.records[2].complete([]);
      await fresh;
      expect(admin.error, isNull);
    },
  );

  test(
    'disposed providers ignore pending reads without notifying listeners',
    () async {
      final backend = _Backend();
      final profile = ProfileProvider(backend: backend);
      final admin = AdminProvider(
        attendanceService: AttendanceService(backend: backend),
        employeeService: EmployeeService(backend: backend),
      );
      final media = profile.loadProfileData('EMP001');
      final dashboard = admin.loadDashboard();
      await _flush();
      profile.dispose();
      admin.dispose();
      backend.media[0].complete({'avatar': 'old.png'});
      backend.staff[0].complete([]);
      backend.records[0].complete([]);
      await Future.wait([media, dashboard]);
      expect(profile.pfpPath, isNull);
      expect(admin.totalEmployees, 0);
    },
  );
}

class _Backend extends PreviewCompanyBackend {
  final media = <Completer<Map<String, String?>>>[];
  final staff = <Completer<List<Employee>>>[];
  final records = <Completer<List<AttendanceRecord>>>[];
  @override
  bool get isPreview => false;
  @override
  Future<Map<String, String?>> profileMedia() {
    final pending = Completer<Map<String, String?>>();
    media.add(pending);
    return pending.future;
  }

  @override
  Future<List<Employee>> employees() {
    final pending = Completer<List<Employee>>();
    staff.add(pending);
    return pending.future;
  }

  @override
  Future<List<AttendanceRecord>> history({
    String? employeeId,
    bool todayOnly = false,
  }) {
    final pending = Completer<List<AttendanceRecord>>();
    records.add(pending);
    return pending.future;
  }

  @override
  Future<void> saveMedia(String kind, Uint8List? bytes) async {}
}
