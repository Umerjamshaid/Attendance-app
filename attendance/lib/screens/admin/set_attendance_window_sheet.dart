import 'package:attendance/config/app_theme.dart';
import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/services/local_storage_service.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Sheet content for choosing when attendance can be marked.
///
/// Present it with `showModalBottomSheet(isScrollControlled: true,
/// useSafeArea: true, showDragHandle: true, backgroundColor: ProfileUi.page)`;
/// the sheet draws no surface of its own.
class SetAttendanceWindowSheet extends StatefulWidget {
  const SetAttendanceWindowSheet({super.key});

  @override
  State<SetAttendanceWindowSheet> createState() =>
      _SetAttendanceWindowSheetState();
}

class _SetAttendanceWindowSheetState extends State<SetAttendanceWindowSheet> {
  final _storageService = LocalStorageService();

  bool _always = false;
  int _startHour = 7;
  int _endHour = 13;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await _storageService.getAttendanceWindow();
    if (saved != null && mounted) {
      setState(() {
        _always = (saved['mode'] as String?) == 'always';
        _startHour = (saved['startHour'] as int?) ?? 7;
        _endHour = (saved['endHour'] as int?) ?? 13;
      });
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

  Future<void> _save() async {
    if (!_rangeValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time.'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _saving = true);

    try {
      await _storageService.saveAttendanceWindow(
        mode: _always ? 'always' : 'period',
        startHour: _startHour,
        endHour: _endHour,
      );

      if (!mounted) return;

      // Refresh the provider so the attendance button updates immediately.
      await context.read<AttendanceProvider>().loadWindowConfig();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Attendance window saved!'),
          backgroundColor: WC.present,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorRed,
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
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose when employees are allowed to mark attendance.',
                          style: ProfileUi.small(),
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
                        backgroundColor: ProfileUi.cardFill,
                        foregroundColor: AppTheme.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ProfileUi.sheetRadius,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    icon: Icon(Icons.schedule_rounded, size: 18),
                    label: Text('Scheduled'),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.all_inclusive_rounded, size: 18),
                    label: Text('Always open'),
                  ),
                ],
                selected: {_always},
                showSelectedIcon: false,
                onSelectionChanged: _saving
                    ? null
                    : (selection) {
                        HapticFeedback.selectionClick();
                        setState(() => _always = selection.first);
                      },
                style: SegmentedButton.styleFrom(
                  backgroundColor: ProfileUi.cardFill,
                  foregroundColor: AppTheme.textSecondary,
                  selectedBackgroundColor: AppTheme.primaryNavy,
                  selectedForegroundColor: Colors.white,
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
                        style: ProfileUi.small(),
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
                                  enabled: !_saving,
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
                                  enabled: !_saving,
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
                              style: ProfileUi.small(),
                            )
                          else
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                'End time must be after start time.',
                                style: ProfileUi.small(
                                  color: AppTheme.errorRed,
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
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Saved on this device. Other devices keep their own setting.',
                      style: ProfileUi.caption(),
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
                        backgroundColor: ProfileUi.cardFill,
                        foregroundColor: AppTheme.textPrimary,
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
                      onPressed: (_saving || !_rangeValid) ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryNavy,
                        foregroundColor: Colors.white,
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
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_rounded, size: 18),
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
          Text(label, style: ProfileUi.small(weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: ProfileUi.cardFill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(16),
                dropdownColor: Colors.white,
                menuMaxHeight: 320,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textSecondary,
                ),
                style: ProfileUi.body(weight: FontWeight.w500),
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
