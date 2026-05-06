import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/screens/admin/admin_notification_screen.dart';
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
    final user = auth.currentUser;

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
      children: [
        ProfileMenuItem(
          icon: Icons.lock_outline,
          title: 'Privacy Policy',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Privacy Policy coming soon')),
            );
          },
        ),
        const Divider(indent: 20, endIndent: 20),
        ProfileMenuItem(
          icon: Icons.logout_rounded,
          title: 'Log Out',
          textColor: Colors.red,
          onTap: () => context.read<AuthProvider>().logout(),
        ),
      ],
    );
  }
}
