import 'package:attendance/config/app_icons.dart';
// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:attendance/app.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/providers/admin_provider.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/providers/theme_provider.dart';
import 'package:attendance/screens/login/login_screen.dart';
import 'package:attendance/widgets/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Login uses both app themes at 320dp with 2x text', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 560);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => AttendanceProvider()),
          ChangeNotifierProvider(create: (_) => AttendanceHistoryProvider()),
          ChangeNotifierProvider(create: (_) => AdminProvider()),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ],
        child: const AttendanceApp(),
      ),
    );

    // Verify widget tree pumped
    expect(find.byType(AttendanceApp), findsOneWidget);

    // Let async login check complete and pump frames
    await tester.pumpAndSettle();

    final login = find.byType(LoginScreen);
    final scaffold = find.descendant(
      of: login,
      matching: find.byType(Scaffold),
    );
    expect(
      tester.widget<Scaffold>(scaffold).backgroundColor,
      AppTheme.darkTheme.colorScheme.surface,
    );
    await tester.element(login).read<ThemeProvider>().select(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Scaffold>(scaffold).backgroundColor,
      AppTheme.theme.colorScheme.surface,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('BottomNav renders tabs and responds to taps', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 560);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    int tappedIndex = -1;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          bottomNavigationBar: BottomNav(
            currentIndex: 0,
            onTap: (index) => tappedIndex = index,
            isAdmin: true,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Home'), findsOneWidget);
    expect(find.byTooltip('History'), findsOneWidget);
    expect(find.byTooltip('Admin'), findsOneWidget);

    // Tap the History destination.
    await tester.tap(find.byIcon(AppIcons.clock));
    await tester.pumpAndSettle();

    expect(tappedIndex, 1);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BottomNav(currentIndex: 2, onTap: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Admin'), findsNothing);
    expect(find.byTooltip('Profile'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Profile' &&
            widget.properties.selected == true,
      ),
      findsOneWidget,
    );
  });
}
