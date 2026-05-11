import 'package:attendance/models/employees_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AttendanceStatsCard extends StatelessWidget {
  final Employee employee;
  const AttendanceStatsCard({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ATTENDANCE OVERVIEW',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey[400],
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                value: '${employee.totalPresents}',
                label: 'Presents',
                color: Colors.green,
                icon: Icons.check_circle_outline_rounded,
              ),
              _StatItem(
                value: '${employee.totalAbsents}',
                label: 'Absents',
                color: Colors.red,
                icon: Icons.highlight_off_rounded,
              ),
              _StatItem(
                value: '${employee.totalLeaves}',
                label: 'Leaves',
                color: Colors.orange,
                icon: Icons.calendar_today_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;

  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1B1D1F),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}
