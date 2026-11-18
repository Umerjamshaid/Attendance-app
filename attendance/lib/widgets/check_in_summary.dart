import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_icons.dart';
import '../config/ui_tokens.dart';
import '../providers/attendance_history_provider.dart';
import 'user-profile/attendance_score_gauge.dart';
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
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gauge = AttendanceScoreGauge(
                progress: unknown ? null : history.monthlyRate,
                label: 'This month',
                isLoading: unknown && history.isLoading,
              );
              final days = _ActivityMetric(
                value: unknown ? null : history.presentThisMonthCount,
                label: 'Days this month',
              );
              return Column(children: [gauge, const SizedBox(height: 12), days]);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ActivityMetric(
                  value: unknown ? null : history.totalCount,
                  label: 'Check-ins',
                  icon: AppIcons.history,
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              Expanded(
                child: _ActivityMetric(
                  value: unknown ? null : history.currentStreak,
                  label: 'Day streak',
                  icon: AppIcons.flame,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityMetric extends StatelessWidget {
  const _ActivityMetric({required this.value, required this.label, this.icon});
  final int? value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: ${value ?? "unavailable"}',
    excludeSemantics: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                value == null ? '\u2014' : '$value',
                style: AppTypography.inter(
                  textStyle: Theme.of(context).textTheme.headlineSmall,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
