import 'dart:async';
import 'dart:io';
import 'package:attendance/models/attendance_record_model.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/models/office_model.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/office_provider.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/services/attendance_service.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ControlledOfficeBackend extends PreviewCompanyBackend {
  ControlledOfficeBackend({OfficeTestState? state, this.boundOffice})
    : state = state ?? OfficeTestState();
  final OfficeTestState state;
  final String? boundOffice;
  @override
  bool get isPreview => false;
  @override
  CompanyBackend forOffice(Employee employee) => ControlledOfficeBackend(
    state: state,
    boundOffice: employee.organizationId,
  );
  Employee employee(String id) => Employee(
    id: 'SAME_CODE',
    authUserId: state.authUserId,
    organizationId: id,
    officeName: id == 'a' ? 'Office A' : 'Office B',
    name: 'Global profile',
    email: 'test@example.invalid',
    role: id == 'a' ? 'admin' : 'employee',
    department: 'Engineering',
    time: '',
  );
  @override
  Future<Employee?> restoreSession() async =>
      state.signedIn ? employee(state.active) : null;
  @override
  Future<List<Office>> offices() async => [
    const Office(id: 'a', name: 'Office A', role: 'admin'),
    if (!state.revoked)
      const Office(id: 'b', name: 'Office B', role: 'employee'),
  ];
  @override
  Future<Employee> switchOffice(String officeId) async {
    state.switchCalls++;
    if (state.switchGate != null) await state.switchGate!.future;
    if (state.failSwitch) throw const CompanyException('Offline');
    if (officeId != 'a' && officeId != 'b' ||
        officeId == 'b' && state.revoked) {
      throw const CompanyException('inactive');
    }
    state.active = officeId;
    return employee(officeId);
  }

  @override
  Future<String> createOffice(String name) async => 'b';
  @override
  Future<List<AttendanceRecord>> history({
    String? employeeId,
    bool todayOnly = false,
  }) async {
    final id = boundOffice ?? state.active;
    if (id == 'a' && state.historyGate != null) await state.historyGate!.future;
    validateContext();
    return [
      AttendanceRecord(
        id: 'record-$id',
        userId: 'SAME_CODE',
        isPresent: true,
        timestamp: DateTime.now(),
        device: 'Device $id',
      ),
    ];
  }

  @override
  void validateContext() {
    if (boundOffice != null && boundOffice != state.active) {
      throw const CompanyException('Office changed');
    }
  }

  @override
  Future<void> signOut() async {
    state.signedIn = false;
  }
}

class OfficeTestState {
  String authUserId = 'account-1';
  String active = 'a';
  bool signedIn = true, revoked = false, failSwitch = false;
  int switchCalls = 0;
  Completer<void>? switchGate, historyGate;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'hiding an office is account-scoped appearance only and can be restored',
    () async {
      final backend = ControlledOfficeBackend();
      final auth = AuthProvider(backend: backend);
      await Future<void>.delayed(Duration.zero);
      var offices = OfficeProvider(auth);
      await offices.reload();
      expect(await offices.hideOffice('b'), isTrue);
      expect(offices.offices.map((office) => office.id), ['a']);
      expect(offices.hiddenOffices.single.id, 'b');
      expect((await backend.offices()).length, 2);
      expect(
        backend.state.switchCalls,
        0,
        reason:
            'inactive office visibility does not switch or revoke a membership',
      );
      offices.dispose();
      offices = OfficeProvider(auth);
      await offices.reload();
      expect(
        offices.hiddenOffices.single.id,
        'b',
        reason: 'visibility survives reopening',
      );
      expect(await offices.restoreOffice('b'), isTrue);
      expect(offices.offices.length, 2);
      expect(offices.hiddenOffices, isEmpty);
      expect(await offices.hideOffice('b'), isTrue);
      offices.dispose();
      auth.dispose();
      final otherBackend = ControlledOfficeBackend(
        state: OfficeTestState()..authUserId = 'account-2',
      );
      final otherAuth = AuthProvider(backend: otherBackend);
      await Future<void>.delayed(Duration.zero);
      final other = OfficeProvider(otherAuth);
      await other.reload();
      expect(
        other.offices.length,
        2,
        reason: 'another account does not inherit hidden offices',
      );
      other.dispose();
      otherAuth.dispose();
    },
  );

  test(
    'hiding the active office reauthorizes a fallback and keeps one visible office',
    () async {
      final backend = ControlledOfficeBackend();
      final auth = AuthProvider(backend: backend);
      await Future<void>.delayed(Duration.zero);
      final offices = OfficeProvider(auth);
      await offices.reload();
      backend.state.failSwitch = true;
      expect(await offices.hideOffice('a'), isFalse);
      expect(offices.hiddenOffices, isEmpty);
      expect(offices.activeOfficeId, 'a');
      backend.state.failSwitch = false;
      expect(await offices.hideOffice('a'), isTrue);
      expect(offices.activeOfficeId, 'b');
      expect(offices.offices.single.id, 'b');
      expect(offices.hiddenOffices.single.id, 'a');
      expect(await offices.hideOffice('b'), isFalse);
      expect(offices.error, contains('Keep one office visible'));
      expect((await backend.offices()).length, 2);
      offices.dispose();
      auth.dispose();
    },
  );

  test(
    'Preview switcher visibility never writes preferences or company data',
    () async {
      final auth = AuthProvider(
        backend: PreviewCompanyBackend(available: false),
      );
      await Future<void>.delayed(Duration.zero);
      await auth.enterPreview();
      final offices = OfficeProvider(auth);
      await offices.reload();
      expect(await offices.hideOffice('preview-hub'), isTrue);
      expect(offices.hiddenOffices.single.id, 'preview-hub');
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      offices.dispose();
      auth.dispose();
    },
  );

  test(
    'office switch preserves account, changes office role and invalidates scope keys',
    () async {
      final backend = ControlledOfficeBackend();
      final auth = AuthProvider(backend: backend);
      await Future<void>.delayed(Duration.zero);
      final offices = OfficeProvider(auth);
      await offices.reload();
      final accountKey = auth.accountScopeKey;
      final officeKey = auth.officeScopeKey;
      final accountBackend = auth.accountBackend;
      final oldScope = auth.backend!;
      expect(await offices.switchOffice('b'), isTrue);
      expect(auth.currentUser!.isAdmin, isFalse);
      expect(auth.currentUser!.organizationId, 'b');
      expect(auth.currentUser!.name, 'Global profile');
      expect(offices.activeOffice!.name, 'Office B');
      expect(auth.accountScopeKey, accountKey);
      expect(auth.accountBackend, same(accountBackend));
      expect(auth.officeScopeKey, isNot(officeKey));
      expect(oldScope.validateContext, throwsA(isA<CompanyException>()));
      offices.dispose();
      auth.dispose();
    },
  );

  test('unauthorized and revoked offices cannot be selected', () async {
    final backend = ControlledOfficeBackend();
    final auth = AuthProvider(backend: backend);
    await Future<void>.delayed(Duration.zero);
    final offices = OfficeProvider(auth);
    await offices.reload();
    expect(await offices.switchOffice('unrelated'), isFalse);
    expect(backend.state.switchCalls, 0);
    backend.state.revoked = true;
    expect(
      await offices.switchOffice('b'),
      isFalse,
      reason: 'server rejects even a stale locally visible membership',
    );
    expect(offices.activeOfficeId, 'a');
    expect(offices.error, contains('inactive'));
    offices.dispose();
    auth.dispose();
  });

  test(
    'switching is single-flight; failures preserve the selected account and office',
    () async {
      final backend = ControlledOfficeBackend();
      final auth = AuthProvider(backend: backend);
      await Future<void>.delayed(Duration.zero);
      final offices = OfficeProvider(auth);
      await offices.reload();
      backend.state.switchGate = Completer<void>();
      backend.state.failSwitch = true;
      final pending = offices.switchOffice('b');
      expect(offices.isSwitching, isTrue);
      expect(await offices.switchOffice('a'), isFalse);
      backend.state.switchGate!.complete();
      expect(await pending, isFalse);
      expect(backend.state.switchCalls, 1);
      expect(auth.isAuthenticated, isTrue);
      expect(offices.activeOfficeId, 'a');
      expect(offices.error, 'Offline');
      expect(offices.isSwitching, isFalse);
      offices.dispose();
      auth.dispose();
    },
  );

  test(
    'late old-office history cannot overwrite new-office records with the same employee code',
    () async {
      final backend = ControlledOfficeBackend();
      final auth = AuthProvider(backend: backend);
      await Future<void>.delayed(Duration.zero);
      backend.state.historyGate = Completer<void>();
      final old = AttendanceHistoryProvider(
        service: AttendanceService(backend: auth.backend),
      );
      final pending = old.loadHistory('SAME_CODE');
      await auth.switchOffice('b');
      old.dispose();
      final next = AttendanceHistoryProvider(
        service: AttendanceService(backend: auth.backend),
      );
      expect(next.records, isEmpty);
      await next.loadHistory('SAME_CODE');
      backend.state.historyGate!.complete();
      await pending;
      expect(old.records, isEmpty);
      expect(next.records.single.id, 'record-b');
      next.dispose();
      auth.dispose();
    },
  );

  test(
    'logout during a pending switch cannot resurrect an authenticated session',
    () async {
      final backend = ControlledOfficeBackend();
      final auth = AuthProvider(backend: backend);
      await Future<void>.delayed(Duration.zero);
      backend.state.switchGate = Completer<void>();
      final pending = auth.switchOffice('b');
      await auth.logout();
      backend.state.switchGate!.complete();
      await pending;
      expect(auth.currentUser, isNull);
      expect(auth.status, AuthStatus.unauthenticated);
      auth.dispose();
    },
  );

  test(
    'preview office switching stays entirely in memory with read-only writes',
    () async {
      await HttpOverrides.runZoned(
        () async {
          final backend = PreviewCompanyBackend();
          final first = (await backend.restoreSession())!;
          final old = backend.forOffice(first);
          final next = await backend.switchOffice('preview-hub');
          expect(next.officeName, 'City Hub');
          expect(
            (await backend.forOffice(next).history()).first.id,
            contains('preview-hub'),
          );
          expect(old.validateContext, throwsA(isA<CompanyException>()));
          await expectLater(
            backend.createOffice('Company'),
            throwsA(isA<CompanyException>()),
          );
          expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
        },
        createHttpClient: (_) => throw StateError('Preview attempted network'),
      );
    },
  );
}
