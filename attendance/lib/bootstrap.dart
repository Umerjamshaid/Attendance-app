import 'dart:async';

import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/providers/office_provider.dart';
import 'package:attendance/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'config/app_theme.dart';
import 'screens/splash/launch_failure_screen.dart';
import 'services/company_backend.dart';
import 'services/launch_failure_reporter.dart';
import 'services/profile_image_cache.dart';
import 'widgets/office/office_scope.dart';

bool _animationLicenseRegistered = false;

abstract final class AttendanceBootstrap {
  static Future<void> run(
    Future<CompanyBackend> Function() initialize, {
    LaunchFailureSink reportFailure = LaunchFailureReporter.report,
  }) async {
    final binding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: binding);
    var reported = false;
    void reportOnce(LaunchFailureReason reason) {
      if (reported) return;
      reported = true;
      unawaited(
        Future<void>.sync(
          () => reportFailure(reason),
        ).catchError((Object _) {}),
      );
    }

    try {
      final backend = await initialize().timeout(const Duration(seconds: 8));
      runAttendanceApp(
        backend: backend,
        onReady: FlutterNativeSplash.remove,
        onLaunchFailure: reportOnce,
      );
    } catch (error, stack) {
      runApp(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          darkTheme: AppTheme.darkTheme,
          home: const LaunchFailureScreen(),
        ),
      );
      FlutterNativeSplash.remove();
      reportOnce(
        error is TimeoutException
            ? LaunchFailureReason.initializationTimeout
            : LaunchFailureReason.initializationError,
      );
      // Initialization exceptions can contain backend configuration.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError('Attendance could not initialize.'),
          stack: stack,
          library: 'Attendance startup',
        ),
      );
    }
  }
}

void runAttendanceApp({
  CompanyBackend? backend,
  VoidCallback? onReady,
  ValueChanged<LaunchFailureReason>? onLaunchFailure,
}) {
  unawaited(ProfileImageCache.retryFailedCleanups());
  if (!_animationLicenseRegistered) {
    _animationLicenseRegistered = true;
    LicenseRegistry.addLicense(() async* {
      for (final entry in {
        'Buzz design and animation adaptations':
            'assets/licenses/Buzz-Apache-2.0.txt',
        'Inter': 'assets/licenses/Inter-OFL.txt',
        'Nanum Pen Script': 'assets/fonts/OFL-NanumPenScript.txt',
      }.entries) {
        yield LicenseEntryWithLineBreaks([
          entry.key,
        ], await rootBundle.loadString(entry.value));
      }
    });
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(backend: backend)),
        ChangeNotifierProvider(
          create: (context) => OfficeProvider(context.read<AuthProvider>()),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return ChangeNotifierProvider(
            key: ValueKey(auth.accountScopeKey),
            lazy: false,
            create: (_) => ProfileProvider(
              backend: auth.accountBackend,
              imageViewer: auth.isPreview ? null : auth.currentUser?.authUserId,
            ),
            child: Provider(
              create: (_) => OfficeNavigatorController(),
              child: AttendanceApp(
                onReady: onReady,
                onLaunchFailure: onLaunchFailure,
              ),
            ),
          );
        },
      ),
    ),
  );
}
