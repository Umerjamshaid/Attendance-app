import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_history_provider.dart';
import 'user-profile/profile_section_card.dart';

class CheckInSummary extends StatelessWidget {
  const CheckInSummary({super.key});
  @override
  Widget build(BuildContext context) {
    final history = context.watch<AttendanceHistoryProvider>();
    final unknown =
        history.records.isEmpty && (history.isLoading || history.error != null);
    return ProfileSectionCard(
      label: 'Check-in activity',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final metric in [
                (
                  label: 'Days this month',
                  value: history.presentThisMonthCount,
                ),
                (label: 'Check-ins', value: history.totalCount),
                (label: 'Day streak', value: history.currentStreak),
              ])
                Expanded(
                  child: Semantics(
                    label:
                        '${metric.label}: ${unknown ? "unavailable" : metric.value}',
                    excludeSemantics: true,
                    child: Column(
                      children: [
                        Text(
                          unknown ? '—' : '${metric.value}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          metric.label,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
