import 'dart:io';
import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/employees_model.dart';

class AttendanceProfileHeader extends StatelessWidget {
  final Employee employee;

  const AttendanceProfileHeader({
    super.key,
    required this.employee,
  });

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    
    ImageProvider avatarImage;
    if (profileProvider.pfpPath != null && File(profileProvider.pfpPath!).existsSync()) {
      avatarImage = FileImage(File(profileProvider.pfpPath!));
    } else {
      final avatarUrl = employee.avatarUrl ??
          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(employee.name)}&background=1A1F71&color=fff&size=200';
      avatarImage = NetworkImage(avatarUrl);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              image: DecorationImage(
                image: avatarImage,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            employee.name,
            style: GoogleFonts.dmSans(
              color: WC.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF334155),
                width: 1,
              ),
            ),
            child: Text(
              employee.department.toUpperCase(),
              style: GoogleFonts.inter(
                color: const Color(0xFF94A3B8),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
