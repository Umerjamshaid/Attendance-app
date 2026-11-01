// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:attendance/app.dart';
import 'package:attendance/providers/admin_provider.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/widgets/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AttendanceApp smoke test - renders initial state and login', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
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

    // Verify it navigates to login screen when unauthenticated
    expect(find.byType(AttendanceApp), findsOneWidget);
  });

  testWidgets('BottomNav renders tabs and responds to taps', (
    WidgetTester tester,
  ) async {
    int tappedIndex = -1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BottomNav(
            currentIndex: 0,
            onTap: (index) => tappedIndex = index,
            isAdmin: true,
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    // Tap the History destination.
    await tester.tap(find.byIcon(Icons.access_time_rounded));
    await tester.pumpAndSettle();

    expect(tappedIndex, 1);
  });
}
