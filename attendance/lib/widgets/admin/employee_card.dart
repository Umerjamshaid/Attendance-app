import 'package:attendance/config/app_icons.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/attendance_record_model.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// One employee row in the admin roster.
///
/// Rows are laid out independently but look like a single grouped card: only
/// the first row rounds its top corners and only the last rounds its bottom
/// ones, with a hairline divider inset past the avatar in between. This is the
/// pattern Block Buzz uses for its member list, and it keeps long lists
/// virtualized.
class EmployeeCard extends StatelessWidget {
  const EmployeeCard({
    super.key,
    required this.data,
    this.isFirst = true,
    this.isLast = true,
  });

  final EmployeeAttendance data;
  final bool isFirst;
  final bool isLast;

  static const double _avatarSize = 40;

  /// Dividers start after the avatar so they align with the text.
  static const double _dividerIndent =
      ProfileUi.rowInset + _avatarSize + ProfileUi.rowInset;

  static String _initials(String name) {
    final letters = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => String.fromCharCode(part.runes.first))
        .join()
        .toUpperCase();
    return letters.isEmpty ? '?' : letters;
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }

  /// "Role · Department", skipping whichever part is empty.
  String get _roleLine => [
    data.employee.role.trim(),
    data.employee.department.trim(),
  ].where((part) => part.isNotEmpty).join(' · ');

  String get _statusLine {
    final employee = data.employee;
    final record = data.latestRecord;
    final totals = '${employee.totalPresents}P / ${employee.totalAbsents}A';

    if (data.isPresent) {
      final time = record == null ? null : _formatTime(record.timestamp);
      return time == null ? 'Checked in · $totals' : 'In at $time · $totals';
    }
    final last = employee.time.trim();
    final hasLast = last.isNotEmpty && last != '—';
    final status = record == null ? 'Not checked in' : 'Marked absent';
    return hasLast ? '$status · Last $last · $totals' : '$status · $totals';
  }

  void _openDetails(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ProfileUi.sheetRadius),
        ),
      ),
      builder: (_) => _EmployeeDetailsSheet(
        employee: data.employee,
        isPresent: data.isPresent,
        initials: _initials(data.employee.name),
        roleLine: _roleLine,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employee = data.employee;
    final name = employee.name.trim().isEmpty
        ? 'Unnamed employee'
        : employee.name.trim();
    final isPresent = data.isPresent;
    final statusColor = isPresent
        ? context.attendancePresent
        : context.colors.onSurfaceVariant;
    final roleLine = _roleLine;

    return Material(
      color: context.colors.surfaceContainerLow,
      borderRadius: BorderRadius.vertical(
        top: isFirst
            ? const Radius.circular(ProfileUi.cardRadius)
            : Radius.zero,
        bottom: isLast
            ? const Radius.circular(ProfileUi.cardRadius)
            : Radius.zero,
      ),
      // Keeps the row ripple inside the rounded corners.
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFirst)
            Divider(
              height: 1,
              thickness: 1,
              indent: _dividerIndent,
              endIndent: ProfileUi.rowInset,
              color: context.colors.outlineVariant,
            ),
          MergeSemantics(
            child: Semantics(
              button: true,
              hint: 'Opens attendance details',
              child: InkWell(
                onTap: () => _openDetails(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ProfileUi.rowInset,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: _avatarSize,
                        height: _avatarSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _initials(employee.name),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.colors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: ProfileUi.rowInset),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: ProfileUi.body(
                                context,
                                weight: FontWeight.w600,
                              ),
                            ),
                            if (roleLine.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                roleLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ProfileUi.caption(context),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              _statusLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ProfileUi.caption(
                                context,
                                color: statusColor,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusPill(isPresent: isPresent),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isPresent});

  final bool isPresent;

  @override
  Widget build(BuildContext context) {
    final color = isPresent
        ? context.attendancePresent
        : context.colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isPresent ? 'Present' : 'Absent',
        style: GoogleFonts.inter(
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Totals for one employee. Replaces the old "Detailed Analytics" dialog.
class _EmployeeDetailsSheet extends StatelessWidget {
  const _EmployeeDetailsSheet({
    required this.employee,
    required this.isPresent,
    required this.initials,
    required this.roleLine,
  });

  final Employee employee;
  final bool isPresent;
  final String initials;
  final String roleLine;

  /// Percentage of recorded days that were present, or an em dash before any
  /// day is recorded (the old dialog divided by zero and printed "NaN%").
  String get _rate {
    final total = employee.totalPresents + employee.totalAbsents;
    if (total == 0) return '—';
    return '${(employee.totalPresents / total * 100).toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final name = employee.name.trim().isEmpty
        ? 'Unnamed employee'
        : employee.name.trim();

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + ProfileUi.gutter,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ProfileUi.gutter),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initials,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.colors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: context.colors.onSurface,
                          ),
                        ),
                      ),
                      if (roleLine.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(roleLine, style: ProfileUi.small(context)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox.square(
                  dimension: 44,
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: context.colors.surfaceContainerLow,
                      foregroundColor: context.colors.onSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ProfileUi.sheetRadius,
                        ),
                      ),
                    ),
                    icon: const Icon(AppIcons.x, size: 24),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ProfileSectionCard(
            label: 'Attendance',
            dividerIndent: ProfileUi.rowInset,
            children: [
              _DetailRow(
                label: 'Today',
                value: isPresent ? 'Present' : 'Absent',
                color: isPresent
                    ? context.attendancePresent
                    : context.colors.onSurfaceVariant,
              ),
              _DetailRow(
                label: 'Total presents',
                value: '${employee.totalPresents}',
                color: context.attendancePresent,
              ),
              _DetailRow(
                label: 'Total absents',
                value: '${employee.totalAbsents}',
                color: context.attendanceAbsent,
              ),
              _DetailRow(
                label: 'Attendance rate',
                value: _rate,
                color: context.colors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ProfileUi.rowInset,
          vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: ProfileUi.body(context))),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
