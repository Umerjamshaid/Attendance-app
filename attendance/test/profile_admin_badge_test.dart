import 'package:attendance/config/app_icons.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/widgets/user-profile/profile_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'office_provider_test.dart' show ControlledOfficeBackend;
import 'support/overview_fonts.dart';
import 'support/test_fonts.dart';

Employee _employee({String role = 'admin', bool active = true}) => Employee(
  id: 'EMP001',
  name: 'Taylor Morgan',
  email: 'taylor@example.invalid',
  department: 'Engineering',
  role: role,
  time: '',
  isActive: active,
);

Widget _app(ProfileProvider profile, Widget child, {bool dark = false}) =>
    ChangeNotifierProvider<ProfileProvider>.value(
      value: profile,
      child: MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.theme,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

Future<void> _waitForShield(WidgetTester tester) async {
  final rendered = find.descendant(
    of: find.byType(SvgPicture),
    matching: find.byType(FittedBox),
  );
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (rendered.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(
    rendered,
    findsOneWidget,
    reason: 'the bundled shield must finish painting',
  );
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
    await loadOverviewFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final dark in [false, true]) {
    testWidgets(
      'only the Admin chip icon changes in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final profile = ProfileProvider();
        addTearDown(profile.dispose);
        await tester.pumpWidget(
          _app(profile, ProfileHeader(employee: _employee()), dark: dark),
        );
        await tester.pumpAndSettle();

        await _waitForShield(tester);
        final shield = find.byType(SvgPicture);
        expect(shield, findsOneWidget);
        final image = tester.widget<SvgPicture>(shield);
        expect(
          (image.bytesLoader as SvgAssetLoader).assetName,
          'assets/badges/admin-prototype.svg',
        );
        expect(image.excludeFromSemantics, isTrue);
        expect(tester.getSize(shield), const Size(16, 16));
        expect(find.byIcon(AppIcons.idBadge2), findsNothing);
        final label = find.text('Admin');
        final chip = find
            .ancestor(of: label, matching: find.byType(Container))
            .first;
        final container = tester.widget<Container>(chip);
        final decoration = container.decoration! as BoxDecoration;
        expect(
          container.padding,
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        );
        expect(decoration.borderRadius, BorderRadius.circular(999));
        expect(
          decoration.color,
          Theme.of(
            tester.element(label),
          ).colorScheme.onSurface.withValues(alpha: .06),
        );
        expect(tester.getTopLeft(label).dx - tester.getTopRight(shield).dx, 6);
        expect(find.descendant(of: chip, matching: shield), findsOneWidget);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(
            'goldens/profile_admin_chip_${dark ? 'dark' : 'light'}.png',
          ),
        );

        tester.view.physicalSize = const Size(320, 800);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        await tester.pumpAndSettle();
        expect(tester.getSize(shield), const Size(16, 16));
        expect(find.text('Admin'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'employees, inactive admins and editable tags do not gain the badge',
    (tester) async {
      final profile = ProfileProvider();
      addTearDown(profile.dispose);
      for (final employee in [
        _employee(role: 'employee').copyWith(chips: ['Admin']),
        _employee(active: false),
      ]) {
        await tester.pumpWidget(
          _app(profile, ProfileHeader(employee: employee)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SvgPicture), findsNothing);
        expect(tester.widget<Icon>(find.byIcon(AppIcons.idBadge2)).size, 16);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'the existing office role drives the badge on switch and return',
    (tester) async {
      final auth = AuthProvider(backend: ControlledOfficeBackend());
      final profile = ProfileProvider();
      addTearDown(auth.dispose);
      addTearDown(profile.dispose);
      await auth.refreshSession();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: _app(
            profile,
            Consumer<AuthProvider>(
              builder: (_, auth, _) =>
                  ProfileHeader(employee: auth.currentUser!),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(auth.currentUser!.organizationId, 'a');
      expect(find.byType(SvgPicture), findsOneWidget);
      await auth.switchOffice('b');
      await tester.pumpAndSettle();
      expect(find.byType(SvgPicture), findsNothing);
      expect(find.text('Employee'), findsOneWidget);
      await auth.switchOffice('a');
      await tester.pumpAndSettle();
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
