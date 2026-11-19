import 'dart:async';

import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/models/office_check_in_activity.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/screens/admin/admin_notification_screen.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('loads, refreshes to empty, and retries a failed read', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 560);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final backend = _ActivityBackend();
    await _mount(tester, backend);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final first = _checkIn('first', 'Alex Morgan');
    backend.requests.single.complete([first]);
    await tester.pumpAndSettle();
    expect(_entry('Alex Morgan'), findsOneWidget);
    expect(find.text(DateFormat.jm().format(first.receivedAt)), findsOneWidget);

    await _pullToRefresh(tester);
    backend.requests[1].complete([]);
    await tester.pumpAndSettle();
    expect(find.text('No check-ins yet'), findsOneWidget);
    expect(_entry('Alex Morgan'), findsNothing);

    await _pullToRefresh(tester);
    backend.requests[2].completeError(const CompanyException('Offline'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load check-ins'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    backend.requests[3].complete([_checkIn('second', 'Sam Rivera')]);
    await tester.pumpAndSettle();
    expect(_entry('Sam Rivera'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('office change clears rows and ignores a stale refresh', (
    tester,
  ) async {
    final backend = _ActivityBackend();
    final auth = await _mount(tester, backend);
    backend.requests.single.complete([_checkIn('old', 'Old office')]);
    await tester.pumpAndSettle();
    expect(_entry('Old office'), findsOneWidget);
    await _pullToRefresh(tester);

    backend.user = backend.user!.copyWith(organizationId: 'office-b');
    await auth.refreshSession();
    await tester.pump();
    expect(_entry('Old office'), findsNothing);
    backend.requests[2].complete([_checkIn('new', 'New office')]);
    await tester.pumpAndSettle();
    backend.requests[1].complete([_checkIn('stale', 'Stale office')]);
    await tester.pumpAndSettle();
    expect(_entry('New office'), findsOneWidget);
    expect(_entry('Stale office'), findsNothing);
  });

  testWidgets(
    'a refused read clears the list; deactivated access stops reads',
    (tester) async {
      final backend = _ActivityBackend();
      final auth = await _mount(tester, backend);
      backend.requests.single.complete([_checkIn('old', 'Previous row')]);
      await tester.pumpAndSettle();
      await _pullToRefresh(tester);
      backend.requests[1].completeError(
        const CompanyAccessException(
          'Check-in activity is only available to active office admins.',
        ),
      );
      await tester.pumpAndSettle();
      expect(_entry('Previous row'), findsNothing);
      expect(find.textContaining('active office admins'), findsOneWidget);

      backend.user = null;
      await auth.refreshSession();
      await tester.pumpAndSettle();
      expect(find.text('Check-in activity unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(backend.requests, hasLength(2));
    },
  );

  testWidgets('employees never request the admin feed', (tester) async {
    final backend = _ActivityBackend();
    backend.user = backend.user!.copyWith(role: 'employee');
    await _mount(tester, backend);
    expect(find.text('Check-in activity unavailable'), findsOneWidget);
    expect(backend.requests, isEmpty);
  });

  test('the preview supplies fictional rows without live access', () async {
    final rows = await PreviewCompanyBackend().checkInActivity();
    expect(rows.map((row) => row.employeeName), ['Alex Morgan', 'Sam Rivera']);
    expect(rows.first.receivedAt.isAfter(rows.last.receivedAt), isTrue);
    await expectLater(
      PreviewCompanyBackend(available: false).checkInActivity(),
      throwsA(isA<CompanyException>()),
    );
  });
}

Finder _entry(String name) => find.text('$name checked in', findRichText: true);

Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, 440));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

OfficeCheckInActivity _checkIn(String id, String employee) =>
    OfficeCheckInActivity(
      id: id,
      employeeName: employee,
      receivedAt: DateTime(2026, 11, 19, 9, 10),
    );

Future<AuthProvider> _mount(
  WidgetTester tester,
  _ActivityBackend backend,
) async {
  final auth = AuthProvider(backend: backend);
  addTearDown(auth.dispose);
  await auth.refreshSession();
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: auth,
      child: MaterialApp(
        theme: AppTheme.theme,
        home: const AdminNotificationScreen(),
      ),
    ),
  );
  await tester.pump();
  return auth;
}

class _ActivityBackend extends PreviewCompanyBackend {
  final requests = <Completer<List<OfficeCheckInActivity>>>[];
  Employee? user = Employee(
    id: 'ADMIN001',
    name: 'Test Admin',
    email: 'admin@example.invalid',
    department: 'Operations',
    role: 'admin',
    time: '',
    authUserId: 'admin',
    organizationId: 'office-a',
  );

  @override
  bool get isPreview => false;

  @override
  Future<Employee?> restoreSession() async => user;

  @override
  CompanyBackend forOffice(Employee employee) => this;

  @override
  Future<List<OfficeCheckInActivity>> checkInActivity() {
    final request = Completer<List<OfficeCheckInActivity>>();
    requests.add(request);
    return request.future;
  }
}
