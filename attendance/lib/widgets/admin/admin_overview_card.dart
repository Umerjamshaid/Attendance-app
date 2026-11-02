import 'package:attendance/config/app_theme.dart';
import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Employees / present / absent for today, in one grouped surface.
///
/// While [isLoading] is true the numbers show an em dash instead of a
/// misleading zero.
class AdminOverviewCard extends StatelessWidget {
  const AdminOverviewCard({
    super.key,
    required this.total,
    required this.present,
    required this.absent,
    this.isLoading = false,
  });

  final int total;
  final int present;
  final int absent;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      label: 'Today',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: _Metric(
                  value: isLoading ? null : total,
                  label: 'Employees',
                  color: AppTheme.primaryNavy,
                ),
              ),
              const _MetricDivider(),
              Expanded(
                child: _Metric(
                  value: isLoading ? null : present,
                  label: 'Present',
                  color: WC.present,
                ),
              ),
              const _MetricDivider(),
              Expanded(
                child: _Metric(
                  value: isLoading ? null : absent,
                  label: 'Absent',
                  color: WC.absent,
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
  final int? value;
  final String label;
  final Color color;

  TextStyle get _numberStyle => GoogleFonts.inter(
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: AppTheme.textPrimary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    final v = value;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: '$label: ${v ?? 'loading'}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (v == null)
            Text('—', style: _numberStyle)
          else
            // Counts up on first build, then animates from the current value
            // whenever a refresh changes the number.
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: v),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, animated, _) =>
                  Text('$animated', style: _numberStyle),
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
