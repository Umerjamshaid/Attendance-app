import 'dart:async';

import 'package:attendance/config/app_icons.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/attendance_record_model.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/screens/admin/attendance_evidence_screen.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:attendance/widgets/admin/employee_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/overview_fonts.dart';
import 'support/test_fonts.dart';

final _employee = Employee(
  id: 'EMP001',
  name: 'Alice Johnson',
  email: 'alice@example.invalid',
  department: 'Engineering',
  role: 'employee',
  time: '',
);

final _samples = [
  for (var i = 0; i < 3; i++)
    AttendanceRecord(
      id: 'log-$i',
      userId: _employee.id,
      isPresent: true,
      timestamp: DateTime(2026, 11, i == 2 ? 9 : 10, 9 - i, 5),
      device: i == 0 ? 'Samsung Galaxy S21 Ultra' : 'Sample Android device',
    ),
];

void main() {
  setUpAll(() async {
    await loadTestFonts();
    await loadOverviewFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final brightness in Brightness.values) {
    testWidgets('Check-in Logs ${brightness.name} reference and large text', (
      tester,
    ) async {
      await _mount(tester, brightness: brightness);
      await _open(tester);
      expect(find.text('Check-in logs'), findsOneWidget);
      expect(find.text('3 check-ins'), findsOneWidget);
      expect(find.text('Nov 10, 2026'), findsOneWidget);
      expect(find.text('Nov 9, 2026'), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(AppIcons.x)).size, 20);
      expect(
        tester.getSize(find.byTooltip('Close check-in logs')).shortestSide,
        greaterThanOrEqualTo(48),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/check_in_logs_${brightness.name}.png'),
      );
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byTooltip('Close check-in logs').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close check-in logs'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    });
  }

  testWidgets('employee logs use a modal spring route, not a new page', (
    tester,
  ) async {
    final fixture = await _mount(tester);
    await _open(tester);
    final route = fixture.observer.routes.last;
    expect(route, isA<ModalBottomSheetRoute<void>>());
    expect(route, isNot(isA<MaterialPageRoute<void>>()));
    expect(route.settings.name, 'employee-check-in-logs');
    expect(route.createSimulation(forward: false), isA<SpringSimulation>());
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(fixture.backend.employeeIds, [_employee.id]);
    await tester.tap(find.byTooltip('Refresh check-in logs'));
    await tester.pumpAndSettle();
    expect(fixture.backend.employeeIds, [_employee.id, _employee.id]);
  });

  testWidgets('list dragging expands the sheet then scrolls long logs', (
    tester,
  ) async {
    final backend = _Backend()
      ..records = [
        for (var i = 0; i < 80; i++)
          AttendanceRecord(
            id: '$i',
            userId: _employee.id,
            isPresent: true,
            timestamp: DateTime(
              2026,
              11,
              10,
              10,
            ).subtract(Duration(minutes: i)),
            device: 'Phone $i',
          ),
      ];
    await _mount(tester, backend: backend);
    await _open(tester);
    final before = tester.getRect(find.byType(BottomSheet));
    final scroll = find.byKey(PageStorageKey('check-ins-${_employee.id}'));
    await tester.drag(scroll, const Offset(0, -280));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(BottomSheet)).top, lessThan(before.top));
    await tester.drag(scroll, const Offset(0, -400));
    await tester.pumpAndSettle();
    final state = tester.state<ScrollableState>(
      find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
    );
    expect(state.position.pixels, greaterThan(0));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byTooltip('Close check-in logs').hitTestable(), findsOneWidget);
    expect(backend.employeeIds.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('close, outside tap, back, and drag all dismiss safely', (
    tester,
  ) async {
    await _mount(tester);
    await _open(tester);
    await tester.tap(find.byTooltip('Close check-in logs'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    await _open(tester);
    await tester.tapAt(const Offset(8, 60));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    await _open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    await _open(tester);
    final sheet = tester.getRect(find.byType(BottomSheet));
    await tester.flingFrom(
      Offset(sheet.center.dx, sheet.top + 14),
      const Offset(0, 430),
      1400,
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Admin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'loading, retry, empty state and refresh keep the employee filter',
    (tester) async {
      final pending = Completer<List<AttendanceRecord>>();
      final backend = _Backend()..pending = pending;
      await _mount(tester, backend: backend);
      await tester.tap(find.byType(EmployeeCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.completeError(StateError('offline'));
      backend.pending = null;
      backend.records = [];
      await tester.pumpAndSettle();
      expect(find.text('Could not load check-ins'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No check-ins yet'), findsOneWidget);
      backend.records = _samples;
      await tester.tap(find.byTooltip('Refresh check-in logs'));
      await tester.pumpAndSettle();
      expect(find.text('3 check-ins'), findsOneWidget);
      expect(backend.employeeIds, [_employee.id, _employee.id, _employee.id]);
    },
  );

  testWidgets('dismiss during loading does not update a disposed sheet', (
    tester,
  ) async {
    final pending = Completer<List<AttendanceRecord>>();
    await _mount(tester, backend: _Backend()..pending = pending);
    await tester.tap(find.byType(EmployeeCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byTooltip('Close check-in logs'));
    await tester.pump(const Duration(milliseconds: 700));
    pending.complete(_samples);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a log still opens evidence and Back restores the sheet', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final fixture = await _mount(tester);
    await _open(tester);
    final row = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          (widget.properties.label?.startsWith('Checked in at 9:05') ??
              false) &&
          (widget.properties.label?.contains('Samsung Galaxy S21 Ultra') ??
              false),
    );
    try {
      expect(
        tester.getSemantics(row),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: tester.widget<Semantics>(row).properties.label,
        ),
      );
    } finally {
      semantics.dispose();
    }
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AttendanceEvidenceScreen), findsOneWidget);
    expect(fixture.backend.evidenceIds, ['log-0']);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Check-in logs'), findsOneWidget);
    expect(fixture.backend.employeeIds.length, 1);
  });

  testWidgets('reduced motion and RTL use the same accessible modal', (
    tester,
  ) async {
    final fixture = await _mount(
      tester,
      reduceMotion: true,
      direction: TextDirection.rtl,
    );
    await _open(tester);
    final route = fixture.observer.routes.last;
    expect(route.createSimulation(forward: true), isNull);
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
    expect(find.byTooltip('Close check-in logs').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Close check-in logs'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy employee details and totals remain unchanged', (
    tester,
  ) async {
    final fixture = await _mount(tester, checkInLog: false);
    await _open(tester);
    expect(find.text('Total presents'), findsOneWidget);
    expect(find.text('Attendance rate'), findsOneWidget);
    expect(find.text('Check-in logs'), findsNothing);
    expect(fixture.backend.employeeIds, isEmpty);
  });
}

Future<({_Backend backend, _Observer observer})> _mount(
  WidgetTester tester, {
  _Backend? backend,
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
  TextDirection direction = TextDirection.ltr,
  bool checkInLog = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final service = backend ?? _Backend();
  final observer = _Observer();
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(backend: service),
      child: MaterialApp(
        navigatorObservers: [observer],
        debugShowCheckedModeBanner: false,
        theme:
            (brightness == Brightness.dark
                    ? AppTheme.darkTheme
                    : AppTheme.theme)
                .copyWith(
                  textTheme:
                      (brightness == Brightness.dark
                              ? AppTheme.darkTheme
                              : AppTheme.theme)
                          .textTheme
                          .apply(fontFamily: 'Roboto'),
                ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: Directionality(textDirection: direction, child: child!),
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('Admin')),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topCenter,
              child: EmployeeCard(
                checkInLog: checkInLog,
                data: EmployeeAttendance(
                  employee: _employee,
                  latestRecord: _samples.first,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (backend: service, observer: observer);
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byType(EmployeeCard));
  await tester.pumpAndSettle();
}

class _Observer extends NavigatorObserver {
  final routes = <TransitionRoute<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is TransitionRoute<dynamic>) routes.add(route);
  }
}

class _Backend extends PreviewCompanyBackend {
  @override
  PreviewCompanyBackend forOffice(Employee employee) => this;
  List<AttendanceRecord> records = _samples;
  Completer<List<AttendanceRecord>>? pending;
  final employeeIds = <String?>[];
  final evidenceIds = <String>[];
  final evidenceResult = Completer<Map<String, dynamic>>();
  @override
  bool get isPreview => false;
  @override
  Future<List<AttendanceRecord>> history({
    String? employeeId,
    bool todayOnly = false,
  }) {
    employeeIds.add(employeeId);
    return pending?.future ?? Future.value(records);
  }

  @override
  Future<Map<String, dynamic>> evidence(String recordId) {
    evidenceIds.add(recordId);
    return evidenceResult.future;
  }
}
