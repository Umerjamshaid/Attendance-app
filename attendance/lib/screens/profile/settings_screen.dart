import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'SETTINGS',
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1B1D1F),
            letterSpacing: 1.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1B1D1F), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          _buildSectionHeader('ACCOUNT'),
          _buildSettingsGroup([
            _buildSettingsItem(
              icon: Icons.person_outline_rounded,
              title: 'Personal Information',
              onTap: () {},
            ),
            _buildDivider(),
            _buildSettingsItem(
              icon: Icons.security_rounded,
              title: 'Security & Password',
              onTap: () {},
            ),
          ]),
          
          const SizedBox(height: 24),
          _buildSectionHeader('NOTIFICATIONS'),
          _buildSettingsGroup([
            _buildToggleItem(
              icon: Icons.notifications_none_rounded,
              title: 'Push Notifications',
              value: true,
              onChanged: (v) {},
            ),
            _buildDivider(),
            _buildSettingsItem(
              icon: Icons.mail_outline_rounded,
              title: 'Email Notifications',
              onTap: () {},
            ),
          ]),

          const SizedBox(height: 24),
          _buildSectionHeader('PERMISSIONS'),
          _buildSettingsGroup([
            _buildSettingsItem(
              icon: Icons.location_on_outlined,
              title: 'Location Permissions',
              subtitle: 'Manage in Settings',
              onTap: () => openAppSettings(),
            ),
            _buildDivider(),
            _buildSettingsItem(
              icon: Icons.settings_applications_outlined,
              title: 'App Settings',
              onTap: () => openAppSettings(),
            ),
          ]),

          const SizedBox(height: 24),
          _buildSectionHeader('PREFERENCES'),
          _buildSettingsGroup([
            _buildSettingsItem(
              icon: Icons.language_rounded,
              title: 'App Language',
              subtitle: 'English (US)',
              onTap: () {},
            ),
            _buildDivider(),
            _buildSettingsItem(
              icon: Icons.dark_mode_outlined,
              title: 'Theme Mode',
              subtitle: 'Light',
              onTap: () {},
            ),
          ]),

          const SizedBox(height: 24),
          _buildSectionHeader('DATA'),
          _buildSettingsGroup([
            _buildSettingsItem(
              icon: Icons.history_rounded,
              title: 'Clear History',
              onTap: () {},
            ),
            _buildDivider(),
            _buildSettingsItem(
              icon: Icons.delete_outline_rounded,
              title: 'Delete Account',
              textColor: Colors.red[600],
              onTap: () {},
            ),
          ]),
        ],
      ),
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

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: textColor ?? const Color(0xFF1B1D1F), size: 22),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (subtitle != null)
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
            ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[300], size: 14),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
}
