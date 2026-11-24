import 'package:attendance/config/app_icons.dart';
import 'package:attendance/config/app_info.dart';
import 'package:attendance/app.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/providers/theme_provider.dart';
import 'package:attendance/screens/admin/set_attendance_window_sheet.dart';
import 'package:attendance/screens/profile/appearance_screen.dart';
import 'package:attendance/screens/profile/profile_details_screen.dart';
import 'package:attendance/screens/profile/settings_screen.dart';
import 'package:attendance/services/local_storage_service.dart';
import 'package:attendance/widgets/app_identity_footer.dart';
import 'package:attendance/widgets/user-profile/profile_header.dart';
import 'package:attendance/widgets/user-profile/profile_menu_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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

  test('each mode persists and is restored by a fresh provider', () async {
    final provider = ThemeProvider();
    await provider.ready;
    expect(provider.mode, ThemeMode.system);
    for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
      await provider.select(mode);
      final restarted = ThemeProvider();
      await restarted.ready;
      expect(restarted.mode, mode);
      restarted.dispose();
    }
    provider.dispose();
  });

  test(
    'palettes persist independently of an existing brightness choice',
    () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final provider = ThemeProvider();
      addTearDown(provider.dispose);
      await provider.ready;
      expect(provider.palette, AppPalette.olive);
      expect(provider.mode, ThemeMode.dark);

      for (final palette in AppPalette.values.reversed) {
        await provider.selectPalette(palette);
        final restored = ThemeProvider();
        addTearDown(restored.dispose);
        await restored.ready;
        expect(restored.palette, palette);
        expect(restored.mode, ThemeMode.dark);
      }
    },
  );

  testWidgets('Settings and Appearance fit at 320dp with 2x text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => _TestAuth()),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const AttendanceApp(),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushReplacement<void, void>(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
    await tester.pumpAndSettle();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 560);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(find.text('Sample Employee'), findsOneWidget);

    expect(find.byType(Switch), findsNothing);
    await _scrollTo(tester, find.text('Theme'));
    await tester.tap(find.text('Theme').hitTestable());
    await tester.pumpAndSettle();
    final appearance = find.byType(AppearanceScreen);
    expect(appearance, findsOneWidget);
    expect(Theme.of(tester.element(appearance)).brightness, Brightness.light);

    final preview = find.text('Preview theme');
    await _scrollTo(tester, preview);
    await tester.tap(preview.hitTestable());
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    final checkIn = find.descendant(of: sheet, matching: find.text('Check in'));
    expect(tester.widget<Text>(checkIn).style!.color, Colors.white);
    final previewDark = find.descendant(of: sheet, matching: find.text('Dark'));
    await tester.tap(previewDark);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(checkIn).style!.color, const Color(0xFF252B17));
    expect(Theme.of(tester.element(appearance)).brightness, Brightness.light);
    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Dark'));
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(appearance)).brightness, Brightness.dark);
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(appearance)).brightness, Brightness.light);
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(appearance)).brightness, Brightness.dark);

    final tide = find.text('Tide');
    await _scrollTo(tester, tide);
    await tester.tap(tide.hitTestable());
    await tester.pumpAndSettle();
    final tideDark = AppTheme.forPalette(AppPalette.tide, Brightness.dark);
    expect(
      Theme.of(tester.element(appearance)).colorScheme,
      tideDark.colorScheme,
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );

    await Scrollable.ensureVisible(tester.element(preview), alignment: .45);
    await tester.pumpAndSettle();
    await tester.tap(preview.hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Tide preview'), findsOneWidget);
    expect(
      tester.widget<Text>(checkIn).style!.color,
      tideDark.colorScheme.onPrimary,
    );
    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await _scrollTo(tester, find.textContaining('Build 6'));
    expect(find.textContaining('Version 1.1.0'), findsOneWidget);
    expect(find.byType(AttendanceMark), findsOneWidget);
    expect(find.text('Crafted by'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('developer-credit-photo')),
      findsOneWidget,
    );
    expect(find.text('Umer Jamshaid'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Umer Jamshaid')).style!.fontFamily,
      'Nanum Pen Script',
    );
    final whatsNew = find.text("What's new");
    await _scrollTo(tester, whatsNew);
    await tester.tap(whatsNew.hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Version 1.1.0 (Build 6)'), findsOneWidget);
    expect(
      find.text('Faster Office Switch', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('Clearer Graphite dividers', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('New Settings sheets', findRichText: true),
      findsOneWidget,
    );
    for (final title in [
      'Interactive maker credits',
      'Office invitations',
      'New app icon',
      'Color palettes',
      'Startup recovery',
    ]) {
      expect(find.text(title, findRichText: true), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile details save only after edits and sign-out asks first', (
    tester,
  ) async {
    final auth = _TestAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile details'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileDetailsScreen), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    final save = find.widgetWithText(FilledButton, 'Save changes');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(find.widgetWithText(InputChip, 'Design'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove Old tag'));
    await tester.pump();
    expect(find.widgetWithText(InputChip, 'Old tag'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'Team lead');
    await tester.enterText(find.byType(TextField).last, 'design, Team mentor');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Add tag'));
    await tester.tap(find.byTooltip('Add tag'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'Team mentor'), findsOneWidget);
    expect(find.byType(InputChip), findsNWidgets(2));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(auth.savedHeadline, 'Team lead');
    expect(auth.savedChips, ['Design', 'Team mentor']);

    final signOut = find.text('Sign out');
    await _scrollTo(tester, signOut);
    await tester.tap(signOut.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 0);

    await tester.tap(signOut.hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(BottomSheet), matching: signOut),
    );
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 1);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('Help, About and credits open sheets with large Graphite text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 540);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => _TestAuth()),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.forPalette(AppPalette.graphite, Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    Finder inSheet(String text) =>
        find.descendant(of: sheet, matching: find.text(text));

    await _scrollTo(tester, find.text('Help Centre'));
    await tester.tap(find.text('Help Centre').hitTestable());
    await tester.pumpAndSettle();
    expect(inSheet(AppInfo.supportEmail), findsOneWidget);
    expect(inSheet('Email Umer'), findsOneWidget);
    expect(inSheet('GitHub profile'), findsOneWidget);
    final copy = inSheet('Copy email address');
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(copied, AppInfo.supportEmail);
    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('About app'));
    await tester.tap(find.text('About app').hitTestable());
    await tester.pumpAndSettle();
    expect(inSheet('Version 1.1.0 (Build 6)'), findsOneWidget);
    expect(inSheet('Source on GitHub'), findsOneWidget);
    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();

    final credit = find.text('Crafted by');
    await _scrollTo(tester, credit);
    await tester.tap(credit.hitTestable());
    await tester.pumpAndSettle();
    expect(inSheet(AppInfo.maker), findsOneWidget);
    expect(inSheet('GitHub profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile metadata stays ahead of distinct personal tags', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ProfileProvider(),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              children: [
                ProfileHeader(
                  employee: Employee(
                    id: 'EMP001',
                    name: 'Sample Employee',
                    email: 'sample@example.com',
                    role: 'admin',
                    department: 'Engineering',
                    time: '',
                    headline: 'Team lead',
                    chips: const [
                      'engineering',
                      'Mentor',
                      'mentor',
                      'Accessibility advocate',
                    ],
                  ),
                  todayStatus: TodayStatus.present,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Engineering'), findsOneWidget);
    expect(find.text('engineering'), findsNothing);
    expect(find.text('Mentor'), findsOneWidget);
    expect(find.text('mentor'), findsNothing);
    final headline = tester.getTopLeft(find.text('Team lead')).dy;
    expect(tester.getTopLeft(find.text('Admin')).dy, lessThan(headline));
    expect(find.byIcon(AppIcons.shieldCheck), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Present today')).dy,
      lessThan(headline),
    );
    expect(tester.getTopLeft(find.text('Mentor')).dy, greaterThan(headline));
    expect(tester.takeException(), isNull);
  });
  testWidgets('attendance mode uses the segmented selector and persists', (
    tester,
  ) async {
    final attendance = AttendanceProvider();
    addTearDown(attendance.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: attendance,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const SetAttendanceWindowSheet(),
                ),
                child: const Text('Open attendance window'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open attendance window'));
    await tester.pumpAndSettle();
    final selector = find.byType(SegmentedButton<bool>);
    expect(find.byType(Switch), findsNothing);
    expect(tester.widget<SegmentedButton<bool>>(selector).selected, {false});
    expect(find.text('Start time'), findsOneWidget);
    await tester.tap(find.text('Always open'));
    await tester.pumpAndSettle();
    expect(tester.widget<SegmentedButton<bool>>(selector).selected, {true});
    expect(find.text('Start time'), findsNothing);
    await tester.tap(find.text('Save window'));
    await tester.pumpAndSettle();
    expect(attendance.windowMode, 'always');
    expect(
      (await LocalStorageService().getAttendanceWindow())?['mode'],
      'always',
    );
  });

  testWidgets('notification toggle has check and close thumb icons', (
    tester,
  ) async {
    var enabled = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ProfileSwitchItem(
              icon: AppIcons.bellRinging,
              title: 'Push notifications',
              value: enabled,
              onChanged: (value) => setState(() => enabled = value),
            ),
          ),
        ),
      ),
    );
    final toggle = find.byType(Switch);
    expect(
      tester.widget<Switch>(toggle).thumbIcon?.resolve({
        WidgetState.selected,
      })?.icon,
      AppIcons.check,
    );
    await tester.tap(find.text('Push notifications'));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, isFalse);
    expect(
      tester.widget<Switch>(toggle).thumbIcon?.resolve({})?.icon,
      AppIcons.x,
    );
  });
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  final viewport = tester.getRect(find.byType(ListView).first);
  for (var i = 0; i < 15 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.dragFrom(
      Offset(viewport.center.dx, viewport.bottom - 110),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
}

class _TestAuth extends AuthProvider {
  int signOutCalls = 0;
  String? savedHeadline;
  List<String>? savedChips;

  @override
  final currentUser = Employee(
    id: 'EMP002',
    name: 'Sample Employee',
    email: 'employee@example.com',
    role: 'employee',
    department: 'Design',
    time: '',
    chips: const ['Design', 'Old tag'],
  );

  @override
  Future<void> logout() async => signOutCalls++;

  @override
  Future<void> updateProfile({
    String? name,
    String? email,
    String? headline,
    List<String>? chips,
  }) async {
    savedHeadline = headline;
    savedChips = chips;
  }
}
