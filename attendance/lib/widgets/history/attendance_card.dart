import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/models/attendance_record_model.dart';
import 'package:flutter/material.dart';

class AttendanceGroupCard extends StatelessWidget {
  final AttendanceGroup group;
  const AttendanceGroupCard({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Text(
            group.date,
            style: const TextStyle(
              color: WC.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...group.records.asMap().entries.map((e) {
          final isLast = e.key == group.records.length - 1;
          return TimelineItem(record: e.value, isLast: isLast);
        }),
      ],
    );
  }
}

class TimelineItem extends StatelessWidget {
  final AttendanceRecord record;
  final bool isLast;
  const TimelineItem({super.key, required this.record, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = record.isPresent ? WC.present : WC.absent;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1.5, color: WC.border)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: WC.card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: WC.shadowSm,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        record.isPresent ? 'Present' : 'Absent',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      record.timestamp.toString(),
                      style: const TextStyle(
                        color: WC.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
