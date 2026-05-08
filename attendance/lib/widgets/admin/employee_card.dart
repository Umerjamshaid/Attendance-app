import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/screens/admin/admin_dashboard_screen.dart';
import 'package:flutter/material.dart';

class EmployeeCard extends StatelessWidget {
  final Employee data;
  const EmployeeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = data.isPresentToday ? WC.present : WC.absent;
    final initial = data.name[0];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WC.card,
        borderRadius: WC.r16,
        border: Border.all(color: WC.border),
        boxShadow: WC.shadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: WC.bg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: WC.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: WC.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${data.department} · ${data.id}',
                  style: const TextStyle(fontSize: 12, color: WC.muted),
                ),
                if (data.time != '—') ...[
                  const SizedBox(height: 2),
                  Text(
                    data.time,
                    style: const TextStyle(fontSize: 11, color: WC.muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Checked in at ${data.checkInTime}',
                    style: const TextStyle(fontSize: 11, color: WC.muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total Presents: ${data.totalPresents}  Absents: ${data.totalAbsents}  Leaves: ${data.totalLeaves}',
                    style: const TextStyle(fontSize: 11, color: WC.muted),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: WC.rFull,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  data.isPresentToday ? 'Present' : 'Absent',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
