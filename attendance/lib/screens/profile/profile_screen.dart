import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/screens/admin/admin_notification_screen.dart';
import 'package:attendance/screens/profile/privacy_screen.dart';
import 'package:attendance/screens/profile/settings_screen.dart';
import 'package:attendance/widgets/user-profile/attendance_stats_card.dart';
import 'package:attendance/widgets/user-profile/profile_header.dart';
import 'package:attendance/widgets/user-profile/profile_menu_item.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;

  // Package info pakage for app version and build number
  String _version = '';
  String _buildNumber = '';

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();

    if (!mounted) return;

    setState(() {
      _version = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) {
        context.read<ProfileProvider>().loadProfileData(auth.currentUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final historyProvider = context.watch<AttendanceHistoryProvider>();
    final Employee? user = auth.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Create a version of the user with updated counts from history
    final updatedUser = user.copyWith(
      totalPresents: historyProvider.presentCount,
      totalAbsents: historyProvider.absentCount,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProfileHeader(employee: updatedUser),
                const SizedBox(height: 20),
                AttendanceStatsCard(employee: updatedUser),
                const SizedBox(height: 32),

                _buildSectionHeader('PREFERENCES'),
                _buildMenuContainer([
                  _buildToggleItem(
                    icon: Icons.notifications_active_outlined,
                    title: 'Push Notifications',
                    value: _notificationsEnabled,
                    onChanged: (v) => setState(() => _notificationsEnabled = v),
                  ),
                  _buildDivider(),
                  ProfileMenuItem(
                    icon: Icons.language_rounded,
                    title: 'Language',
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 24),
                _buildSectionHeader('SUPPORT'),
                _buildMenuContainer([
                  ProfileMenuItem(
                    icon: Icons.help_outline_rounded,
                    title: 'Help Center',
                    onTap: () => _showHelpDialog(context),
                  ),
                  _buildDivider(),
                  ProfileMenuItem(
                    icon: Icons.info_outline_rounded,
                    title: 'About App',
                    onTap: () => _showAboutDialog(context),
                  ),
                  _buildDivider(),
                  ProfileMenuItem(
                    icon: Icons.lock_outline_rounded,
                    title: 'Privacy Policy',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                    ),
                  ),
                  _buildDivider(),
                  ProfileMenuItem(
                    icon: Icons.settings_applications_outlined,
                    title: 'App Permissions',
                    onTap: () => openAppSettings(),
                  ),
                ]),

                const SizedBox(height: 24),
                _buildMenuContainer([
                  ProfileMenuItem(
                    icon: Icons.logout_rounded,
                    title: 'Log Out',
                    textColor: Colors.red[600],
                    onTap: () => _showLogoutConfirmation(context),
                  ),
                ]),

                const SizedBox(height: 40),
                _buildFooter(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      title: Text(
        'PROFILE',
        style: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF1B1D1F),
          letterSpacing: 1.5,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Color(0xFF1B1D1F)),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuContainer(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1B1D1F), size: 22),
      title: Text(
        title,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.grey[50], indent: 56);
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'PIPFA ATTENDANCE',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Colors.grey[300],
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Version $_version Build ($_buildNumber)',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.grey[400],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Reuse existing dialog methods...
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'About App',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
        ),
        content: const Text('Secure attendance tracking for PIPFA employees.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Help',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
        ),
        content: const Text('Contact support at support@pipfa.org.pk'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log Out',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().logout();
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
