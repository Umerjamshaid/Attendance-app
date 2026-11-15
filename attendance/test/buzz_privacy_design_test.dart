import 'package:attendance/config/app_theme.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/screens/profile/privacy_screen.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final dark in [false, true]) {
    testWidgets(
      'privacy preserves content and expansion in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 1000);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => AuthProvider(backend: PreviewCompanyBackend()),
            child: MaterialApp(
              theme: dark ? AppTheme.darkTheme : AppTheme.theme,
              home: const RepaintBoundary(
                key: ValueKey('privacy-preview'),
                child: PrivacyScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const ValueKey('privacy-preview')),
          matchesGoldenFile('goldens/privacy_${dark ? 'dark' : 'light'}.png'),
        );
        await tester.tap(find.text('Check-in photo'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('not used for advertising or profiling'),
          findsOneWidget,
        );
        tester.view.physicalSize = const Size(320, 1000);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Open system settings'));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
