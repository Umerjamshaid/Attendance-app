import 'dart:async';

import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/screens/login/login_screen.dart';
import 'package:attendance/screens/profile/account_edit_screen.dart';
import 'package:attendance/services/company_backend.dart';
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
      'company Login ${dark ? 'dark' : 'light'} design and responsive form',
      (tester) async {
        await _mount(tester, _Backend(), dark: dark);
        await expectLater(
          find.byType(LoginScreen),
          matchesGoldenFile(
            'goldens/company_login_${dark ? 'dark' : 'light'}.png',
          ),
        );
        for (final size in [const Size(320, 640), const Size(800, 600)]) {
          tester.view.physicalSize = size;
          tester.view.viewInsets = const FakeViewPadding(bottom: 250);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          await tester.pumpAndSettle();
          for (final control in [
            find.byType(FilledButton),
            find.text('Explore demo'),
          ]) {
            await tester.ensureVisible(control);
            await tester.pumpAndSettle();
            expect(control.hitTestable(), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'password visibility, next focus and existing validation stay intact',
    (tester) async {
      final backend = _Backend();
      await _mount(tester, backend);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Enter your work email.'), findsOneWidget);
      await tester.enterText(_field('Work email'), 'not-an-email');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Enter your email and password.'), findsOneWidget);
      expect(backend.signIns, isEmpty);
      await tester.enterText(_field('Work email'), 'alex@example.invalid');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(
        tester.widget<TextField>(_field('Password')).focusNode!.hasFocus,
        true,
      );
      await tester.enterText(_field('Password'), 'same password');
      expect(tester.widget<TextField>(_field('Password')).obscureText, true);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_field('Password')).obscureText, false);
      expect(
        tester.widget<TextField>(_field('Password')).controller!.text,
        'same password',
      );
      expect(
        tester.getSize(find.byTooltip('Hide password')).shortestSide,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_field('Password')).obscureText, true);
    },
  );

  testWidgets(
    'company sign-in sends the same credentials once and reports errors then success',
    (tester) async {
      final backend = _Backend()..pending = Completer<Employee>();
      var successes = 0;
      await _mount(tester, backend, onSuccess: () => successes++);
      await tester.enterText(_field('Work email'), '  alex@example.invalid  ');
      await tester.enterText(_field('Password'), 'test password');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(backend.signIns, [('alex@example.invalid', 'test password')]);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(tester.widget<TextField>(_field('Work email')).readOnly, true);
      expect(tester.widget<TextField>(_field('Password')).readOnly, true);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(backend.signIns.length, 1);
      backend.pending!.completeError(
        const CompanyException('Invalid credentials.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Invalid credentials.'), findsOneWidget);
      expect(successes, 0);
      backend.pending = null;
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(successes, 1);
      expect(backend.signIns.length, 2);
    },
  );

  testWidgets('forgot-password route retains the email and recovery action', (
    tester,
  ) async {
    final backend = _Backend();
    await _mount(tester, backend);
    await tester.enterText(_field('Work email'), 'alex@example.invalid');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountEditScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'alex@example.invalid',
    );
    await tester.ensureVisible(find.text('Send recovery email'));
    await tester.tap(find.text('Send recovery email'));
    await tester.pumpAndSettle();
    expect(backend.recoveryEmail, 'alex@example.invalid');
    expect(find.byType(AccountEditScreen), findsNothing);
    expect(
      find.text('If the account exists, a recovery email will arrive shortly.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'reduced motion is respected when changed during login entrance',
    (tester) async {
      final backend = _Backend();
      await _mount(tester, backend, reduced: false);
      await tester.pumpWidget(_app(backend, reduced: true));
      await tester.pump();
      final fade = find
          .descendant(
            of: find.byType(LoginScreen),
            matching: find.byType(FadeTransition),
          )
          .first;
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _mount(
  WidgetTester tester,
  _Backend backend, {
  bool dark = false,
  bool reduced = true,
  VoidCallback? onSuccess,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    _app(backend, dark: dark, reduced: reduced, onSuccess: onSuccess),
  );
  if (reduced) await tester.pumpAndSettle();
}

Widget _app(
  _Backend backend, {
  bool dark = false,
  bool reduced = true,
  VoidCallback? onSuccess,
}) => ChangeNotifierProvider(
  create: (_) => AuthProvider(backend: backend),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? AppTheme.darkTheme : AppTheme.theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: child!,
    ),
    home: LoginScreen(onLoginSuccess: onSuccess),
  ),
);

class _Backend extends PreviewCompanyBackend {
  final signIns = <(String, String)>[];
  Completer<Employee>? pending;
  String? recoveryEmail;
  @override
  bool get isPreview => false;
  @override
  Future<Employee?> restoreSession() async => null;
  @override
  Future<Employee> signIn(String email, String password) async {
    signIns.add((email, password));
    return pending == null
        ? (await PreviewCompanyBackend().restoreSession())!
        : await pending!.future;
  }

  @override
  Future<void> resetPassword(String email) async {
    recoveryEmail = email;
  }
}
