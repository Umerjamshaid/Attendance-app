import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../models/employees_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/user-profile/edit_profile_sheet.dart';
import '../admin/set_attendance_window_sheet.dart';
import 'appearance_screen.dart';
import 'privacy_screen.dart';
import 'profile_details_screen.dart';
import 'settings_layout.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Future<PackageInfo> _package = PackageInfo.fromPlatform();
  late var _permissions = _readPermissions();
  late final AppLifecycleListener _lifecycle;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refreshPermissions);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<List<PermissionStatus>> _readPermissions() => Future.wait([
    Permission.locationWhenInUse.status,
    Permission.camera.status,
  ]);

  void _refreshPermissions() => setState(() {
    _permissions = _readPermissions();
  });

  void _feedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openPermissions() async {
    try {
      if (await openAppSettings()) return;
    } catch (_) {
      // The platform may not provide an app settings destination.
    }
    _feedback('Could not open device settings.');
  }

  Future<void> _editProfile(Employee user) async {
    final auth = context.read<AuthProvider>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => EditProfileSheet(
        initialName: user.name,
        initialEmail: user.email,
        onSave: (name, email) => auth.updateProfile(name: name, email: email),
      ),
    );
    if (saved == true) _feedback('Profile saved.');
  }

  Future<void> _signOut() async {
    final auth = context.read<AuthProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await auth.logout();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      _feedback('Could not sign out. Try again.');
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  void _openWindow() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const SetAttendanceWindowSheet(),
    );
  }

  String _permissionLabel(
    AsyncSnapshot<List<PermissionStatus>> snapshot,
    int index,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return 'Checking access...';
    }
    if (!snapshot.hasData) return 'Status unavailable';
    return switch (snapshot.data![index]) {
      PermissionStatus.granted => 'Allowed',
      PermissionStatus.limited => 'Limited access',
      PermissionStatus.restricted => 'Restricted',
      PermissionStatus.provisional => 'Provisionally allowed',
      PermissionStatus.denied ||
      PermissionStatus.permanentlyDenied => 'Not allowed',
    };
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final mode = context.select((ThemeProvider provider) => provider.mode);
    final colors = Theme.of(context).colorScheme;
    final avatar = context.select(
      (ProfileProvider provider) => provider.pfpPath,
    );
    return SettingsLayout(
      title: 'Settings',
      close: true,
      children: [
        if (user != null) ...[
          _SettingsProfileHeader(
            user: user,
            path: avatar,
            edit: () => _editProfile(user),
          ),
          SettingsSection(
            title: 'Account',
            rows: [
              SettingsRow('Edit profile', onTap: () => _editProfile(user)),
              SettingsRow(
                'Profile details',
                onTap: () => ProfileDetailsScreen.open(context, user),
              ),
              SettingsRow('Employee ID', detail: user.id),
              if (user.department.isNotEmpty)
                SettingsRow('Department', detail: user.department),
              SettingsRow(
                _signingOut ? 'Signing out...' : 'Sign out',
                destructive: true,
                onTap: _signingOut ? null : _signOut,
              ),
            ],
          ),
        ],
        SettingsSection(
          title: 'Appearance',
          rows: [
            SettingsRow(
              'Theme',
              detail: themeModeLabel(mode),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const AppearanceScreen()),
              ),
            ),
          ],
        ),
        if (user?.isAdmin ?? false)
          Consumer<AttendanceProvider>(
            builder: (context, attendance, _) => SettingsSection(
              title: 'Attendance',
              rows: [
                SettingsRow(
                  'Attendance window',
                  detail: attendance.windowMode == 'always'
                      ? 'Always open'
                      : '${attendance.formatHour(attendance.windowStartHour)} to '
                            '${attendance.formatHour(attendance.windowEndHour)}',
                  onTap: _openWindow,
                ),
              ],
            ),
          ),
        FutureBuilder(
          future: _permissions,
          builder: (context, snapshot) => SettingsSection(
            title: 'Permissions',
            rows: [
              SettingsRow(
                'Location',
                detail: _permissionLabel(snapshot, 0),
                onTap: _openPermissions,
              ),
              SettingsRow(
                'Camera',
                detail: _permissionLabel(snapshot, 1),
                onTap: _openPermissions,
              ),
            ],
          ),
        ),
        SettingsSection(
          title: 'About',
          rows: [
            SettingsRow(
              'Privacy & security',
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const PrivacyScreen()),
              ),
            ),
          ],
        ),
        FutureBuilder(
          future: _package,
          builder: (context, snapshot) {
            final info = snapshot.data;
            return Text(
              info == null
                  ? 'Attendance'
                  : 'Attendance · Version ${info.version} (Build ${info.buildNumber})',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            );
          },
        ),
      ],
    );
  }
}

class _SettingsProfileHeader extends StatelessWidget {
  const _SettingsProfileHeader({
    required this.user,
    required this.path,
    required this.edit,
  });

  final Employee user;
  final String? path;
  final VoidCallback edit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = user.name.trim();
    final initials = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final fallback = Center(
      child: Text(
        initials,
        style: theme.textTheme.headlineMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Column(
        children: [
          IconButton(
            tooltip: 'Edit profile information',
            onPressed: edit,
            padding: EdgeInsets.zero,
            icon: ClipOval(
              child: SizedBox.square(
                dimension: 76,
                child: ColoredBox(
                  color: theme.colorScheme.primaryContainer,
                  child: path == null || path!.isEmpty
                      ? fallback
                      : Image.file(
                          File(path!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => fallback,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name.isEmpty ? user.id : name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email.trim().isEmpty ? user.id : user.email,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
