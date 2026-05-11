import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/models/attendance_record_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AttendanceGroupCard extends StatelessWidget {
  final AttendanceGroup group;
  const AttendanceGroupCard({Key? key, required this.group}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header - softer style
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 12, left: 4),
          child: Text(
            group.date,
            style: const TextStyle(
              color: WC.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),

        // Timeline items
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

  const TimelineItem({Key? key, required this.record, required this.isLast})
    : super(key: key);

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final color = record.isPresent ? WC.present : WC.absent;
    final time = _formatTime(record.timestamp);
    final hasLocation = record.latitude != null && record.longitude != null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline - simpler, cleaner
          SizedBox(
            width: 28,
            child: Column(
              children: [
                // Dot - smaller, softer shadow
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),

                // Line - thinner, more subtle
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.grey[300],
                    ),
                  ),
              ],
            ),
          ),

          // Card - more padding, softer
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: WC.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header - status + time
                    Row(
                      children: [
                        // Status badge - smaller, softer
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                record.isPresent
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: color,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                record.isPresent ? 'Present' : 'Absent',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Time - less bold, more readable
                        Text(
                          time,
                          style: const TextStyle(
                            color: WC.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Details - only show if needed
                    if (hasLocation || record.device.isNotEmpty) ...[
                      // Device
                      if (record.device.isNotEmpty)
                        _InfoRow(
                          icon: Icons.smartphone_rounded,
                          value: record.device,
                        ),

                      // Location (only if available)
                      if (hasLocation) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.location_on_rounded,
                          value:
                              '${record.latitude?.toStringAsFixed(4)}, ${record.longitude?.toStringAsFixed(4)}',
                        ),
                      ],

                      // Accuracy (only if available)
                      if (record.accuracy != null) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.my_location_rounded,
                          value:
                              '${record.accuracy?.toStringAsFixed(0)}m accuracy',
                        ),
                      ],
                    ],
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

// Simple info row - icon + text only
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _InfoRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
