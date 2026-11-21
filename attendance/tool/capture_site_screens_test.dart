import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/attendance_record_model.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/models/office_model.dart';
import 'package:attendance/providers/admin_provider.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/office_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/providers/theme_provider.dart';
import 'package:attendance/screens/app_shell.dart';
import 'package:attendance/services/attendance_service.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/services/employees_service.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/test_fonts.dart';

const _readmeGallery = bool.fromEnvironment('ATTENDANCE_README_SCREENSHOTS');
const _captureSurface = ValueKey('readme-capture-surface');

void main() {
  setUpAll(loadTestFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final screens = _readmeGallery
      ? [
          ('Home', 'attendance', AppPalette.olive, Brightness.light),
          ('History', 'history', AppPalette.tide, Brightness.dark),
          ('Admin', 'admin', AppPalette.iris, Brightness.light),
          ('Admin', 'employees', AppPalette.graphite, Brightness.dark),
          ('Profile', 'profile', AppPalette.tide, Brightness.light),
          ('Profile', 'settings', AppPalette.graphite, Brightness.dark),
        ]
      : [
          ('Home', 'check-in', AppPalette.olive, Brightness.light),
          ('History', 'history', AppPalette.tide, Brightness.dark),
          ('Admin', 'offices', AppPalette.iris, Brightness.light),
        ];

  for (final (tab, file, palette, brightness) in screens) {
    testWidgets('capture $file using fictional data', (tester) async {
      if (_readmeGallery) {
        SharedPreferences.setMockInitialValues({
          'theme_palette': palette.name,
          'theme_mode': brightness.name,
        });
        PackageInfo.setMockInitialValues(
          appName: 'Attendance',
          packageName: 'com.example.attendance',
          version: '1.1.0',
          buildNumber: '4027',
          buildSignature: '',
        );
      }
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.padding = const FakeViewPadding(top: 22, bottom: 12);
      addTearDown(tester.view.reset);

      final backend = _ShowcaseBackend();
      final auth = AuthProvider(backend: backend);
      await auth.refreshSession();
      final user = auth.currentUser!;
      final offices = OfficeProvider(auth);
      final attendance = _ShowcaseAttendance(backend);
      final history = AttendanceHistoryProvider(
        service: AttendanceService(backend: backend),
      );
      final admin = AdminProvider(
        attendanceService: AttendanceService(backend: backend),
        employeeService: EmployeeService(backend: backend),
      )..setFilter('all');
      final profile = ProfileProvider(backend: backend);
      final theme = ThemeProvider();
      await history.loadHistory(user.id);
      addTearDown(() {
        offices.dispose();
        auth.dispose();
        attendance.dispose();
        history.dispose();
        admin.dispose();
        profile.dispose();
        theme.dispose();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: offices),
            ChangeNotifierProvider<AttendanceProvider>.value(value: attendance),
            ChangeNotifierProvider.value(value: history),
            ChangeNotifierProvider.value(value: admin),
            ChangeNotifierProvider.value(value: profile),
            ChangeNotifierProvider.value(value: theme),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.forPalette(palette, brightness),
            builder: (context, child) => RepaintBoundary(
              key: _captureSurface,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
            ),
            home: const AppShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (tab != 'Home') {
        await tester.tap(find.byTooltip(tab));
        await tester.pumpAndSettle();
      }
      if (file == 'employees') {
        await tester.tap(find.byTooltip('Manage employees'));
        await tester.pumpAndSettle();
        expect(find.text('Removed'), findsOneWidget);
      } else if (file == 'settings') {
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        expect(find.text('Sign-in & recovery'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        _readmeGallery ? find.byKey(_captureSurface) : find.byType(AppShell),
        matchesGoldenFile(
          _readmeGallery
              ? '../screenshots/current/$file.png'
              : '../../site/public/screens/$file.png',
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

class _ShowcaseAttendance extends AttendanceProvider {
  _ShowcaseAttendance(_ShowcaseBackend backend) : super(backend: backend);

  @override
  Future<void> initialize() => loadWindowConfig();
}

class _ShowcaseBackend extends PreviewCompanyBackend {
  static const studio = Office(
    id: 'sample-studio',
    name: 'Northstar Studio',
    role: 'admin',
    createdBy: 'sample-alex',
  );

  static final roster = [
    _employee('alex', 'Alex Morgan', 'Product', role: 'admin'),
    _employee('sam', 'Sam Rivera', 'Engineering'),
    _employee('jordan', 'Jordan Chen', 'Design'),
    _employee('avery', 'Avery Blake', 'Operations'),
  ];

  static Employee _employee(
    String id,
    String name,
    String department, {
    String role = 'employee',
  }) => Employee(
    id: 'SAMPLE-$id',
    authUserId: 'sample-$id',
    organizationId: studio.id,
    officeName: studio.name,
    name: name,
    department: department,
    email: '$id@example.invalid',
    role: role,
    time: '',
  );

  @override
  bool get isPreview => false;
  @override
  CompanyBackend forOffice(Employee employee) => this;
  @override
  Future<Employee?> restoreSession() async => _readmeGallery
      ? roster.first.copyWith(
          headline: 'Product operations',
          chips: ['Mentor', 'Onboarding'],
        )
      : roster.first;
  @override
  Future<List<Office>> offices() async => [studio];
  @override
  Future<List<Employee>> employees() async => _readmeGallery
      ? [...roster.take(3), roster.last.copyWith(isActive: false)]
      : roster;
  @override
  DateTime get companyNow =>
      _readmeGallery ? DateTime.now() : DateTime(2026, 11, 18, 9);

  @override
  Future<List<AttendanceRecord>> history({
    String? employeeId,
    bool todayOnly = false,
  }) async => [
    if (todayOnly)
      for (final (i, employee) in roster.skip(1).take(2).indexed)
        _record(employee.id, 0, minute: i * 9 + 12)
    else
      for (final day in [1, 2, 3, 5, 6, 7])
        _record(employeeId ?? roster.first.id, day, minute: day * 7),
  ];

  AttendanceRecord _record(String user, int day, {required int minute}) {
    final today = companyNow;
    return AttendanceRecord(
      id: '$user-$day',
      userId: user,
      isPresent: true,
      timestamp: DateTime(today.year, today.month, today.day - day, 9, minute),
      device: 'Android device',
    );
  }
}
