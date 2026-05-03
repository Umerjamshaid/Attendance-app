Here's a full Discord/Facebook-inspired redesign of `ProfileHeader`:

**Key changes:**
- **Avatar moved bottom-left** (Discord-style) with a white border ring and an online status dot
- **Gradient banner** with subtle decorative circles for depth
- **Name + Edit Profile** row appears beside the avatar space, not below it
- **Info chips** for department and employee ID replace the plain text line
- **Extracted private widgets** (`_InfoChip`, `_EditButton`) to keep `build()` clean

```dart
// profile_header.dart

import 'package:attendance/models/employees_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileHeader extends StatelessWidget {
  final Employee employee;
  const ProfileHeader({super.key, required this.employee});

  // ── Layout constants ─────────────────────────────────────────────
  static const double _bannerHeight   = 160;
  static const double _avatarRadius   = 46;
  static const double _borderWidth    = 4;
  static const double _totalRadius    = _avatarRadius + _borderWidth; // 50
  static const double _avatarDiameter = _totalRadius * 2;             // 100
  static const double _avatarLeft     = 16;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Banner + avatar ──────────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            _buildBanner(),
            Positioned(
              bottom: -_totalRadius, // straddles the banner bottom edge
              left: _avatarLeft,
              child: _buildAvatar(),
            ),
          ],
        ),

        // ── Clear avatar overhang + gap ──────────────────────────
        const SizedBox(height: _totalRadius + 10),

        // ── Name + Edit row ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Invisible spacer to clear the avatar column
              const SizedBox(width: _avatarDiameter + 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      style: GoogleFonts.dmSans(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1B1D1F),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      employee.role,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const _EditButton(),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Info chips (department + ID) ─────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoChip(icon: Icons.business_outlined, label: employee.department),
              _InfoChip(icon: Icons.badge_outlined,    label: employee.id),
            ],
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  // ── Banner ───────────────────────────────────────────────────────
  Widget _buildBanner() {
    return Container(
      height: _bannerHeight,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF1B3A5C), Color(0xFF2E6DA4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative blur circles — depth effect
          Positioned(
            top: -40,
            right: -40,
            child: _glowCircle(160, 0.06),
          ),
          Positioned(
            bottom: -20,
            right: 80,
            child: _glowCircle(90, 0.04),
          ),
          Positioned(
            top: 20,
            right: 120,
            child: _glowCircle(50, 0.03),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }

  // ── Avatar + status dot ─────────────────────────────────────────
  Widget _buildAvatar() {
    return Stack(
      children: [
        Container(
          width: _avatarDiameter,
          height: _avatarDiameter,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white, // border ring
          ),
          child: Padding(
            padding: const EdgeInsets.all(_borderWidth),
            child: CircleAvatar(
              radius: _avatarRadius,
              backgroundColor: Colors.grey,
              backgroundImage: employee.avatarUrl != null
                  ? NetworkImage(employee.avatarUrl!)
                  : null,
              child: employee.avatarUrl == null
                  ? const Icon(Icons.person_2_rounded, size: 48, color: Colors.white)
                  : null,
            ),
          ),
        ),

        // Online status dot
        Positioned(
          bottom: 7,
          right: 7,
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: const Color(0xFF3BA55D), // Discord green
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Edit Profile button ──────────────────────────────────────────
class _EditButton extends StatelessWidget {
  const _EditButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1B3A5C),
        side: const BorderSide(color: Color(0xFF1B3A5C), width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        'Edit Profile',
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Department / ID chip ─────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey[600]),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
```

Also remove the `Center` wrapper in `ProfileScreen` — the new header is left-aligned, so `CrossAxisAlignment.stretch` fits better:

```dart
// In ProfileScreen body → SingleChildScrollView child:
Column(
  crossAxisAlignment: CrossAxisAlignment.stretch, // ← was Center
  children: [
    ProfileHeader(employee: user),
    const SizedBox(height: 24),
    AttendanceStatsCard(employee: user),
    ...
  ],
),
```

The online status dot is hardcoded green for now — once you have a presence/status field on your `Employee` model, you can wire it up to reflect real state.