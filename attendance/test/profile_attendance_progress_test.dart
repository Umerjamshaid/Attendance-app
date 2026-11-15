import 'dart:async';

import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/attendance_record_model.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/services/attendance_service.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:attendance/widgets/check_in_summary.dart';
import 'package:attendance/widgets/user-profile/attendance_progress_ring.dart';
import 'package:attendance/widgets/user-profile/attendance_stats_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/test_fonts.dart';

class _Backend extends PreviewCompanyBackend {
  Completer<List<AttendanceRecord>>? pending;
  @override
  DateTime get companyNow => DateTime(2026, 11, 15, 12);
  @override
  Future<List<AttendanceRecord>> history({
    String? employeeId,
    bool todayOnly = false,
  }) async =>
      pending?.future ??
      [
        for (final (index, day) in [15, 15, 14, 13, 10, 5].indexed)
          AttendanceRecord(
            id: 'record-$index',
            userId: 'EMP001',
            isPresent: true,
            timestamp: DateTime(2026, 11, day, 9),
            device: 'Sample device',
          ),
      ];
}

void main() {
  setUpAll(loadTestFonts);

  Future<AttendanceHistoryProvider> mount(
    WidgetTester tester, {
    bool dark = false,
    bool reducedMotion = false,
    _Backend? backend,
  }) async {
    final history = AttendanceHistoryProvider(
      service: AttendanceService(backend: backend ?? _Backend()),
    );
    addTearDown(history.dispose);
    final request = history.loadHistory('EMP001');
    if (backend?.pending == null) await request;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: history,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.darkTheme : AppTheme.theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reducedMotion),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: CheckInSummary()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return history;
  }

  for (final dark in [false, true]) {
    testWidgets(
      'profile activity ${dark ? "dark" : "light"} reference, narrow and large text',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 500);
        addTearDown(tester.view.reset);
        final history = await mount(tester, dark: dark);
        expect(history.presentThisMonthCount, 5);
        expect(history.totalCount, 6);
        expect(history.currentStreak, 3);
        expect(
          tester
              .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator),
              )
              .value,
          closeTo(1 / 3, .001),
        );
        expect(find.text('33%'), findsOneWidget);
        expect(find.text('Days this month'), findsOneWidget);
        expect(find.text('Check-ins'), findsOneWidget);
        expect(find.text('Day streak'), findsOneWidget);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(
            'goldens/profile_activity_${dark ? "dark" : "light"}.png',
          ),
        );
        tester.view.physicalSize = const Size(320, 650);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Day streak'));
        expect(tester.takeException(), isNull);
        tester.view.physicalSize = const Size(800, 600);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('loading and failed history show no invented progress', (
    tester,
  ) async {
    final backend = _Backend()..pending = Completer<List<AttendanceRecord>>();
    await mount(tester, backend: backend);
    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    backend.pending!.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Unavailable'), findsOneWidget);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'progress updates immediately with reduced motion and keeps raw check-in counts',
    (tester) async {
      final history = await mount(tester, reducedMotion: true);
      history.acceptSubmittedRecord(
        AttendanceRecord(
          id: 'new-record',
          userId: 'EMP001',
          isPresent: true,
          timestamp: DateTime(2026, 11, 15, 11),
          device: 'Sample device',
        ),
      );
      await tester.pump();
      expect(find.text('7'), findsOneWidget);
      expect(find.text('33%'), findsOneWidget);
      expect(history.presentThisMonthCount, 5);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'legacy overview keeps presents, absents and leaves with its existing rate',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: AttendanceStatsCard(
              employee: Employee(
                id: 'EMP001',
                name: 'Alex',
                email: '',
                role: 'employee',
                department: '',
                time: '',
                totalPresents: 18,
                totalAbsents: 2,
                totalLeaves: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('86%'), findsOneWidget);
      for (final label in ['Presents', 'Absents', 'Leaves']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ring clamps invalid inputs and exposes an accessible percentage',
    (tester) async {
      final semantics = tester.ensureSemantics();
      Future<void> show(double progress) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AttendanceProgressRing(
                progress: progress,
                label: 'This month',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(2);
      expect(find.text('100%'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('This month')).value,
        '100 percent',
      );
      await show(-1);
      expect(find.text('0%'), findsOneWidget);
      await show(double.nan);
      expect(find.text('Unavailable'), findsOneWidget);
      semantics.dispose();
    },
  );
}
