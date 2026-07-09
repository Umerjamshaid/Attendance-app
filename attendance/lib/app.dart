import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/screens/app_shell.dart';
import 'package:attendance/screens/login/login_screen.dart';
import 'package:attendance/screens/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      theme: AppColors.dark == true ? ThemeData.dark() : ThemeData.light(),
      debugShowCheckedModeBanner: false,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.status == AuthStatus.initial) {
            return const SplashScreen();
          }
          return auth.isAuthenticated ? const AppShell() : const LoginScreen();
        },
      ),
    );
  }
}
