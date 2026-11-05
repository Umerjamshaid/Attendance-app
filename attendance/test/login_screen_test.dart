import 'dart:async';

import 'package:attendance/config/app_theme.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/screens/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final dark in [false, true]) {
    testWidgets('login onboarding reference - ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_login(dark: dark));
      await tester.pumpAndSettle();
      final action = find.byType(FilledButton);
      expect(tester.getBottomLeft(action).dy, greaterThan(700));
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      await expectLater(
        find.byKey(const ValueKey('login-preview')),
        matchesGoldenFile('goldens/login_${dark ? 'dark' : 'light'}.png'),
      );
    });
  }

  testWidgets('one submission at a time, with empty-ID and server feedback', (
    tester,
  ) async {
    final auth = _LoginAuth();
    addTearDown(auth.dispose);
    var signedIn = 0;
    await tester.pumpWidget(_login(auth: auth, onSuccess: () => signedIn++));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Enter your employee ID.'), findsOneWidget);
    expect(auth.calls, 0);
    await tester.enterText(find.byType(TextField), 'emp002');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(auth.lastId, 'EMP002');
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(auth.calls, 1);
    auth.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Employee ID not found.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    auth.complete(true);
    await tester.pumpAndSettle();
    expect(signedIn, 1);
  });

  testWidgets('keyboard and 2x text keep the action reachable at 320dp', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_login(scale: 2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _login({
  bool dark = false,
  double scale = 1,
  _LoginAuth? auth,
  VoidCallback? onSuccess,
}) {
  final theme = dark ? AppTheme.darkTheme : AppTheme.theme;
  final page = RepaintBoundary(
    key: const ValueKey('login-preview'),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: LoginScreen(onLoginSuccess: onSuccess),
    ),
  );
  return auth == null
      ? ChangeNotifierProvider<AuthProvider>(
          create: (_) => _LoginAuth(),
          child: page,
        )
      : ChangeNotifierProvider<AuthProvider>.value(value: auth, child: page);
}

class _LoginAuth extends AuthProvider {
  AuthStatus _state = AuthStatus.unauthenticated;
  Completer<bool>? _request;
  int calls = 0;
  String? lastId;

  @override
  AuthStatus get status => _state;

  @override
  String? get error => 'Employee ID not found.';

  @override
  Future<bool> login(String employeeId, {String password = ''}) {
    calls++;
    lastId = employeeId;
    _state = AuthStatus.authenticating;
    _request = Completer<bool>();
    notifyListeners();
    return _request!.future;
  }

  void complete(bool success) {
    _state = success ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    _request!.complete(success);
    notifyListeners();
  }
}
