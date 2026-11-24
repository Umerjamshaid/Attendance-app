import 'dart:async';

import 'package:attendance/app.dart';
import 'package:attendance/bootstrap.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/office_provider.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/providers/theme_provider.dart';
import 'package:attendance/screens/login/login_screen.dart';
import 'package:attendance/widgets/bottom_nav.dart';
import 'package:attendance/widgets/office/office_selector_header.dart';
import 'package:attendance/widgets/office/office_switcher_sheet.dart';
import 'package:attendance/widgets/office/office_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'office_provider_test.dart' show ControlledOfficeBackend;
import 'support/test_fonts.dart';
import 'support/overview_fonts.dart';

void main() {
  setUpAll(() async {
    await loadTestFonts();
    await loadOverviewFonts();
  });

  testWidgets("What's new shows once per update, not on install or downgrade", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final installed = DateTime(2026, 11, 1);
    Future<void> launch(String build) async {
      await tester.pumpWidget(const SizedBox.shrink());
      _mockPackage(build, installTime: installed, updateTime: installed);
      runAttendanceApp(backend: ControlledOfficeBackend());
      await _pumpLaunch(tester);
    }

    final prefs = await SharedPreferences.getInstance();
    Finder sheetText(String text) => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(text, findRichText: true),
    );

    await launch('4026');
    expect(find.byType(BottomSheet), findsNothing);
    expect(prefs.getString('last_seen_release'), '1.1.0+4026');

    await launch('4027');
    expect(sheetText("What's new"), findsOneWidget);
    expect(sheetText('Version 1.1.0 (Build 4027)'), findsOneWidget);
    expect(find.byType(GptMarkdown), findsOneWidget);
    expect(sheetText('Faster Office Switch'), findsOneWidget);
    expect(sheetText('Interactive maker credits'), findsOneWidget);
    expect(prefs.getString('last_seen_release'), '1.1.0+4026');
    final done = sheetText('Got it');
    await tester.tap(done.hitTestable());
    await _pumpLaunch(tester);
    expect(find.byType(BottomSheet), findsNothing);
    expect(prefs.getString('last_seen_release'), '1.1.0+4027');

    await launch('4026');
    expect(find.byType(BottomSheet), findsNothing);
    expect(prefs.getString('last_seen_release'), '1.1.0+4027');
    await launch('4027');
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an update from a legacy build waits until Home is current', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    _mockPackage(
      '4027',
      installTime: DateTime(2026, 11, 1),
      updateTime: DateTime(2026, 11, 2),
    );
    final backend = ControlledOfficeBackend()..state.signedIn = false;
    var released = false;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider(backend: backend)),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(
            create: (_) => ProfileProvider(backend: backend),
          ),
          ChangeNotifierProvider(
            create: (context) => OfficeProvider(context.read<AuthProvider>()),
          ),
        ],
        child: AttendanceApp(onReady: () => released = true),
      ),
    );
    await _pumpLaunch(tester);
    final login = find.byType(LoginScreen);
    expect(login, findsOneWidget);
    expect(released, isTrue);
    expect(find.byType(BottomSheet), findsNothing);

    final loginContext = tester.element(login);
    final auth = loginContext.read<AuthProvider>();
    final navigator = Navigator.of(loginContext);
    unawaited(
      navigator.push<void>(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Cover'))),
      ),
    );
    await _pumpLaunch(tester);
    backend.state.signedIn = true;
    await auth.refreshSession();
    await _pumpLaunch(tester);
    expect(find.text('Cover'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    navigator.pop();
    await _pumpLaunch(tester);
    expect(find.text("What's new"), findsOneWidget);
    expect(find.byType(BottomNav), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await _pumpLaunch(tester);
    expect(find.byType(BottomSheet), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('last_seen_release'), '1.1.0+4027');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'real bootstrap hides old content, replaces office providers and preserves profile state',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'Attendance',
        packageName: 'test.attendance',
        version: '1.1.0',
        buildNumber: '6',
        buildSignature: '',
      );
      final backend = ControlledOfficeBackend();
      await tester.pumpWidget(const SizedBox.shrink());
      runAttendanceApp(backend: backend);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final context = tester.element(find.byType(OfficeSelectorHeader));
      final auth = context.read<AuthProvider>();
      final offices = context.read<OfficeProvider>();
      final profile = context.read<ProfileProvider>();
      final oldHistory = context.read<AttendanceHistoryProvider>();
      expect(oldHistory.records.single.id, 'record-a');
      expect(tester.widget<BottomNav>(find.byType(BottomNav)).isAdmin, isTrue);
      backend.state.switchGate = Completer<void>();
      final pending = offices.switchOffice('b');
      await tester.pump();
      expect(find.bySemanticsLabel('Loading office'), findsOneWidget);
      final overlay = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('office-loading-overlay')),
      );
      expect(
        overlay.color.a,
        1,
        reason: 'old-office evidence cannot show through the loading layer',
      );
      backend.state.switchGate!.complete();
      await pending;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final next = tester.element(find.byType(OfficeSelectorHeader));
      expect(next.read<AuthProvider>(), same(auth));
      expect(next.read<ProfileProvider>(), same(profile));
      expect(next.read<AttendanceHistoryProvider>(), isNot(same(oldHistory)));
      expect(
        next.read<AttendanceHistoryProvider>().records.single.id,
        'record-b',
      );
      expect(tester.widget<BottomNav>(find.byType(BottomNav)).isAdmin, isFalse);
      expect(find.text('Office B'), findsOneWidget);
      expect(find.bySemanticsLabel('Loading office'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'the account switcher survives real office route invalidation and nested Back works',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = ControlledOfficeBackend();
      await tester.pumpWidget(const SizedBox.shrink());
      runAttendanceApp(backend: backend);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final home = tester.element(find.byType(OfficeSelectorHeader));
      final rootNavigator = Navigator.of(home, rootNavigator: true);
      final navigation = home.read<OfficeNavigatorController>();
      final oldOfficeNavigator = navigation.navigator;
      await tester.tap(find.byKey(const ValueKey('office-selector')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final switcher = tester.state(find.byType(OfficeSwitcherSheet));
      backend.state.switchGate = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('office-option-b')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      expect(
        find.byKey(const ValueKey('office-loading-overlay')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('office-flying-avatar')),
        findsOneWidget,
      );
      backend.state.switchGate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 650));
      expect(tester.state(find.byType(OfficeSwitcherSheet)), same(switcher));
      final next = tester.element(find.byType(OfficeSelectorHeader));
      expect(Navigator.of(next, rootNavigator: true), same(rootNavigator));
      expect(navigation.navigator, isNot(same(oldOfficeNavigator)));
      expect(
        next.read<AttendanceHistoryProvider>().records.single.id,
        'record-b',
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pump(const Duration(milliseconds: 350));
      unawaited(
        navigation.navigator!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Office B detail')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Office B detail'), findsOneWidget);
      await tester.pump();
      expect(navigation.navigator!.canPop(), isTrue);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(navigation.navigator!.canPop(), isFalse);
      expect(find.text('Office B detail'), findsNothing);
      expect(find.byType(OfficeSelectorHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

void _mockPackage(
  String build, {
  required DateTime installTime,
  required DateTime updateTime,
}) => PackageInfo.setMockInitialValues(
  appName: 'Attendance',
  packageName: 'test.attendance',
  version: '1.1.0',
  buildNumber: build,
  buildSignature: '',
  installTime: installTime,
  updateTime: updateTime,
);

Future<void> _pumpLaunch(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}
