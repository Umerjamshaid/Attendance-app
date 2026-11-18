import 'dart:async';

import 'package:attendance/app.dart';
import 'package:attendance/bootstrap.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/theme_provider.dart';
import 'package:attendance/screens/login/login_screen.dart';
import 'package:attendance/screens/splash/launch_failure_screen.dart';
import 'package:attendance/services/launch_failure_reporter.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StartupAuth extends AuthProvider {
  _StartupAuth() : super(backend: PreviewCompanyBackend(available: false));

  AuthStatus startupStatus = AuthStatus.initial;
  @override
  AuthStatus get status => startupStatus;

  void finish() {
    startupStatus = AuthStatus.unauthenticated;
    notifyListeners();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget launch(
    _StartupAuth auth,
    VoidCallback ready, {
    ValueChanged<LaunchFailureReason>? report,
  }) => MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ],
    child: AttendanceApp(onReady: ready, onLaunchFailure: report),
  );

  testWidgets('native launch hold releases once after routing is ready', (
    tester,
  ) async {
    final auth = _StartupAuth();
    addTearDown(auth.dispose);
    var releases = 0;
    final reports = <LaunchFailureReason>[];
    await tester.pumpWidget(
      launch(auth, () => releases++, report: reports.add),
    );
    await tester.pump();
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(releases, 0);
    auth.finish();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(releases, 1);
    await tester.pump(const Duration(seconds: 12));
    expect(releases, 1);
    expect(find.byType(LaunchFailureScreen), findsNothing);
    expect(reports, isEmpty);
  });

  testWidgets('stalled session restoration releases to startup failure', (
    tester,
  ) async {
    final auth = _StartupAuth();
    addTearDown(auth.dispose);
    var releases = 0;
    final reports = <LaunchFailureReason>[];
    await tester.pumpWidget(
      launch(auth, () => releases++, report: reports.add),
    );
    await tester.pump(const Duration(seconds: 12));
    expect(releases, 1);
    expect(find.text("Attendance couldn't start"), findsOneWidget);
    expect(find.text('Close the app, then open it again.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 12));
    expect(reports, [LaunchFailureReason.routeTimeout]);
  });

  testWidgets('pre-run error renders failure without exposing its message', (
    tester,
  ) async {
    final captured = <FlutterErrorDetails>[];
    final reports = <LaunchFailureReason>[];
    final upload = Completer<void>();
    final previous = FlutterError.onError;
    FlutterError.onError = captured.add;
    try {
      await AttendanceBootstrap.run(
        () async => throw StateError('fixture key'),
        reportFailure: (reason) {
          reports.add(reason);
          return upload.future;
        },
      );
    } finally {
      FlutterError.onError = previous;
    }
    await tester.pumpAndSettle();
    expect(find.byType(LaunchFailureScreen), findsOneWidget);
    expect(find.textContaining('fixture key'), findsNothing);
    expect(captured.single.exceptionAsString(), isNot(contains('fixture key')));
    expect(reports, [LaunchFailureReason.initializationError]);
    upload.complete();
    await tester.pump();
  });
}
