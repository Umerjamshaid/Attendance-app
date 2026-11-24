import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/office_model.dart';
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
  testWidgets('cached office rows open before any refresh or distant layout', (
    tester,
  ) async {
    final backend = ControlledOfficeBackend();
    backend.state.offices = [
      const Office(id: 'a', name: 'Office A', role: 'admin'),
      for (var i = 0; i < 20; i++)
        Office(id: 'office-$i', name: 'Office $i', role: 'employee'),
    ];
    final auth = AuthProvider(backend: backend);
    await tester.pump();
    final offices = _TrackedOfficeProvider(auth);
    await offices.reload();
    addTearDown(auth.dispose);
    addTearDown(offices.dispose);
    final reads = backend.state.officeCalls;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider<OfficeProvider>.value(value: offices),
        ],
        child: MaterialApp(
          theme: AppTheme.theme,
          home: const Scaffold(body: OfficeSelectorHeader()),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('office-selector')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Office 0'), findsOneWidget);
    expect(find.text('Office 19'), findsNothing);
    expect(backend.state.officeCalls, reads);
    expect(offices.entranceRefreshes, 0);
    await tester.pumpAndSettle();
    expect(offices.entranceRefreshes, 1);
    expect(backend.state.officeCalls, reads);
    await tester.scrollUntilVisible(find.text('Office 19'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Office 19').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
      expect(find.byType(OfficeSwitcherSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(OfficeSwitcherSheet),
          matching: find.text('Office B'),
        ),
        findsOneWidget,
      );
      expect(auth.currentUser!.isAdmin, isFalse);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(OfficeSwitcherSheet), findsNothing);
      expect(find.text('Office B'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

class _TrackedOfficeProvider extends OfficeProvider {
  _TrackedOfficeProvider(super.auth);

  int entranceRefreshes = 0;

  @override
  Future<void> refreshIfStale() {
    entranceRefreshes++;
    return super.refreshIfStale();
  }
}
