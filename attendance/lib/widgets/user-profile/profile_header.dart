import 'dart:io';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ProfileHeader extends StatelessWidget {
  final Employee employee;
  const ProfileHeader({super.key, required this.employee});

  // ── Layout constants ─────────────────────────────────────────────
  static const double _bannerHeight = 180;
  static const double _avatarRadius = 50;
  static const double _borderWidth = 5;
  static const double _totalRadius = _avatarRadius + _borderWidth;
  static const double _avatarDiameter = _totalRadius * 2;
  static const double _avatarLeft = 20;

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final pfpPath = profileProvider.pfpPath;
    final bannerPath = profileProvider.bannerPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Banner + avatar ──────────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            _buildBanner(context, bannerPath),
            Positioned(
              bottom: -_totalRadius + 15,
              left: _avatarLeft,
              child: _buildAvatar(context, pfpPath),
            ),
          ],
        ),

        const SizedBox(height: _totalRadius - 5),

        // ── Name + Info Row ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.name,
                          style: GoogleFonts.dmSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1B1D1F),
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '@${employee.id.toLowerCase()}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _EditProfileButton(employee: employee),
                ],
              ),
              const SizedBox(height: 16),

              // Bio / Role section
              Text(
                employee.headline ?? '${employee.role} at ${employee.department}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF2D3436),
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 16),

              // Info chips — use custom chips if set, otherwise fall back to defaults
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: employee.chips.isNotEmpty
                    ? _buildDynamicChips(employee.chips)
                    : [
                        _InfoChip(
                          icon: Icons.business_center_rounded,
                          label: employee.department,
                          color: Colors.blue[50]!,
                          textColor: Colors.blue[700]!,
                        ),
                        _InfoChip(
                          icon: Icons.verified_user_rounded,
                          label: employee.role.toUpperCase(),
                          color: Colors.green[50]!,
                          textColor: Colors.green[700]!,
                        ),
                        _InfoChip(
                          icon: Icons.calendar_month_rounded,
                          label: 'Joined ${employee.time.split(' ').first}',
                          color: Colors.orange[50]!,
                          textColor: Colors.orange[700]!,
                        ),
                      ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const List<Color> _chipBgColors = [
    Color(0xFFE3F2FD), // blue[50]
    Color(0xFFE8F5E9), // green[50]
    Color(0xFFFFF3E0), // orange[50]
    Color(0xFFF3E5F5), // purple[50]
    Color(0xFFE0F7FA), // cyan[50]
  ];
  static const List<Color> _chipTextColors = [
    Color(0xFF1565C0), // blue[700]
    Color(0xFF2E7D32), // green[700]
    Color(0xFFE65100), // orange[700]
    Color(0xFF7B1FA2), // purple[700]
    Color(0xFF00838F), // cyan[700]
  ];
  static const List<IconData> _chipIcons = [
    Icons.label_rounded,
    Icons.tag_rounded,
    Icons.star_rounded,
    Icons.bookmark_rounded,
    Icons.circle,
  ];

  List<Widget> _buildDynamicChips(List<String> chips) {
    return chips.asMap().entries.map((entry) {
      final i = entry.key;
      final label = entry.value;
      return _InfoChip(
        icon: _chipIcons[i % _chipIcons.length],
        label: label,
        color: _chipBgColors[i % _chipBgColors.length],
        textColor: _chipTextColors[i % _chipTextColors.length],
      );
    }).toList();
  }

  Widget _buildBanner(BuildContext context, String? path) {
    return GestureDetector(
      onTap: () => context.read<ProfileProvider>().pickBanner(employee.id),
      child: Container(
        height: _bannerHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF2C3E50),
          image: path != null
              ? DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover)
              : null,
          gradient: path == null
              ? const LinearGradient(
                  colors: [
                    Color(0xFF0F2027),
                    Color(0xFF203A43),
                    Color(0xFF2C5364),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Stack(
          children: [
            if (path == null)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.1,
                  child: CustomPaint(painter: _PatternPainter()),
                ),
              ),
            Positioned(
              top: 15,
              right: 15,
              child: _CircularIconButton(
                icon: Icons.camera_alt_rounded,
                onTap: () =>
                    context.read<ProfileProvider>().pickBanner(employee.id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, String? path) {
    return GestureDetector(
      onTap: () => context.read<ProfileProvider>().pickPfp(employee.id),
      child: Stack(
        children: [
          Container(
            width: _avatarDiameter,
            height: _avatarDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(_borderWidth),
              child: CircleAvatar(
                radius: _avatarRadius,
                backgroundColor: const Color(0xFFE1E8ED),
                backgroundImage: path != null
                    ? FileImage(File(path))
                    : (employee.avatarUrl != null
                          ? NetworkImage(employee.avatarUrl!) as ImageProvider
                          : null),
                child: (path == null && employee.avatarUrl == null)
                    ? const Icon(
                        Icons.person_rounded,
                        size: 50,
                        color: Color(0xFF657786),
                      )
                    : null,
              ),
            ),
          ),
          Positioned(
            bottom: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: const Icon(
                Icons.add_a_photo_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircularIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.4),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

class _EditProfileButton extends StatelessWidget {
  final Employee employee;
  const _EditProfileButton({required this.employee});

  void _showEditSheet(BuildContext context) {
    final nameController = TextEditingController(text: employee.name);
    final emailController = TextEditingController(text: employee.email);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline_rounded, color: Colors.blue),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      'Edit Profile',
                      style: GoogleFonts.dmSans(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1B1D1F),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Update your personal information below.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 30),
                _buildFieldLabel('FULL NAME'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: nameController,
                  hint: 'Enter your full name',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 20),
                _buildFieldLabel('EMAIL ADDRESS'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: emailController,
                  hint: 'Enter your email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 35),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<AuthProvider>().updateProfile(
                            name: nameController.text,
                            email: emailController.text,
                          );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Profile updated successfully!'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: Colors.green[700],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B1D1F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      'Save Changes',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Colors.grey[500],
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1B1D1F),
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey[400]),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _showEditSheet(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1B1D1F),
        elevation: 0,
        side: BorderSide(color: Colors.grey[300]!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(
        'Edit Profile',
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }
}
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    for (var i = 0; i < size.width; i += 20) {
      for (var j = 0; j < size.height; j += 20) {
        canvas.drawCircle(Offset(i.toDouble(), j.toDouble()), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
