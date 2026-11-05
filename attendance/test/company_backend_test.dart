import 'dart:async';
import 'dart:io';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/models/attendance_record_model.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/services/attendance_service.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'preview reads samples without network or persistent account writes',
    () async {
      await HttpOverrides.runZoned(
        () async {
          final backend = PreviewCompanyBackend();
          final employee = (await backend.restoreSession())!;
          expect(employee.id, 'DEMO001');
          expect((await backend.history(employeeId: employee.id)).length, 8);
          expect((await backend.policy()).mode, 'always');
          expect(await backend.profileMedia(), isEmpty);
          await expectLater(
            backend.updateProfile(name: 'Changed'),
            throwsA(isA<CompanyException>()),
          );
          await expectLater(
            backend.invite(
              email: 'x@example.com',
              name: 'x',
              employeeCode: 'X',
              department: 'x',
            ),
            throwsA(isA<CompanyException>()),
          );
          final attendance = AttendanceProvider(backend: backend);
          await expectLater(
            attendance.submitPhoto(
              requestId: 'x',
              base64Image: '',
              latitude: 0,
              longitude: 0,
              accuracy: 0,
              capturedAt: DateTime.now(),
            ),
            throwsA(isA<CompanyException>()),
          );
          attendance.dispose();
          expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
        },
        createHttpClient: (_) =>
            throw StateError('Preview attempted network access'),
      );
    },
  );
  test(
    'public preview can exit without touching private login preferences',
    () async {
      SharedPreferences.setMockInitialValues({'userId': 'EMP001'});
      final auth = AuthProvider(
        backend: PreviewCompanyBackend(available: false),
      );
      await Future<void>.delayed(Duration.zero);
      expect(auth.isAuthenticated, false);
      await auth.enterPreview();
      expect(auth.isPreview, true);
      expect(auth.currentUser!.id, 'DEMO001');
      await auth.logout();
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.isPreview, false);
      expect(
        (await SharedPreferences.getInstance()).getString('userId'),
        'EMP001',
      );
      auth.dispose();
    },
  );
  test(
    'saved check-in wins over a stale history request, without a second write',
    () async {
      final backend = _ControlledBackend();
      final history = AttendanceHistoryProvider(
        service: AttendanceService(backend: backend),
      );
      final pending = history.loadHistory('DEMO001');
      final record = AttendanceRecord(
        id: 'server-id',
        userId: 'DEMO001',
        isPresent: true,
        timestamp: DateTime.now(),
        device: 'Phone',
      );
      history.acceptSubmittedRecord(record);
      backend.records.complete([]);
      await pending;
      expect(history.records.single.id, 'server-id');
      history.acceptSubmittedRecord(record);
      expect(history.records.length, 1);
      expect(history.isLoading, false);
      history.dispose();
    },
  );
  test('public day counts do not inflate when someone uploads repeatedly', () {
    final history = AttendanceHistoryProvider(
      service: AttendanceService(backend: PreviewCompanyBackend()),
    );
    for (var i = 0; i < 3; i++) {
      history.acceptSubmittedRecord(
        AttendanceRecord(
          id: '$i',
          userId: 'DEMO001',
          isPresent: true,
          timestamp: DateTime.now(),
          device: 'Phone',
        ),
      );
    }
    expect(history.totalCount, 3);
    expect(history.presentCount, 1);
    expect(history.presentThisMonthCount, 1);
    history.dispose();
  });
  test(
    'session restore failure is recoverable and never authenticates a demo employee',
    () async {
      final auth = AuthProvider(backend: _BrokenBackend());
      await Future<void>.delayed(Duration.zero);
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.currentUser, isNull);
      expect(auth.error, contains('Connection failed'));
      await auth.enterPreview();
      expect(auth.isPreview, true);
      auth.dispose();
    },
  );
  test('a transient refresh failure preserves a loaded account', () async {
    final backend = _SessionBackend();
    final auth = AuthProvider(backend: backend);
    await Future<void>.delayed(Duration.zero);
    final employee = auth.currentUser;
    expect(employee, isNotNull);
    backend.failure = const CompanyException('Connection failed');
    await auth.refreshSession();
    expect(auth.status, AuthStatus.authenticated);
    expect(auth.currentUser, same(employee));
    expect(auth.error, 'Connection failed');
    backend.failure = null;
    await auth.refreshSession();
    expect(auth.isAuthenticated, true);
    expect(auth.error, isNull);
    auth.dispose();
  });
  test(
    'confirmed inactive access clears a previously loaded account',
    () async {
      final backend = _SessionBackend();
      final auth = AuthProvider(backend: backend);
      await Future<void>.delayed(Duration.zero);
      backend.failure = const CompanyAccessException(
        'Company access is inactive',
      );
      await auth.refreshSession();
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.currentUser, isNull);
      expect(auth.error, 'Company access is inactive');
      auth.dispose();
    },
  );
  test('a missing session clears a previously loaded account', () async {
    final backend = _SessionBackend();
    final auth = AuthProvider(backend: backend);
    await Future<void>.delayed(Duration.zero);
    expect(auth.isAuthenticated, true);
    backend.hasSession = false;
    await auth.refreshSession();
    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.currentUser, isNull);
    auth.dispose();
  });
}

class _SessionBackend extends PreviewCompanyBackend {
  Exception? failure;
  bool hasSession = true;
  @override
  Future<Employee?> restoreSession() async {
    if (failure != null) throw failure!;
    return hasSession ? super.restoreSession() : null;
  }
}

class _ControlledBackend extends PreviewCompanyBackend {
  final records = Completer<List<AttendanceRecord>>();
  @override
  Future<List<AttendanceRecord>> history({
    String? employeeId,
    bool todayOnly = false,
  }) => records.future;
}

class _BrokenBackend extends PreviewCompanyBackend {
  @override
  bool get isPreview => false;
  @override
  Future<Never> restoreSession() async =>
      throw const CompanyException('Connection failed');
}
