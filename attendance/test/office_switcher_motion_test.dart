import 'dart:async';
import 'package:attendance/config/app_icons.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/office_provider.dart';
import 'package:attendance/screens/office/manage_offices_screen.dart';
import 'package:attendance/widgets/office/office_switcher_sheet.dart';
import 'package:attendance/widgets/office/office_selector_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'office_provider_test.dart' show ControlledOfficeBackend;
import 'support/test_fonts.dart';
import 'support/overview_fonts.dart';

Future<(AuthProvider, OfficeProvider)> _mount(
  WidgetTester tester,
  ControlledOfficeBackend backend,
) async {
  final auth = AuthProvider(backend: backend);
  await tester.pump();
  final offices = OfficeProvider(auth);
  await offices.reload();
  addTearDown(offices.dispose);
  addTearDown(auth.dispose);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: offices),
      ],
      child: MaterialApp(
        theme: AppTheme.theme,
        home: const Scaffold(body: OfficeSelectorHeader()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('office-selector')));
  await tester.pumpAndSettle();
  return (auth, offices);
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
    await loadOverviewFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Edit morphs the check to a bin without moving its touch target and selection flies back',
    (tester) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
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
      final backend = ControlledOfficeBackend();
      final (auth, _) = await _mount(tester, backend);
      final before = tester.getRect(
        find.byKey(const ValueKey('office-selection-a')),
      );
      await tester.tap(find.byKey(const ValueKey('office-switcher-edit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(
        find.byKey(const ValueKey('office-badge-morph-a')),
        findsOneWidget,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('office-remove-a'))),
        before,
      );
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.byIcon(AppIcons.trash), findsNWidgets(2));
      final title = tester.widget<Text>(find.text('Switch Office'));
      expect(title.style!.fontFamily, 'Office Inter');
      expect(title.style!.fontSize, 24);
      expect(title.style!.fontWeight, FontWeight.w600);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      backend.state.switchGate = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('office-option-b')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 210));
      expect(
        find.byKey(const ValueKey('office-flying-avatar')),
        findsOneWidget,
      );
      expect(
        tester
            .getRect(find.byType(OfficeSwitcherSheet))
            .contains(
              tester.getCenter(
                find.byKey(const ValueKey('office-flying-avatar')),
              ),
            ),
        isTrue,
      );
      backend.state.switchGate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byType(OfficeSwitcherSheet), findsOneWidget);
      expect(find.byKey(const ValueKey('office-flying-avatar')), findsNothing);
      expect(auth.currentUser!.organizationId, 'b');
      expect(find.text('Office B is active'), findsOneWidget);
      expect(
        haptics
            .where((value) => value == 'HapticFeedbackType.selectionClick')
            .length,
        3,
      );
      expect(haptics, contains('HapticFeedbackType.lightImpact'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed switching restores the grid and never dismisses the sheet',
    (tester) async {
      final backend = ControlledOfficeBackend();
      final (auth, _) = await _mount(tester, backend);
      backend.state.failSwitch = true;
      await tester.tap(find.byKey(const ValueKey('office-option-b')));
      await tester.pumpAndSettle();
      expect(auth.currentUser!.organizationId, 'a');
      expect(find.byType(OfficeSwitcherSheet), findsOneWidget);
      expect(find.byKey(const ValueKey('office-flying-avatar')), findsNothing);
      expect(
        find.descendant(
          of: find.byType(OfficeSwitcherSheet),
          matching: find.text('Offline'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'remove confirms device-only hiding and Manage Offices can restore it',
    (tester) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
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
      final backend = ControlledOfficeBackend();
      final (_, offices) = await _mount(tester, backend);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('office-remove-b')));
      await tester.pumpAndSettle();
      expect(find.text('Remove Office?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(offices.hiddenOffices, isEmpty);
      await tester.tap(find.byKey(const ValueKey('office-remove-b')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(offices.hiddenOffices.single.id, 'b');
      expect(find.byType(OfficeSwitcherSheet), findsOneWidget);
      expect((await backend.offices()).length, 2);
      expect(backend.state.switchCalls, 0);
      expect(
        haptics
            .where((value) => value == 'HapticFeedbackType.mediumImpact')
            .length,
        1,
      );
      await tester.ensureVisible(find.text('Manage Offices'));
      await tester.tap(find.text('Manage Offices'));
      await tester.pumpAndSettle();
      expect(find.byType(ManageOfficesScreen), findsOneWidget);
      expect(find.text('Hidden on this device'), findsOneWidget);
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(offices.hiddenOffices, isEmpty);
      expect(offices.offices.length, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
