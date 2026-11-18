import 'dart:async';

import 'package:attendance/app.dart';
import 'package:attendance/config/backend_config.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/theme_provider.dart';
import 'package:attendance/screens/login/email_code_screen.dart';
import 'package:attendance/screens/login/password_setup_screen.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Backend extends PreviewCompanyBackend {
  final events = StreamController<void>.broadcast();
  final emailRequest = Completer<void>();
  bool setup = false;
  int signOuts = 0;
  (String, String, CompanyEmailCode)? codeRequest;

  @override
  bool get isPreview => false;
  @override
  bool get needsPasswordSetup => setup;
  @override
  Stream<void> get authChanges => events.stream;
  @override
  Future<Employee?> restoreSession() async => null;
  @override
  Future<void> resetPassword(String email) => emailRequest.future;
  @override
  Future<void> signOut() async {
    signOuts++;
    setup = false;
    events.add(null);
  }

  @override
  Future<void> verifyEmailCode(
    String email,
    String code,
    CompanyEmailCode type,
  ) async {
    codeRequest = (email, code, type);
    throw const CompanyException('The code has expired.');
  }

  void openRecoveryLink() {
    setup = true;
    events.add(null);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_Backend> mount(WidgetTester tester, {bool narrow = false}) async {
    final backend = _Backend();
    addTearDown(backend.events.close);
    if (narrow) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider(backend: backend)),
        ],
        child: const AttendanceApp(),
      ),
    );
    await tester.pumpAndSettle();
    return backend;
  }

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

  test('only the registered app auth callback is accepted', () {
    for (final valid in [
      'workcheck://auth/callback?code=test',
      'workcheck://auth/callback#error=expired',
    ]) {
      expect(BackendConfig.isAuthCallback(Uri.parse(valid)), isTrue);
    }
    for (final invalid in [
      'https://auth/callback?code=test',
      'workcheck://other/callback',
      'workcheck://auth/callback-extra',
    ]) {
      expect(BackendConfig.isAuthCallback(Uri.parse(invalid)), isFalse);
    }
  });

  testWidgets('a warm recovery link dismisses the pending email form', (
    tester,
  ) async {
    final backend = await mount(tester);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Work email'), 'employee@example.invalid');
    await tester.tap(find.text('Send recovery email'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    backend.openRecoveryLink();
    await tester.pumpAndSettle();
    expect(find.byType(PasswordSetupScreen), findsOneWidget);
    expect(find.text('Reset password'), findsNothing);
    backend.emailRequest.complete();
    await tester.pumpAndSettle();
    expect(find.byType(PasswordSetupScreen), findsOneWidget);
    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    expect(find.byType(PasswordSetupScreen), findsNothing);
    expect(backend.signOuts, 1);
  });

  testWidgets('link errors are safe and email code entry fits enlarged text', (
    tester,
  ) async {
    final backend = await mount(tester, narrow: true);
    backend.events.addError(StateError('internal details must not appear'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not open the sign-in link'),
      findsOneWidget,
    );
    expect(find.textContaining('internal details'), findsNothing);
    final useCode = find.text('Use email code');
    await tester.ensureVisible(useCode);
    await tester.pumpAndSettle();
    await tester.tap(useCode);
    await tester.pumpAndSettle();
    expect(find.byType(EmailCodeScreen), findsOneWidget);
    final submit = find.text('Verify code');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(backend.codeRequest, isNull);
    await tester.enterText(field('Work email'), 'employee@example.invalid');
    await tester.enterText(field('Code from email'), '123456');
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(backend.codeRequest, (
      'employee@example.invalid',
      '123456',
      CompanyEmailCode.invitation,
    ));
    expect(find.text('The code has expired.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
