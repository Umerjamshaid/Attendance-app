import 'package:attendance/config/app_theme.dart';
import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Presents / absents / leaves in one grouped surface.
///
/// While [isLoading] is true the history-derived counts (presents, absents)
/// show an em dash instead of a misleading zero. Leaves come straight from the
/// employee record, so they always render.
class AttendanceStatsCard extends StatelessWidget {
  const AttendanceStatsCard({
    super.key,
    required this.employee,
    this.isLoading = false,
  });

  final Employee employee;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      label: 'Attendance overview',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: _StatItem(
                  value: isLoading ? null : employee.totalPresents,
                  label: 'Presents',
                  color: WC.present,
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: _StatItem(
                  value: isLoading ? null : employee.totalAbsents,
                  label: 'Absents',
                  color: WC.absent,
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: _StatItem(
                  value: employee.totalLeaves,
                  label: 'Leaves',
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

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: ProfileUi.hairline);
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
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
            // Counts up once on first build and animates from the current
            // value whenever the number changes afterwards.
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
