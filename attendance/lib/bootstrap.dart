import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/providers/office_provider.dart';
import 'package:attendance/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/company_backend.dart';
import 'widgets/office/office_scope.dart';

bool _animationLicenseRegistered = false;

void runAttendanceApp({CompanyBackend? backend}) {
  if (!_animationLicenseRegistered) {
    _animationLicenseRegistered = true;
    LicenseRegistry.addLicense(() async* {
      for (final entry in {
        'Buzz animation adaptations': 'assets/licenses/Buzz-Apache-2.0.txt',
        'Inter': 'assets/licenses/Inter-OFL.txt',
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
            create: (_) => ProfileProvider(backend: auth.accountBackend),
            child: Provider(
              create: (_) => OfficeNavigatorController(),
              child: const AttendanceApp(),
            ),
          );
        },
      ),
    ),
  );
}
