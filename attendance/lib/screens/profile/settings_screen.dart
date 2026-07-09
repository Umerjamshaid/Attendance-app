import 'package:attendance/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotificationsEnabled = true;
  bool _emailNotificationsEnabled = false;
  late TextEditingController _headlineController;
  late TextEditingController _chipsController;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _headlineController = TextEditingController(
      text: user?.headline ?? '${user?.role ?? ''} at ${user?.department ?? ''}',
    );
    _chipsController = TextEditingController(
      text: user != null && user.chips.isNotEmpty
          ? user.chips.join(', ')
          : '${user?.department ?? ''}, ${user?.role ?? ''}',
    );
  }

  @override
  void dispose() {
    _headlineController.dispose();
    _chipsController.dispose();
    super.dispose();
  }

  void _saveProfileDetails() {
    final headline = _headlineController.text.trim();
    final chipsText = _chipsController.text.trim();
    final chips = chipsText.isNotEmpty
        ? chipsText.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    context.read<AuthProvider>().updateProfile(
      headline: headline,
      chips: chips,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile details saved!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.green[700],
      ),
    );
  }

  // Helper to build groups without manual dividers
  List<Widget> _buildGroupChildren(List<Widget> tiles) {
    final List<Widget> children = [];
    for (int i = 0; i < tiles.length; i++) {
      children.add(tiles[i]);
      if (i < tiles.length - 1) {
        children.add(
          const Padding(
            padding: EdgeInsets.only(left: 64.0),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F7)),
          ),
        );
      }
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFFFAFAFA),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF1B1D1F),
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 48, bottom: 16),
              title: Text(
                'Settings',
                style: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1B1D1F),
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          // Profile Header Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Builder(
                builder: (context) {
                  final user = context.watch<AuthProvider>().currentUser;
                  return _ProfileHeader(
                    name: user?.name ?? 'User',
                    email: user?.email ?? '',
                    role: user?.headline ?? '${user?.role ?? ''} at ${user?.department ?? ''}',
                    avatarColor: const Color(0xFF7C5CFC),
                    onTap: () {},
                  );
                },
              ),
            ),
          ),

          // Settings Sections
          SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionHeader('ACCOUNT'),
              _buildSettingsGroup([
                _SettingsTile(
                  icon: Icons.person_outline_rounded,
                  iconColor: Colors.blue[400]!,
                  title: 'Personal Information',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.security_rounded,
                  iconColor: Colors.grey[600]!,
                  title: 'Security & Password',
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: 28),
              _buildSectionHeader('PROFILE DETAILS'),
              _buildProfileDetailsSection(),

              const SizedBox(height: 28),
              _buildSectionHeader('NOTIFICATIONS'),
              _buildSettingsGroup([
                _SettingsToggleTile(
                  icon: Icons.notifications_none_rounded,
                  iconColor: Colors.red[400]!,
                  title: 'Push Notifications',
                  value: _pushNotificationsEnabled,
                  onChanged: (v) {
                    HapticFeedback.lightImpact();
                    setState(() => _pushNotificationsEnabled = v);
                  },
                ),
                _SettingsToggleTile(
                  icon: Icons.mail_outline_rounded,
                  iconColor: Colors.orange[400]!,
                  title: 'Email Notifications',
                  value: _emailNotificationsEnabled,
                  onChanged: (v) {
                    HapticFeedback.lightImpact();
                    setState(() => _emailNotificationsEnabled = v);
                  },
                ),
              ]),

              const SizedBox(height: 28),
              _buildSectionHeader('PERMISSIONS'),
              _buildSettingsGroup([
                _SettingsTile(
                  icon: Icons.location_on_outlined,
                  iconColor: Colors.green[400]!,
                  title: 'Location Permissions',
                  subtitle: 'Manage in Settings',
                  onTap: () => openAppSettings(),
                ),
                _SettingsTile(
                  icon: Icons.settings_applications_outlined,
                  iconColor: Colors.teal[400]!,
                  title: 'App Settings',
                  onTap: () => openAppSettings(),
                ),
              ]),

              const SizedBox(height: 28),
              _buildSectionHeader('PREFERENCES'),
              _buildSettingsGroup([
                _SettingsTile(
                  icon: Icons.language_rounded,
                  iconColor: Colors.indigo[400]!,
                  title: 'App Language',
                  subtitle: 'English (US)',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  iconColor: Colors.purple[400]!,
                  title: 'Theme Mode',
                  subtitle: 'Light',
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: 28),
              _buildSectionHeader('DATA'),
              _buildSettingsGroup([
                _SettingsTile(
                  icon: Icons.history_rounded,
                  iconColor: Colors.brown[400]!,
                  title: 'Clear History',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.delete_outline_rounded,
                  iconColor: Colors.red[400]!,
                  title: 'Delete Account',
                  textColor: Colors.red[600]!,
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: 40),
              Center(
                child: Text(
                  'Version 2.4.1 • Build 2024',
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFEFF4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HEADLINE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey[500],
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _headlineController,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B1D1F),
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Software Engineer at Company',
              prefixIcon: Icon(Icons.short_text_rounded, size: 20, color: Colors.grey[400]),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'CHIPS / TAGS',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey[500],
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Separate multiple tags with commas',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _chipsController,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B1D1F),
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Engineering, Admin, Full-time',
              prefixIcon: Icon(Icons.label_outline_rounded, size: 20, color: Colors.grey[400]),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saveProfileDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B1D1F),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                'Save Details',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
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
          color: const Color(0xFF8E8E93),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> tiles) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFEFF4), width: 1),
      ),
      child: Column(children: _buildGroupChildren(tiles)),
    );
  }
}

// =========================================================
// Custom Widgets for Pixel-Perfect UI
// =========================================================

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final Color avatarColor;
  final VoidCallback onTap;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.role,
    required this.avatarColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .map((e) => e[0])
        .take(2)
        .join()
        .toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEFEFF4), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: avatarColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: avatarColor.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.dmSans(
                      color: avatarColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1B1D1F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: avatarColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFC7C7CC),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color? textColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(0), // Handled by parent container
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _IconContainer(icon: icon, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor ?? const Color(0xFF1B1D1F),
                  ),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF8E8E93),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey[350],
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _IconContainer(icon: icon, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1B1D1F),
              ),
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: const Color(0xFF34C759),
              inactiveTrackColor: const Color(0xFFE5E5EA),
              activeColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconContainer extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconContainer({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}
