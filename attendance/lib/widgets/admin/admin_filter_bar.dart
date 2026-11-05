import 'package:attendance/config/app_theme.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// All / Present / Absent selector with live counts.
///
/// Modeled on Block Buzz's shared `FilterChipBar`: one equal-width row of
/// stadium chips, no checkmark, the selected chip filled with the primary
/// colour, and the count appended to each label. Selection values are the
/// strings `AdminProvider.filter` already uses.
class AdminFilterBar extends StatelessWidget {
  const AdminFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.total,
    required this.present,
    required this.absent,
    this.checkInLog = false,
  });

  /// One of `'all'`, `'present'` or `'absent'`.
  final String selected;
  final ValueChanged<String> onSelected;
  final int total;
  final int present;
  final int absent;
  final bool checkInLog;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ProfileUi.gutter,
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: _Chip(
              label: 'All',
              count: total,
              isSelected: selected == 'all',
              onTap: () => onSelected('all'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Chip(
              label: checkInLog ? 'Checked in' : 'Present',
              count: present,
              isSelected: selected == 'present',
              onTap: () => onSelected('present'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Chip(
              label: checkInLog ? 'Not yet' : 'Absent',
              count: absent,
              isSelected: selected == 'absent',
              onTap: () => onSelected('absent'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chip = FilterChip(
      selected: isSelected,
      showCheckmark: false,
      onSelected: (_) {
        if (!isSelected) HapticFeedback.selectionClick();
        onTap();
      },
      shape: const StadiumBorder(),
      side: BorderSide.none,
      elevation: 0,
      pressElevation: 0,
      backgroundColor: context.colors.surfaceContainerLow,
      selectedColor: context.colors.primary,
      labelPadding: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      // Keeps the full 48dp touch target even though the chip looks smaller.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      label: SizedBox(
        width: double.infinity,
        child: Text(
          '$label ($count)',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.2,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? context.colors.onPrimary
                : context.colors.onSurfaceVariant,
          ),
        ),
      ),
    );
    // Same safeguard Buzz uses so the chip fills its Expanded slot.
    return SizedBox(width: double.infinity, child: chip);
  }
}
