import 'package:attendance/config/wc_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/employees_model.dart';

class AttendanceProfileHeader extends StatelessWidget {
  final Employee employee;

  const AttendanceProfileHeader({
    super.key,
    required this.employee,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = employee.avatarUrl ??
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(employee.name)}&background=1A1F71&color=fff&size=200';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: WC.present.withOpacity(0.3), width: 3),
              image: DecorationImage(
                image: NetworkImage(avatarUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            employee.name,
            style: GoogleFonts.dmSans(
              color: WC.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF2A2A2A),
                width: 1,
              ),
            ),
            child: Text(
              employee.department.toUpperCase(),
              style: GoogleFonts.inter(
                color: const Color(0xFF777777),
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
