import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmployeeCard extends StatelessWidget {
  final Employee data;
  const EmployeeCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final color = data.isPresentToday ? WC.present : WC.absent;
    final initials = data.name.split(' ').map((e) => e[0]).take(2).join().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                      backgroundColor: color.withOpacity(0.1),
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
                        data.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1B1D1F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.work_outline_rounded, size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            '${data.role} · ${data.department}',
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    data.isPresentToday ? 'PRESENT' : 'ABSENT',
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              children: [
                if (data.isPresentToday)
                  _InfoItem(
                    icon: Icons.access_time_filled_rounded,
                    label: 'IN: ${data.checkInTime ?? '—'}',
                    color: Colors.blue[700]!,
                  )
                else
                  _InfoItem(
                    icon: Icons.event_busy_rounded,
                    label: 'LAST: ${data.time}',
                    color: Colors.grey[600]!,
                  ),
                const SizedBox(width: 16),
                _InfoItem(
                  icon: Icons.analytics_outlined,
                  label: '${data.totalPresents}P / ${data.totalAbsents}A',
                  color: Colors.grey[600]!,
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.black26),
              ],
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

  const _InfoItem({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color.withOpacity(0.5)),
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
