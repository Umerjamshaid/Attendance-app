import 'dart:async';

import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/theme_provider.dart';
import 'package:attendance/screens/app_shell.dart';
import 'package:attendance/screens/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'config/app_info.dart';
import 'screens/login/password_setup_screen.dart';
import 'screens/splash/launch_failure_screen.dart';
import 'services/launch_failure_reporter.dart';
import 'widgets/office/office_scope.dart';
import 'widgets/app_toast.dart';

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key, this.onReady, this.onLaunchFailure});

  final VoidCallback? onReady;
  final ValueChanged<LaunchFailureReason>? onLaunchFailure;

  @override
  Widget build(BuildContext context) {
    final (mode, palette) = context.select(
      (ThemeProvider provider) => (provider.mode, provider.palette),
    );
    return MaterialApp(
      title: AppInfo.name,
      theme: AppTheme.forPalette(palette, Brightness.light),
      darkTheme: AppTheme.forPalette(palette, Brightness.dark),
      themeMode: mode,
      themeAnimationDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => AppToastHost(
        scopeKey: context.select((AuthProvider auth) => auth.officeScopeKey),
        child: child ?? const SizedBox.shrink(),
      ),
      home: _LaunchGate(onReady: onReady, onLaunchFailure: onLaunchFailure),
    );
  }
}

class _LaunchGate extends StatefulWidget {
  const _LaunchGate({this.onReady, this.onLaunchFailure});

  final VoidCallback? onReady;
  final ValueChanged<LaunchFailureReason>? onLaunchFailure;

  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate> {
  Timer? _deadline;
  bool _timedOut = false;
  bool _released = false;

  @override
  void initState() {
    super.initState();
    if (widget.onReady != null) {
      _deadline = Timer(const Duration(seconds: 12), () {
        setState(() => _timedOut = true);
      });
    }
  }

  @override
  void dispose() {
    _deadline?.cancel();
    super.dispose();
  }

  void _releaseAfterLayout({bool timedOut = false}) {
    if (_released) return;
    _released = true;
    _deadline?.cancel();
    final ready = widget.onReady;
    final reportFailure = widget.onLaunchFailure;
    if (ready != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ready();
        if (timedOut) reportFailure?.call(LaunchFailureReason.routeTimeout);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeRestoring = context.select((ThemeProvider theme) => theme.busy);
    final sessionRestoring =
        auth.status == AuthStatus.initial && !auth.needsPasswordSetup;
    final holdingNative = !_released && widget.onReady != null;
    if (holdingNative && (themeRestoring || sessionRestoring)) {
      if (!_timedOut) return const Scaffold();
      _releaseAfterLayout(timedOut: true);
      return const LaunchFailureScreen();
    }
    _releaseAfterLayout();
    if (auth.needsPasswordSetup) return const PasswordSetupScreen();
    return switch (auth.status) {
      AuthStatus.initial when _timedOut => const LaunchFailureScreen(),
      AuthStatus.initial => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      AuthStatus.authenticated => const OfficeScope(child: AppShell()),
      _ => const LoginScreen(),
    };
  }
}
