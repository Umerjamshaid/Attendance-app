import 'dart:async';

import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/screens/office/office_roles_screen.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:attendance/widgets/app_toast.dart';
import 'package:attendance/widgets/office/office_role_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_fonts.dart';

final _employee = Employee(
  id: 'EMP002',
  authUserId: 'employee-user',
  organizationId: 'office-a',
  officeName: 'Office A',
  name: 'Jordan Lee',
  email: 'jordan@example.invalid',
  role: 'employee',
  department: 'Design',
  time: '',
);

Finder get _sheet => find.byType(OfficeRoleSheet);
Finder _option(String text) =>
    find.descendant(of: _sheet, matching: find.text(text));
Finder get _save =>
    find.descendant(of: _sheet, matching: find.byType(FilledButton));

Future<void> _openConfirmation(WidgetTester tester) async {
  await tester.tap(find.text('Save changes'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  setUpAll(loadTestFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(
    WidgetTester tester,
    _Backend backend, {
    bool dark = false,
  }) async {
    final auth = AuthProvider(backend: backend);
    addTearDown(auth.dispose);
    await auth.refreshSession();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.darkTheme : AppTheme.theme,
          builder: (context, child) => RepaintBoundary(
            key: const ValueKey('role-preview'),
            child: AppToastHost(scopeKey: 'office-a', child: child!),
          ),
          home: const OfficeRolesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(backend.employee.isAdmin ? 'Administrator' : 'Employee'),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('role drafts require a change and confirmation before saving', (
    tester,
  ) async {
    final backend = _Backend()..saveGate = Completer<void>();
    await mount(tester, backend);
    expect(tester.widget<FilledButton>(_save).onPressed, isNull);
    await tester.tap(_option('Administrator'));
    await tester.pumpAndSettle();
    expect(_sheet, findsOneWidget);
    expect(backend.changes, isEmpty);
    await _openConfirmation(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(backend.changes, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(_sheet, findsOneWidget);
    expect(backend.employee.role, 'employee');
    await _openConfirmation(tester);
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<FilledButton>(_save).onPressed, isNull);
    expect(backend.changes, [('employee-user', 'admin')]);
    backend.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(_sheet, findsNothing);
    expect(find.text('Administrator'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('server role rejection keeps the sheet open and permits retry', (
    tester,
  ) async {
    final backend = _Backend()
      ..employee = _employee.copyWith(role: 'admin')
      ..failure = 'The last active administrator must keep their role.';
    await mount(tester, backend);
    await tester.tap(_option('Employee'));
    await tester.pumpAndSettle();
    await _openConfirmation(tester);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text(backend.failure!), findsOneWidget);
    expect(_sheet, findsOneWidget);
    expect(backend.employee.role, 'admin');
    expect(tester.widget<FilledButton>(_save).onPressed, isNotNull);
    backend.failure = null;
    await _openConfirmation(tester);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(_sheet, findsNothing);
    expect(backend.employee.role, 'employee');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dismissal during a save still refreshes the parent role list', (
    tester,
  ) async {
    final backend = _Backend()..saveGate = Completer<void>();
    await mount(tester, backend);
    await tester.tap(_option('Administrator'));
    await tester.pumpAndSettle();
    await _openConfirmation(tester);
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    Navigator.of(tester.element(_sheet)).pop();
    await tester.pumpAndSettle();
    backend.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Administrator'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'role sheet ${dark ? 'dark' : 'light'} reference and large text',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        await mount(tester, _Backend(), dark: dark);
        await expectLater(
          find.byKey(const ValueKey('role-preview')),
          matchesGoldenFile(
            'goldens/office_role_${dark ? 'dark' : 'light'}.png',
          ),
        );
        tester.view.physicalSize = const Size(320, 600);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save changes'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

class _Backend extends PreviewCompanyBackend {
  Employee employee = _employee;
  Completer<void>? saveGate;
  String? failure;
  final changes = <(String, String)>[];
  @override
  bool get isPreview => false;
  @override
  CompanyBackend forOffice(Employee employee) => this;
  @override
  Future<Employee?> restoreSession() async =>
      _employee.copyWith(id: 'OWNER', authUserId: 'owner-user', role: 'admin');
  @override
  Future<List<Employee>> employees() async => [employee];
  @override
  Future<void> setEmployeeRole(String userId, String role) async {
    changes.add((userId, role));
    await saveGate?.future;
    if (failure != null) throw CompanyException(failure!);
    employee = employee.copyWith(role: role);
  }
}
