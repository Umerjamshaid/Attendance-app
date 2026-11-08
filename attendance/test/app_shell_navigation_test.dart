import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/admin_provider.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/providers/theme_provider.dart';
import 'package:attendance/screens/app_shell.dart';
import 'package:attendance/screens/history/history_screen.dart';
import 'package:attendance/screens/home/attendance_screen.dart';
import 'package:attendance/screens/profile/profile_screen.dart';
import 'package:attendance/services/attendance_service.dart';
import 'package:attendance/services/employees_service.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:attendance/widgets/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/overview_fonts.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(() async {
    await loadTestFonts();
    await loadOverviewFonts();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Attendance',
      packageName: 'test.attendance',
      version: '1.1.0',
      buildNumber: '6',
      buildSignature: '',
    );
  });

  testWidgets('employee swipes and dock taps select the same page', (
    tester,
  ) async {
    final fixture = await _mount(tester);
    expect(_nav(tester).isAdmin, false);
    expect(find.byTooltip('Admin'), findsNothing);
    expect(
      tester.getCenter(find.byKey(const ValueKey('floating-navigation'))).dx,
      195,
    );
    final physics = _pager(tester).physics!;
    expect(physics.spring.mass, 0.5);
    expect(physics.spring.stiffness, 200);
    expect(physics.spring.damping, 18);

    await _swipe(tester, -360);
    _expectSelected(tester, 'History', 1);
    final home = find.byType(AttendanceScreen, skipOffstage: false);
    expect(tester.widget<AttendanceScreen>(home).isActive, false);
    expect(TickerMode.valuesOf(tester.element(home)).enabled, false);
    await _swipe(tester, 360);
    _expectSelected(tester, 'Home', 0);
    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    _expectSelected(tester, 'Profile', 2);
    expect(fixture.auth.isAuthenticated, true);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('admin stays reachable by swipe and refreshes on either path', (
    tester,
  ) async {
    final fixture = await _mount(tester, admin: true);
    await _swipe(tester, -360);
    await _swipe(tester, -360);
    _expectSelected(tester, 'Admin', 2);
    expect(fixture.admin.loadCalls, greaterThan(0));
    await _swipe(tester, -360);
    _expectSelected(tester, 'Profile', 3);
    final before = fixture.admin.loadCalls;
    await tester.tap(find.byTooltip('Admin'));
    await tester.pumpAndSettle();
    _expectSelected(tester, 'Admin', 2);
    expect(fixture.admin.loadCalls, greaterThan(before));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('vertical history scrolling and page state survive tab changes', (
    tester,
  ) async {
    await _mount(tester);
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    final historyState = tester.state(find.byType(HistoryScreen));
    final scrolling = find
        .descendant(
          of: find.byType(HistoryScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    final scrollState = tester.state<ScrollableState>(scrolling);
    await tester.drag(find.byType(HistoryScreen), const Offset(0, -480));
    await tester.pumpAndSettle();
    final offset = scrollState.position.pixels;
    expect(offset, greaterThan(0));
    _expectSelected(tester, 'History', 1);
    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    await _swipe(tester, 360);
    _expectSelected(tester, 'History', 1);
    expect(tester.state(find.byType(HistoryScreen)), same(historyState));
    expect(scrollState.position.pixels, closeTo(offset, 0.01));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('rapid dock taps and an interrupted swipe leave one selection', (
    tester,
  ) async {
    await _mount(tester);
    for (final label in ['History', 'Profile', 'Home']) {
      await tester.tap(find.byTooltip(label));
    }
    await tester.pumpAndSettle();
    _expectSelected(tester, 'Home', 0);
    final drag = await tester.startGesture(tester.getCenter(_pageFinder));
    await drag.moveBy(const Offset(-220, 0));
    await tester.pump();
    await tester.tap(find.byTooltip('Profile'));
    await drag.up();
    await tester.pumpAndSettle();
    _expectSelected(tester, 'Profile', 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Profile selection and state survive admin role changes', (
    tester,
  ) async {
    final fixture = await _mount(tester, admin: true);
    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    final profileState = tester.state(find.byType(ProfileScreen));
    final oldTap = _nav(tester).onTap;
    fixture.backend.admin = false;
    await fixture.auth.refreshSession();
    await tester.pumpAndSettle();
    _expectSelected(tester, 'Profile', 2);
    expect(find.byTooltip('Admin'), findsNothing);
    expect(tester.state(find.byType(ProfileScreen)), same(profileState));
    oldTap(3);
    expect(_pager(tester).controller!.page, 2);
    fixture.backend.admin = true;
    await fixture.auth.refreshSession();
    await tester.pumpAndSettle();
    _expectSelected(tester, 'Profile', 3);
    expect(tester.state(find.byType(ProfileScreen)), same(profileState));
    await tester.tap(find.byTooltip('Admin'));
    await tester.pumpAndSettle();
    fixture.backend.admin = false;
    await fixture.auth.refreshSession();
    await tester.pumpAndSettle();
    _expectSelected(tester, 'Home', 0);
    expect(find.byTooltip('Admin'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('RTL and reduced motion retain synchronized swipes', (
    tester,
  ) async {
    await _mount(tester, rtl: true, reducedMotion: true);
    expect(_pager(tester).physics.runtimeType, PageScrollPhysics);
    await _swipe(tester, 360);
    _expectSelected(tester, 'History', 1);
    await tester.tap(find.byTooltip('Profile'));
    await tester.pump();
    _expectSelected(tester, 'Profile', 2);
    for (final align in tester.widgetList<AnimatedAlign>(
      find.byType(AnimatedAlign),
    )) {
      expect(align.duration, Duration.zero);
    }
    expect(
      tester.getCenter(find.byKey(const ValueKey('floating-navigation'))).dx,
      195,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

final _pageFinder = find.byKey(const PageStorageKey('main-pages'));
PageView _pager(WidgetTester tester) => tester.widget<PageView>(_pageFinder);
BottomNav _nav(WidgetTester tester) =>
    tester.widget<BottomNav>(find.byType(BottomNav));

void _expectSelected(WidgetTester tester, String label, int index) {
  expect(_nav(tester).currentIndex, index);
  expect(_pager(tester).controller!.page, closeTo(index, 0.01));
  expect(
    find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == label &&
          widget.properties.selected == true,
    ),
    findsOneWidget,
  );
  expect(tester.takeException(), isNull);
}

Future<void> _swipe(WidgetTester tester, double dx) async {
  await tester.drag(_pageFinder, Offset(dx, 0));
  await tester.pumpAndSettle();
}

Future<_Fixture> _mount(
  WidgetTester tester, {
  bool admin = false,
  bool rtl = false,
  bool reducedMotion = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final fixture = _Fixture(admin: admin);
  addTearDown(fixture.dispose);
  await fixture.auth.refreshSession();
  await fixture.history.loadHistory('DEMO001');
  await tester.pumpWidget(fixture.app(rtl: rtl, reducedMotion: reducedMotion));
  await tester.pumpAndSettle();
  return fixture;
}

class _Fixture {
  _Fixture({required bool admin}) : backend = _Backend(admin: admin);
  final _Backend backend;
  late final auth = AuthProvider(backend: backend);
  late final history = AttendanceHistoryProvider(
    service: AttendanceService(backend: backend),
  );
  late final attendance = _UiAttendanceProvider(backend);
  late final profile = ProfileProvider(backend: backend);
  late final admin = _CountingAdmin(backend);
  late final theme = ThemeProvider();

  Widget app({required bool rtl, required bool reducedMotion}) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: history),
      ChangeNotifierProvider<AttendanceProvider>.value(value: attendance),
      ChangeNotifierProvider.value(value: profile),
      ChangeNotifierProvider<AdminProvider>.value(value: admin),
      ChangeNotifierProvider.value(value: theme),
    ],
    child: MaterialApp(
      theme: AppTheme.theme.copyWith(
        textTheme: AppTheme.theme.textTheme.apply(fontFamily: 'Roboto'),
      ),
      builder: (context, child) => Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reducedMotion),
          child: child!,
        ),
      ),
      home: const AppShell(),
    ),
  );

  void dispose() {
    auth.dispose();
    history.dispose();
    attendance.dispose();
    profile.dispose();
    admin.dispose();
    theme.dispose();
  }
}

class _Backend extends PreviewCompanyBackend {
  _Backend({required this.admin});
  bool admin;
  @override
  bool get isPreview => false;
  @override
  Future<Employee?> restoreSession() async =>
      (await super.restoreSession())!.copyWith(
        role: admin ? 'admin' : 'employee',
        isPresentToday: true,
        checkInTime: '09:05 AM',
      );
}

class _UiAttendanceProvider extends AttendanceProvider {
  _UiAttendanceProvider(_Backend backend) : super(backend: backend);
  @override
  Future<void> initialize() => loadWindowConfig();
}

class _CountingAdmin extends AdminProvider {
  _CountingAdmin(_Backend backend)
    : super(
        attendanceService: AttendanceService(backend: backend),
        employeeService: EmployeeService(backend: backend),
      );
  int loadCalls = 0;
  @override
  Future<void> loadDashboard() async {
    loadCalls++;
    await super.loadDashboard();
  }
}
