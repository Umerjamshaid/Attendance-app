import 'package:attendance/config/app_theme.dart';
import 'package:attendance/screens/splash/splash_screen.dart';
import 'package:attendance/widgets/app_identity_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Attendance',
      packageName: 'test.attendance',
      version: '2.4.0',
      buildNumber: '42',
      buildSignature: '',
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('splash retains the installed build in ${brightness.name}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final reduceMotion = brightness == Brightness.dark;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          darkTheme: AppTheme.darkTheme,
          themeMode: reduceMotion ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: reduceMotion,
            ),
            child: child!,
          ),
          home: const SplashScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final mark = find.byType(AttendanceMark);
      final credit = find.text('Umer Jamshaid');
      expect(mark, findsOneWidget);
      expect(find.textContaining('Version 2.4.0 (Build 42)'), findsOneWidget);
      expect(credit, findsOneWidget);
      expect(
        find.byKey(const ValueKey('developer-credit-photo')),
        findsOneWidget,
      );
      expect(
        tester.getBottomLeft(mark).dy,
        lessThan(tester.getTopLeft(credit).dy),
      );
      expect(tester.getBottomLeft(credit).dy, lessThan(420));
      expect(
        find.byType(CircularProgressIndicator),
        reduceMotion ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
