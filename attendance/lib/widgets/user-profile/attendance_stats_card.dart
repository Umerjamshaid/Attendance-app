import 'package:attendance/models/employees_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AttendanceStatsCard extends StatelessWidget {
  final Employee employee;
  const AttendanceStatsCard({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: const Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _StatColumn(
                value: '${employee.totalPresents}',
                label: 'Presents',
                valueColor: Colors.greenAccent,
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              _StatColumn(
                value: '${employee.totalAbsents}',
                label: 'Absents',
                valueColor: Colors.redAccent,
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              _StatColumn(
                value: '${employee.totalLeaves}',
                label: 'Leaves',
                valueColor: Colors.amber,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _StatColumn({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w300,
              color: Colors.grey[400],
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
