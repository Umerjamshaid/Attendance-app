import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/theme_provider.dart';
import 'package:attendance/screens/app_shell.dart';
import 'package:attendance/screens/login/login_screen.dart';
import 'package:attendance/screens/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'screens/login/password_setup_screen.dart';
import 'widgets/office/office_scope.dart';

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      theme: AppTheme.theme,
      darkTheme: AppTheme.darkTheme,
      themeMode: context.select((ThemeProvider provider) => provider.mode),
      themeAnimationDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      debugShowCheckedModeBanner: false,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return switch (auth.status) {
            AuthStatus.initial => const SplashScreen(),
            AuthStatus.authenticated =>
              auth.needsPasswordSetup
                  ? const PasswordSetupScreen()
                  : const OfficeScope(child: AppShell()),
            _ => const LoginScreen(),
          };
        },
      ),
    );
  }
}
