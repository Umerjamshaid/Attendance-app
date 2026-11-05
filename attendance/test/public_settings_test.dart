import 'package:attendance/config/app_theme.dart';
import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/providers/theme_provider.dart';
import 'package:attendance/screens/profile/settings_screen.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    PackageInfo.setMockInitialValues(
      appName: 'Attendance',
      packageName: 'test.attendance',
      version: '1.1.0',
      buildNumber: '6',
      buildSignature: '',
    );
  });
  for (final brightness in Brightness.values) {
    testWidgets('public Settings ${brightness.name} reference', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final backend = _PublicBackend();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AuthProvider(backend: backend),
            ),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(
              create: (_) => ProfileProvider(backend: backend),
            ),
            ChangeNotifierProvider(
              create: (_) => AttendanceProvider(backend: backend),
            ),
          ],
          child: MaterialApp(
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
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Account & security'), findsOneWidget);
      await expectLater(
        find.byType(SettingsScreen),
        matchesGoldenFile('goldens/public_settings_${brightness.name}.png'),
      );
      tester.view.physicalSize = const Size(320, 560);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

class _PublicBackend extends PreviewCompanyBackend {
  @override
  bool get isPreview => false;
}
