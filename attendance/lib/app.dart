import 'dart:async';

import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/theme_provider.dart';
import 'package:attendance/screens/app_shell.dart';
import 'package:attendance/screens/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_theme.dart';
import 'config/app_info.dart';
import 'screens/login/password_setup_screen.dart';
import 'screens/profile/whats_new_screen.dart';
import 'screens/splash/launch_failure_screen.dart';
import 'screens/splash/offline_home_screen.dart';
import 'services/launch_failure_reporter.dart';
import 'services/network_status.dart';
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
        child: _NetworkNotice(child: child ?? const SizedBox.shrink()),
      ),
      home: _LaunchGate(onReady: onReady, onLaunchFailure: onLaunchFailure),
    );
  }
}

class _NetworkNotice extends StatefulWidget {
  const _NetworkNotice({required this.child});

  final Widget child;

  @override
  State<_NetworkNotice> createState() => _NetworkNoticeState();
}

class _NetworkNoticeState extends State<_NetworkNotice> {
  bool _offline = false;

  @override
  Widget build(BuildContext context) {
    final offline = context.select(
      (NetworkStatus? status) => status?.offline ?? false,
    );
    if (offline != _offline) {
      _offline = offline;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || offline != _offline) return;
        if (offline) {
          AppToast.of(context).showSnackBar(
            const SnackBar(content: Text(NetworkStatus.offlineMessage)),
          );
        } else {
          final auth = context.read<AuthProvider>();
          if (!auth.isPreview &&
              !auth.isAuthenticated &&
              auth.status != AuthStatus.authenticating) {
            unawaited(auth.refreshSession());
          }
        }
      });
    }
    return widget.child;
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
  static const _seenReleaseKey = 'last_seen_release';

  Timer? _deadline;
  bool _timedOut = false;
  bool _released = false;
  bool _checkedRelease = false;
  bool _checkingRelease = false;

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

  void _checkReleaseAfterLayout() {
    if (_checkedRelease || _checkingRelease) return;
    _checkingRelease = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_checkRelease());
    });
  }

  Future<void> _checkRelease() async {
    try {
      final (info, preferences) = await (
        PackageInfo.fromPlatform(),
        SharedPreferences.getInstance(),
      ).wait;
      final current = Version.parse(info.version);
      final saved = preferences.getString(_seenReleaseKey);
      // Older builds stored the build number along with the release version.
      final previous = saved == null
          ? null
          : Version.parse(saved.split('+').first);
      if (previous != null && current <= previous) {
        _checkedRelease = true;
        return;
      }

      // Older Attendance builds have no marker yet. Use OS install metadata
      // to distinguish an in-place update from a new install in that case.
      final installedAt = info.installTime;
      final updatedAt = info.updateTime;
      final isUpdate =
          previous != null ||
          (installedAt != null &&
              updatedAt != null &&
              updatedAt.isAfter(installedAt));
      if (isUpdate) {
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
        final auth = context.read<AuthProvider>();
        if (auth.status != AuthStatus.authenticated ||
            auth.needsPasswordSetup) {
          return;
        }
        await showWhatsNewSheet(context, info);
      }
      _checkedRelease = await preferences.setString(
        _seenReleaseKey,
        current.toString(),
      );
    } catch (_) {
      // Optional release notes must never block Home or the native splash.
    } finally {
      _checkingRelease = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeRestoring = context.select((ThemeProvider theme) => theme.busy);
    final offline = context.select(
      (NetworkStatus? status) => status?.offline ?? false,
    );
    if (offline &&
        !auth.isPreview &&
        (!auth.isAuthenticated || auth.needsPasswordSetup)) {
      _releaseAfterLayout();
      return const OfflineHomeScreen();
    }
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
    if (!themeRestoring &&
        auth.status == AuthStatus.authenticated &&
        ModalRoute.isCurrentOf(context) == true) {
      _checkReleaseAfterLayout();
    }
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
