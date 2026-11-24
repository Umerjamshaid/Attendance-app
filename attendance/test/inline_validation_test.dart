import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/models/office_model.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/office_provider.dart';
import 'package:attendance/screens/admin/employee_management_screen.dart';
import 'package:attendance/screens/office/manage_offices_screen.dart';
import 'package:attendance/screens/profile/account_edit_screen.dart';
import 'package:attendance/screens/profile/profile_details_screen.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:attendance/widgets/error_shake.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_fonts.dart';

final _user = Employee(
  id: 'EMP1',
  authUserId: 'user-a',
  organizationId: 'a',
  name: 'Alex',
  email: 'alex@example.invalid',
  role: 'admin',
  department: '',
  time: '',
);

Finder _field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
double _offset(WidgetTester tester, Finder field) {
  final shake = find
      .ancestor(of: field, matching: find.byType(ErrorShake))
      .first;
  return tester
      .widget<Transform>(
        find.descendant(of: shake, matching: find.byType(Transform)).first,
      )
      .transform
      .storage[12];
}

class _Backend extends PreviewCompanyBackend {
  final invitations = <(String, String, String, String)>[];
  final creations = <String>[];
  String? failure;
  @override
  bool get isPreview => false;
  @override
  CompanyBackend forOffice(Employee employee) => this;
  @override
  Future<Employee?> restoreSession() async => _user;
  @override
  Future<List<Office>> offices() async => [
    const Office(id: 'a', name: 'Office A', role: 'admin'),
  ];
  @override
  Future<String> createOffice(String name) async {
    creations.add(name);
    return 'a';
  }

  @override
  Future<bool> invite({
    required String email,
    required String name,
    required String employeeCode,
    required String department,
  }) async {
    invitations.add((email, name, employeeCode, department));
    if (failure != null) throw CompanyException(failure!);
    return false;
  }
}

void main() {
  setUpAll(loadTestFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(
    WidgetTester tester,
    Widget screen, {
    bool dark = false,
    _Backend? backend,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final auth = AuthProvider(backend: backend ?? _Backend());
    await auth.refreshSession();
    final offices = OfficeProvider(auth);
    await offices.reload();
    addTearDown(() {
      offices.dispose();
      auth.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: offices),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.darkTheme : AppTheme.theme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => screen),
                ),
                child: const Text('Open form'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets(
      'single-field validation ${dark ? "dark" : "light"} is inline, repeatable and responsive',
      (tester) async {
        var saves = 0;
        await mount(
          tester,
          AccountEditScreen(
            title: 'Change email',
            label: 'Work email',
            email: true,
            initialValue: 'alex@example.invalid',
            onSave: (_) async {
              saves++;
            },
          ),
          dark: dark,
        );
        await tester.enterText(_field('Work email'), 'invalid');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();
        expect(find.text('Enter a valid work email.'), findsOneWidget);
        final theme = Theme.of(tester.element(_field('Work email')));
        final labelStyle =
            theme.inputDecorationTheme.labelStyle! as WidgetStateTextStyle;
        expect(
          labelStyle.resolve({WidgetState.error}).color,
          theme.colorScheme.error,
        );
        expect(
          labelStyle.resolve({}).color,
          theme.colorScheme.onSurfaceVariant,
        );
        expect(theme.inputDecorationTheme.floatingLabelStyle, same(labelStyle));
        expect(find.byType(SnackBar), findsNothing);
        expect(saves, 0);
        await expectLater(
          find.byType(Scaffold).last,
          matchesGoldenFile(
            'goldens/field_validation_${dark ? "dark" : "light"}.png',
          ),
        );
        await tester.tap(find.text('Save changes'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(_offset(tester, _field('Work email')), greaterThan(0));
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(320, 650);
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Enter a valid work email.'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'account save failure stays beside the input and clears on edit',
    (tester) async {
      var saves = 0;
      await mount(
        tester,
        AccountEditScreen(
          title: 'Display name',
          label: 'Display name',
          initialValue: 'Alex',
          onSave: (_) async {
            saves++;
            throw const CompanyException('Could not save. Try again.');
          },
        ),
      );
      await tester.enterText(_field('Display name'), 'Jordan');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Could not save. Try again.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(saves, 1);
      await tester.enterText(_field('Display name'), 'Alex');
      await tester.pumpAndSettle();
      expect(find.text('Could not save. Try again.'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'invite errors stay on their fields and retries preserve the existing payload',
    (tester) async {
      final backend = _Backend()..failure = 'Employee number already in use.';
      await mount(tester, const InviteEmployeeScreen(), backend: backend);
      await tester.ensureVisible(find.text('Send invitation'));
      await tester.tap(find.text('Send invitation'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsNWidgets(4));
      expect(backend.invitations, isEmpty);
      await tester.enterText(_field('Full name'), ' Jordan ');
      await tester.enterText(_field('Work email'), 'not-email');
      await tester.enterText(_field('Employee number'), 'bad code');
      await tester.enterText(_field('Department'), ' Engineering ');
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email.'), findsOneWidget);
      expect(
        find.text('Use letters, numbers, hyphens or underscores.'),
        findsOneWidget,
      );
      await tester.enterText(_field('Work email'), ' jordan@example.invalid ');
      await tester.enterText(_field('Employee number'), ' emp2 ');
      await tester.ensureVisible(find.text('Send invitation'));
      await tester.tap(find.text('Send invitation'));
      await tester.pumpAndSettle();
      expect(find.text(backend.failure!), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(backend.invitations.single, (
        'jordan@example.invalid',
        'Jordan',
        'EMP2',
        'Engineering',
      ));
      backend.failure = null;
      await tester.tap(find.text('Send invitation'));
      await tester.pumpAndSettle();
      expect(find.byType(InviteEmployeeScreen), findsNothing);
      expect(backend.invitations.length, 2);
    },
  );

  testWidgets('empty office name shakes without attempting an office write', (
    tester,
  ) async {
    final backend = _Backend();
    await mount(tester, const ManageOfficesScreen(), backend: backend);
    await tester.tap(find.text('Create Office'));
    await tester.pumpAndSettle();
    final create = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(FilledButton),
    );
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.text('Enter an office name'), findsOneWidget);
    expect(backend.creations, isEmpty);
    await tester.tap(create);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(_offset(tester, _field('Office name')), greaterThan(0));
    await tester.enterText(_field('Office name'), 'New office');
    await tester.pumpAndSettle();
    expect(find.text('Enter an office name'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(backend.creations, isEmpty);
  });

  testWidgets(
    'invalid tag remains editable and shakes rather than becoming a chip',
    (tester) async {
      await mount(tester, ProfileDetailsScreen(user: _user));
      final draft = _field('Add a tag');
      await tester.enterText(draft, 'x' * 41);
      await tester.pumpAndSettle();
      expect(
        find.text('Use up to 12 tags, each no longer than 40 characters.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Add tag'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(_offset(tester, draft), greaterThan(0));
      expect(find.byType(InputChip), findsNothing);
      await tester.enterText(draft, 'Mentor');
      await tester.tap(find.byTooltip('Add tag'));
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsOneWidget);
      expect(
        find.text('Use up to 12 tags, each no longer than 40 characters.'),
        findsNothing,
      );
    },
  );
}
