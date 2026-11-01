import 'package:attendance/config/app_theme.dart';
import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Today / this month / streak, computed from the attendance history.
///
/// While [isLoading] is true the history-derived values show an em dash rather
/// than a misleading zero.
class AttendanceSummaryCard extends StatelessWidget {
  const AttendanceSummaryCard({
    super.key,
    required this.isCheckedIn,
    required this.monthlyRate,
    required this.streak,
    this.isLoading = false,
  });

  final bool isCheckedIn;

  /// Fraction (0..1) of days so far this month with a present record.
  final double monthlyRate;

  /// Consecutive days present, ending today or yesterday.
  final int streak;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      label: 'Your attendance',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: _Metric(
                  value: isCheckedIn ? 'Present' : 'Not yet',
                  label: 'Today',
                  color: isCheckedIn ? WC.present : AppTheme.textSecondary,
                ),
              ),
              const _MetricDivider(),
              Expanded(
                child: _Metric(
                  value: isLoading ? null : '${(monthlyRate * 100).round()}%',
                  label: 'This month',
                  color: AppTheme.primaryNavy,
                ),
              ),
              const _MetricDivider(),
              Expanded(
                child: _Metric(
                  value: isLoading ? null : '$streak',
                  label: 'Day streak',
                  color: ProfileUi.warning,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: ProfileUi.hairline);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.color,
  });

  /// Null renders a placeholder dash.
  final String? value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = value ?? '—';
    return Semantics(
      label: '$label: ${value ?? 'loading'}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scales down instead of overflowing on narrow screens or large
          // font sizes.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                text,
                key: ValueKey(text),
                style: GoogleFonts.inter(
                  fontSize: 24,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ProfileUi.caption(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
