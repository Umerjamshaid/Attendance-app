import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/attendance_record_model.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/screens/history/history_screen.dart';
import 'package:attendance/screens/home/attendance_screen.dart';
import 'package:attendance/services/attendance_service.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:attendance/widgets/home/attendance_button.dart';
import 'package:attendance/widgets/home/attendance_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_fonts.dart';
import 'support/overview_fonts.dart';

void main() {
  setUpAll(() async {
    await loadTestFonts();
    await loadOverviewFonts();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'Home summary ${brightness.name} reference and responsive labels',
      (tester) async {
        _setView(tester, const Size(390, 250));
        await tester.pumpWidget(
          _app(
            brightness,
            const Scaffold(
              body: AttendanceSummaryCard(
                isCheckedIn: false,
                monthlyRate: 1 / 3,
                streak: 1,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(
            'goldens/attendance_summary_${brightness.name}.png',
          ),
        );
        for (final size in [const Size(320, 560), const Size(800, 500)]) {
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          await tester.pumpAndSettle();
          expect(find.text('Not yet'), findsOneWidget);
          expect(find.text('Today'), findsOneWidget);
          expect(find.text('This month'), findsOneWidget);
          expect(find.text('Day streak'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets('History ${brightness.name} keeps the original overview', (
      tester,
    ) async {
      _setView(tester, const Size(390, 844));
      final backend = _FixtureBackend(preview: false);
      final auth = AuthProvider(backend: backend);
      final history = AttendanceHistoryProvider(
        service: AttendanceService(backend: backend),
      );
      addTearDown(auth.dispose);
      addTearDown(history.dispose);
      await history.loadHistory('DEMO001');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: history),
          ],
          child: _app(brightness, const HistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      _expectOverview();
      // Three submissions on two days must not lower the recorded-day rate.
      expect(history.totalCount, 3);
      expect(history.presentCount, 2);
      expect(find.text('100%'), findsOneWidget);
      await expectLater(
        find.byType(HistoryScreen),
        matchesGoldenFile('goldens/history_overview_${brightness.name}.png'),
      );
      for (final size in [const Size(320, 560), const Size(800, 500)]) {
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        await tester.pumpAndSettle();
        _expectOverview();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final preview in [true, false]) {
    testWidgets(
      'Home keeps today status in ${preview ? 'demo' : 'company'} mode',
      (tester) async {
        _setView(tester, const Size(390, 1100));
        final backend = _FixtureBackend(preview: preview);
        final employee = (await backend.restoreSession())!;
        final history = AttendanceHistoryProvider(
          service: AttendanceService(backend: backend),
        );
        final attendance = _UiAttendanceProvider(backend);
        final profile = ProfileProvider(backend: backend);
        addTearDown(history.dispose);
        addTearDown(attendance.dispose);
        addTearDown(profile.dispose);
        await history.loadHistory(employee.id);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: history),
              ChangeNotifierProvider<AttendanceProvider>.value(
                value: attendance,
              ),
              ChangeNotifierProvider.value(value: profile),
            ],
            child: _app(
              Brightness.light,
              AttendanceScreen(employee: employee, isActive: false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AttendanceSummaryCard), findsOneWidget);
        expect(find.text('Your attendance'), findsOneWidget);
        expect(find.text('Not yet'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Check-in activity'), findsNothing);
        expect(
          tester
              .widget<AttendanceButton>(find.byType(AttendanceButton))
              .isUploadEnabled,
          !preview,
        );
        history.acceptSubmittedRecord(
          AttendanceRecord(
            id: 'today',
            userId: employee.id,
            isPresent: true,
            timestamp: backend.companyNow,
            device: 'Test phone',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Present'), findsOneWidget);
        expect(find.text('Not yet'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('Home summary respects reduced motion and loading placeholders', (
    tester,
  ) async {
    _setView(tester, const Size(320, 300));
    await tester.pumpWidget(
      _app(
        Brightness.dark,
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(
            body: AttendanceSummaryCard(
              isCheckedIn: false,
              monthlyRate: 0,
              streak: 0,
              isLoading: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('—'), findsNWidgets(2));
    for (final switcher in tester.widgetList<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    )) {
      expect(switcher.duration, Duration.zero);
    }
    expect(tester.takeException(), isNull);
  });
}

void _setView(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Widget _app(Brightness brightness, Widget home) {
  final theme = brightness == Brightness.dark
      ? AppTheme.darkTheme
      : AppTheme.theme;
  return MaterialApp(
    theme: theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
    ),
    home: home,
  );
}

void _expectOverview() {
  for (final label in [
    'Overview',
    'This month',
    'Current streak',
    'Overall rate',
    'Days present',
    'Days absent',
  ]) {
    expect(find.text(label), findsOneWidget);
  }
  expect(find.text('Check-in activity'), findsNothing);
}

class _FixtureBackend extends PreviewCompanyBackend {
  _FixtureBackend({required this.preview});
  final bool preview;
  @override
  bool get isPreview => preview;
  @override
  DateTime get companyNow => DateTime(2026, 11, 6, 12);
  @override
  Future<List<AttendanceRecord>> history({
    String? employeeId,
    bool todayOnly = false,
  }) async => [
    for (var i = 0; i < 3; i++)
      AttendanceRecord(
        id: 'sample-$i',
        userId: 'DEMO001',
        isPresent: true,
        timestamp: DateTime(2026, 11, i == 2 ? 4 : 5, 9, 5),
        device: 'Sample Android device',
      ),
  ];
}

class _UiAttendanceProvider extends AttendanceProvider {
  _UiAttendanceProvider(_FixtureBackend backend) : super(backend: backend);
  @override
  Future<void> initialize() => loadWindowConfig();
}
