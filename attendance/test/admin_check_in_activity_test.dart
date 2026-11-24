import 'dart:async';

import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/models/office_check_in_activity.dart';
import 'package:attendance/providers/admin_activity_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/screens/admin/admin_notification_screen.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
    'read markers are persisted per office, including tied timestamps',
    (tester) async {
      final backend = _ActivityBackend();
      final auth = await _mount(tester, backend);
      final marked = _checkIn('b', 'Known check-in');
      backend.requests.single.complete([
        marked,
        OfficeCheckInActivity(
          id: 'a',
          employeeName: 'Earlier check-in',
          receivedAt: marked.receivedAt.subtract(const Duration(days: 1)),
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Earlier'), findsOneWidget);
      final action = find.byTooltip('Mark all as read');
      expect(action, findsOneWidget);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(action, findsNothing);
      await tester.tap(find.text('Unread'));
      await tester.pumpAndSettle();
      expect(find.text('You’re caught up'), findsOneWidget);
      expect(_entry('Known check-in'), findsNothing);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(_entry('Known check-in'), findsOneWidget);

      backend.user = backend.user!.copyWith(organizationId: 'office-b');
      await auth.refreshSession();
      await tester.pump();
      backend.requests[1].complete([marked]);
      await tester.pumpAndSettle();
      expect(action, findsOneWidget);

      backend.user = backend.user!.copyWith(organizationId: 'office-a');
      await auth.refreshSession();
      await tester.pump();
      backend.requests[2].complete([marked]);
      await tester.pumpAndSettle();
      expect(action, findsNothing);

      await _pullToRefresh(tester);
      backend.requests[3].complete([_checkIn('c', 'New arrival'), marked]);
      await tester.pumpAndSettle();
      expect(action, findsOneWidget);
      expect(_entry('New arrival'), findsOneWidget);
    },
  );

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

  testWidgets('returning from the background refreshes the open inbox', (
    tester,
  ) async {
    final backend = _ActivityBackend();
    await _mount(tester, backend);
    backend.requests.single.complete([]);
    await tester.pumpAndSettle();
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    expect(backend.requests, hasLength(2));
    backend.requests.last.complete([_checkIn('new', 'New after resume')]);
    await tester.pumpAndSettle();
    expect(_entry('New after resume'), findsOneWidget);
  });

  testWidgets(
    'Realtime refreshes after a pending read and announces only authorized new IDs',
    (tester) async {
      final backend = _ActivityBackend();
      final feed = AdminActivityProvider(
        backend,
        viewer: 'admin',
        office: 'office-a',
      );
      final received = <String>[];
      final listener = feed.arrivals.listen((event) => received.add(event.id));
      addTearDown(() async {
        await listener.cancel();
        await backend.signals.close();
      });

      backend.signals.add('first');
      backend.signals.add('first');
      backend.signals.add('outside');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(backend.requests, hasLength(1));
      backend.requests.single.complete([]);
      await tester.pump();
      expect(backend.requests, hasLength(2));
      final checkIn = _checkIn('first', 'Alex Morgan');
      backend.requests.last.complete([checkIn]);
      await tester.pump();
      expect(feed.hasUnread, isTrue);
      expect(received, ['first']);

      backend.signals.add('first');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      backend.requests.last.complete([checkIn]);
      await tester.pump();
      expect(received, ['first']);

      backend.signals.add('late');
      feed.dispose();
      await tester.pump(const Duration(milliseconds: 300));
      expect(backend.requests, hasLength(3));
      expect(received, ['first']);
    },
  );

  test('the preview supplies fictional rows without live access', () async {
    final preview = PreviewCompanyBackend();
    final rows = await preview.checkInActivity();
    expect(rows.map((row) => row.employeeName), ['Alex Morgan', 'Sam Rivera']);
    expect(rows.first.receivedAt.isAfter(rows.last.receivedAt), isTrue);
    await expectLater(
      PreviewCompanyBackend(available: false).checkInActivity(),
      throwsA(isA<CompanyException>()),
    );
  });

  testWidgets('only admin test builds can open activity in preview', (
    tester,
  ) async {
    const adminPreview = bool.fromEnvironment('ATTENDANCE_PREVIEW_ADMIN');
    final auth = AuthProvider(backend: PreviewCompanyBackend(available: false));
    addTearDown(auth.dispose);
    await auth.enterPreview();
    final endpoint = auth.backend!;
    expect(auth.currentUser!.isAdmin, adminPreview);
    expect((await endpoint.offices()).map((office) => office.role).toSet(), {
      adminPreview ? 'admin' : 'employee',
    });
    await expectLater(
      endpoint.savePolicy(const AttendancePolicy()),
      throwsA(isA<CompanyException>()),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          theme: AppTheme.theme,
          home: const AdminNotificationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_entry('Alex Morgan'), adminPreview ? findsOneWidget : findsNothing);
    expect(
      find.text('Check-in activity unavailable'),
      adminPreview ? findsNothing : findsOneWidget,
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
  final signals = StreamController<String?>.broadcast();
  @override
  Stream<String?> get checkInActivitySignals => signals.stream;
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
  DateTime get companyNow => DateTime(2026, 11, 19, 10);

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
