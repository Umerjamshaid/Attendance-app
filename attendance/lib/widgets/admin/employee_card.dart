import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/models/attendance_record_model.dart';
import 'package:attendance/models/employees_model.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmployeeCard extends StatelessWidget {
  final EmployeeAttendance data;
  const EmployeeCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final employee = data.employee;
    final isPresent = data.isPresent;
    final color = isPresent ? WC.present : WC.absent;
    final initials = employee.name
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: WC.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with presence ring
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.2), width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: CircleAvatar(
                      backgroundColor: color.withOpacity(0.08),
                      child: Text(
                        initials,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Name & Role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1B1D1F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.work_outline_rounded,
                            size: 12,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${employee.role} · ${employee.department}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Compact Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isPresent ? 'PRESENT' : 'ABSENT',
                    style: GoogleFonts.inter(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Secondary Info Strip (Balanced details)
          InkWell(
            onTap: () => _showEmployeeStats(context),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            splashColor: Colors.black.withOpacity(0.02),
            highlightColor: Colors.black.withOpacity(0.01),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                border: const Border(top: BorderSide(color: Color(0xFFF5F5F5))),
              ),
              child: Row(
                children: [
                  if (isPresent)
                    _InfoItem(
                      icon: Icons.access_time_filled_rounded,
                      label: 'IN: ${data.latestRecord?.timestamp.hour.toString().padLeft(2, '0')}:${data.latestRecord?.timestamp.minute.toString().padLeft(2, '0')}',
                      color: Colors.blue[700]!,
                    )
                  else
                    _InfoItem(
                      icon: Icons.event_busy_rounded,
                      label: 'LAST: ${employee.time}',
                      color: Colors.grey[600]!,
                    ),
                  const SizedBox(width: 16),
                  _InfoItem(
                    icon: Icons.analytics_outlined,
                    label: '${employee.totalPresents}P / ${employee.totalAbsents}A',
                    color: const Color(0xFF666666),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: Color(0xFFCCCCCC),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmployeeStats(BuildContext context) {
    final employee = data.employee;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WC.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        title: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Detailed Analytics',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1B1D1F),
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailRow(
              label: 'Total Presents',
              value: '${employee.totalPresents}',
              color: WC.present,
            ),
            const Divider(color: Color(0xFFF5F5F5)),
            _DetailRow(
              label: 'Total Absents',
              value: '${employee.totalAbsents}',
              color: WC.absent,
            ),
            const Divider(color: Color(0xFFF5F5F5)),
            _DetailRow(
              label: 'Attendance Rate',
              value:
                  '${((employee.totalPresents / (employee.totalPresents + employee.totalAbsents)) * 100).toStringAsFixed(1)}%',
              color: Colors.blue[700]!,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, right: 8),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: Text(
                'Close',
                style: GoogleFonts.inter(
                  color: const Color(0xFF1B1D1F),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _DetailRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF666666),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.dmSans(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color.withOpacity(0.6)),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
