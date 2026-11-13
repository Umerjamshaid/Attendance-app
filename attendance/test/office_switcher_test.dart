import 'package:attendance/config/app_theme.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/office_provider.dart';
import 'package:attendance/widgets/office/office_selector_header.dart';
import 'package:attendance/widgets/office/office_switcher_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final dark in [false, true]) {
    testWidgets('office header opens, selects and dismisses; dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final auth = AuthProvider(backend: ControlledOfficeBackend());
      await tester.pump();
      final offices = OfficeProvider(auth);
      await offices.reload();
      addTearDown(offices.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: offices),
          ],
          child: MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: RepaintBoundary(
                key: const ValueKey('office-test-surface'),
                child: child!,
              ),
            ),
            home: const Scaffold(body: OfficeSelectorHeader()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Office A'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('office-selector')));
      await tester.pumpAndSettle();
      expect(find.byType(OfficeSwitcherSheet), findsOneWidget);
      expect(find.text('Switch Office'), findsOneWidget);
      expect(find.text('Add Office'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('office-test-surface')),
        matchesGoldenFile(
          'goldens/office_switcher_${dark ? 'dark' : 'light'}.png',
        ),
      );
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Office B'));
      await tester.pumpAndSettle();
      expect(find.byType(OfficeSwitcherSheet), findsNothing);
      expect(find.text('Office B'), findsOneWidget);
      expect(auth.currentUser!.isAdmin, isFalse);
      await tester.tap(find.byKey(const ValueKey('office-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(OfficeSwitcherSheet), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
