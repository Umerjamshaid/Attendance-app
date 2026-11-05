import 'package:attendance/config/app_icons.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Sheet content for choosing when attendance can be marked.
///
/// Present it with `showModalBottomSheet(isScrollControlled: true,
/// useSafeArea: true, showDragHandle: true, backgroundColor: context.colors.surface)`;
/// the sheet draws no surface of its own.
class SetAttendanceWindowSheet extends StatefulWidget {
  const SetAttendanceWindowSheet({super.key});

  @override
  State<SetAttendanceWindowSheet> createState() =>
      _SetAttendanceWindowSheetState();
}

class _SetAttendanceWindowSheetState extends State<SetAttendanceWindowSheet> {
  bool _always = false;
  int _startHour = 7;
  int _endHour = 13;
  bool _initialAlways = false;
  int _initialStartHour = 7;
  int _initialEndHour = 13;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final provider = context.read<AttendanceProvider>();
      await provider.loadWindowConfig();
      if (!mounted) return;
      setState(() {
        _always = provider.windowMode == 'always';
        _startHour = provider.windowStartHour;
        _endHour = provider.windowEndHour;
        _initialAlways = _always;
        _initialStartHour = _startHour;
        _initialEndHour = _endHour;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _formatHour(int hour) {
    final normalized = ((hour % 24) + 24) % 24;
    final period = normalized >= 12 ? 'PM' : 'AM';
    var h = normalized % 12;
    if (h == 0) h = 12;
    return '$h:00 $period';
  }

  /// "Always open" has no range; a schedule needs the end after the start.
  bool get _rangeValid => _always || _endHour > _startHour;
  bool get _hasChanges =>
      _always != _initialAlways ||
      _startHour != _initialStartHour ||
      _endHour != _initialEndHour;

  Future<void> _save() async {
    if (_loading || _saving || !_hasChanges) return;
    if (!_rangeValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _saving = true);

    try {
      final attendanceProvider = context.read<AttendanceProvider>();
      await attendanceProvider.saveWindowConfig(
        mode: _always ? 'always' : 'period',
        startHour: _startHour,
        endHour: _endHour,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Attendance window saved!'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // useSafeArea does not cover the bottom edge, so keep clear of the gesture
    // bar ourselves (unless the keyboard is already covering it).
    final safeBottom = keyboard > 0
        ? 0.0
        : MediaQuery.viewPaddingOf(context).bottom;

    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            ProfileUi.gutter,
            0,
            ProfileUi.gutter,
            ProfileUi.gutter + safeBottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Attendance window',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: context.colors.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose when employees are allowed to mark attendance.',
                          style: ProfileUi.small(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox.square(
                    dimension: 44,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
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
              const SizedBox(height: 20),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(AppIcons.clock, size: 24),
                    label: Text('Scheduled'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(AppIcons.infinity, size: 24),
                    label: Text('Always open'),
                  ),
                ],
                selected: {_always},
                showSelectedIcon: false,
                onSelectionChanged: (_saving || _loading)
                    ? null
                    : (selection) {
                        HapticFeedback.selectionClick();
                        setState(() => _always = selection.first);
                      },
                style: SegmentedButton.styleFrom(
                  backgroundColor: context.colors.surfaceContainerLow,
                  foregroundColor: context.colors.onSurfaceVariant,
                  selectedBackgroundColor: context.colors.primary,
                  selectedForegroundColor: context.colors.onPrimary,
                  side: BorderSide.none,
                  minimumSize: const Size.fromHeight(48),
                  textStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AnimatedSize(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _always
                    ? Text(
                        'No time restriction (24 hours).',
                        style: ProfileUi.small(context),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _HourSelector(
                                  label: 'Start time',
                                  value: _startHour,
                                  formatter: _formatHour,
                                  enabled: !_saving && !_loading,
                                  onChanged: (v) =>
                                      setState(() => _startHour = v),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _HourSelector(
                                  label: 'End time',
                                  value: _endHour,
                                  formatter: _formatHour,
                                  enabled: !_saving && !_loading,
                                  onChanged: (v) =>
                                      setState(() => _endHour = v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_rangeValid)
                            Text(
                              'Employees can mark attendance from ${_formatHour(_startHour)} to ${_formatHour(_endHour)}.',
                              style: ProfileUi.small(context),
                            )
                          else
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                'End time must be after start time.',
                                style: ProfileUi.small(
                                  context,
                                  color: context.colors.error,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              // The window is stored in this device's local storage, so it
              // does not reach other employees' phones. Say so plainly.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(AppIcons.infoCircle, size: 24),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.read<AttendanceProvider>().isCompanyMode
                          ? 'Company timezone: ${context.read<AttendanceProvider>().companyTimezone}'
                          : 'Saved on this device. Other devices keep their own setting.',
                      style: ProfileUi.caption(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colors.surfaceContainerLow,
                        foregroundColor: context.colors.onSurface,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed:
                          (_loading || _saving || !_hasChanges || !_rangeValid)
                          ? null
                          : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        foregroundColor: context.colors.onPrimary,
                        disabledBackgroundColor:
                            context.colors.surfaceContainerHighest,
                        disabledForegroundColor:
                            context.colors.onSurfaceVariant,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(AppIcons.check, size: 24),
                                SizedBox(width: 8),
                                Text('Save window'),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HourSelector extends StatelessWidget {
  final String label;
  final int value;
  final String Function(int) formatter;
  final ValueChanged<int> onChanged;
  final bool enabled;

  const _HourSelector({
    required this.label,
    required this.value,
    required this.formatter,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ProfileUi.small(context, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(16),
                dropdownColor: context.colors.surfaceContainerLow,
                menuMaxHeight: 320,
                icon: Icon(AppIcons.chevronDown),
                style: ProfileUi.body(context, weight: FontWeight.w500),
                items: List.generate(24, (h) => h)
                    .map(
                      (h) => DropdownMenuItem<int>(
                        value: h,
                        child: Text(formatter(h)),
                      ),
                    )
                    .toList(),
                onChanged: enabled
                    ? (v) {
                        if (v != null) onChanged(v);
                      }
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
