import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/screens/admin/admin_notification_screen.dart';
import 'package:attendance/screens/profile/privacy_screen.dart';
import 'package:attendance/widgets/user-profile/attendance_stats_card.dart';
import 'package:attendance/widgets/user-profile/profile_header.dart';
import 'package:attendance/widgets/user-profile/profile_menu_item.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:attendance/providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const double _sectionGap = 24.0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final Employee? user = auth.currentUser;

    // Guard: show a fallback if there's no authenticated user
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.black38,
            backgroundColor: Colors.white,
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.black26),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileHeader(employee: user),
            const SizedBox(height: _sectionGap + 6),
            AttendanceStatsCard(employee: user),
            const SizedBox(height: _sectionGap),
            _buildMenuSection(context),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.grey[50],
      elevation: 0,
      foregroundColor: Colors.black,
      title: Text(
        'YOUR PROFILE',
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1B1D1F),
          letterSpacing: 1.2,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: WC.muted,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdminNotificationScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Settings & Support',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: WC.muted,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              ProfileMenuItem(
                icon: Icons.info_outline_rounded,
                title: 'About App',
                onTap: () => _showAboutDialog(context),
              ),
              _buildDivider(),
              ProfileMenuItem(
                icon: Icons.help_outline_rounded,
                title: 'Help & Support',
                onTap: () => _showHelpDialog(context),
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
                icon: Icons.logout_rounded,
                title: 'Log Out',
                textColor: Colors.red[600],
                onTap: () => _showLogoutConfirmation(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: Column(
            children: [
              Text(
                'PIPFA Attendance App',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: WC.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'v1.0.0',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: WC.muted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Colors.grey[200]),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'About PIPFA Attendance',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'PIPFA Attendance App v1.0.0\n\n'
          'A secure, GPS-based attendance tracking system designed for accurate and fraud-proof employee attendance.\n\n'
          '© 2026 PIPFA. All rights reserved.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
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
        title: Text(
          'Help & Support',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpItem(
                'How to mark attendance?',
                'Tap "Mark Attendance" on the home screen. The app will capture your GPS location and device information.',
              ),
              const SizedBox(height: 12),
              _buildHelpItem(
                'Offline mode?',
                'If internet is unavailable, your attendance is saved locally and synced when connection is restored.',
              ),
              const SizedBox(height: 12),
              _buildHelpItem(
                'GPS not working?',
                'Ensure location permissions are enabled in your device settings. Accuracy must be within acceptable range.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1B1D1F),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: GoogleFonts.inter(fontSize: 13, color: WC.muted, height: 1.5),
        ),
      ],
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Log Out',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
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
            child: Text('Log Out', style: TextStyle(color: Colors.red[600])),
          ),
        ],
      ),
    );
  }
}
