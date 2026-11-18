// Adapted from Portal Labs Tag Selection Interaction (MIT), copyright 2026 Luis Portal.
// See assets/licenses/PortalLabs-MIT.txt.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_icons.dart';
import '../../config/ui_tokens.dart';
import '../portal_spring_curve.dart';
import 'profile_section_card.dart';

/// Controlled tags sharing one keyed layer while moving between both groups.
class ProfileTagSelection extends StatelessWidget {
  const ProfileTagSelection({
    super.key,
    required this.choices,
    required this.selected,
    required this.onToggle,
    this.enabled = true,
    this.canAdd = true,
  });

  final List<String> choices;
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final bool enabled;
  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = ProfileUi.small(context, weight: FontWeight.w500);
    final heading = ProfileUi.small(context, weight: FontWeight.w600);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final duration = AppMotion.duration(context, AppMotion.entrance);
    final all = {
      for (final tag in [...choices, ...selected]) tag.toLowerCase(): tag,
    };
    final selectedIds = selected.map((tag) => tag.toLowerCase()).toSet();
    final available = all.keys
        .where((id) => !selectedIds.contains(id))
        .toList();
    final orderedSelected = selectedIds.toList();
    final headerHeight = scaler.scale(14) * 1.3;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        Size measure(String id, double availableWidth) {
          final text = TextPainter(
            text: TextSpan(text: all[id], style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 2,
            ellipsis: '...',
          )..layout(maxWidth: math.max(1, availableWidth - 60));
          final size = Size(
            math.min(availableWidth, math.max(72, text.width + 60)),
            math.max(48, text.height + 20),
          );
          text.dispose();
          return size;
        }

        final sizes = {
          for (final id in all.keys)
            id: measure(
              id,
              selectedIds.contains(id) ? math.max(1, width - 24) : width,
            ),
        };
        final selectedLayout = _wrap(
          orderedSelected,
          sizes,
          math.max(1, width - 24),
          direction,
        );
        final poolLayout = _wrap(available, sizes, width, direction);
        final selectedTop = headerHeight + 8;
        final selectedHeight = selectedIds.isEmpty
            ? 0.0
            : selectedLayout.height + 24;
        final suggestionsTop =
            selectedTop + selectedHeight + (selectedIds.isEmpty ? 0 : 16);
        final poolTop =
            suggestionsTop + (available.isEmpty ? 0 : headerHeight + 8);
        final height = poolTop + poolLayout.height;

        return AnimatedSize(
          duration: duration,
          curve: AppMotion.enterCurve,
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: headerHeight,
                  child: Row(
                    children: [
                      Expanded(child: Text('Your tags', style: heading)),
                      Text(
                        '${selected.length}/12',
                        style: ProfileUi.caption(context),
                      ),
                    ],
                  ),
                ),
                AnimatedPositioned(
                  duration: duration,
                  curve: AppMotion.enterCurve,
                  top: selectedTop,
                  left: 0,
                  right: 0,
                  height: selectedHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                  ),
                ),
                if (available.isNotEmpty)
                  AnimatedPositioned(
                    duration: duration,
                    curve: AppMotion.enterCurve,
                    top: suggestionsTop,
                    left: 0,
                    right: 0,
                    height: headerHeight,
                    child: Text('Suggestions', style: heading),
                  ),
                for (final entry in all.entries)
                  AnimatedPositioned(
                    key: ValueKey('profile-tag:${entry.key}'),
                    duration: duration,
                    curve: const PortalSpringCurve(),
                    left: selectedIds.contains(entry.key)
                        ? selectedLayout.offsets[entry.key]!.dx + 12
                        : poolLayout.offsets[entry.key]!.dx,
                    top: selectedIds.contains(entry.key)
                        ? selectedLayout.offsets[entry.key]!.dy +
                              selectedTop +
                              12
                        : poolLayout.offsets[entry.key]!.dy + poolTop,
                    width: sizes[entry.key]!.width,
                    height: sizes[entry.key]!.height,
                    child: Tooltip(
                      message: entry.value,
                      child: selectedIds.contains(entry.key)
                          ? InputChip(
                              selected: true,
                              showCheckmark: false,
                              isEnabled: enabled,
                              label: Text(
                                entry.value,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: style.copyWith(
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                              labelPadding: EdgeInsets.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              visualDensity: VisualDensity.standard,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              selectedColor: colors.primaryContainer,
                              side: BorderSide(
                                color: colors.primary.withValues(alpha: .35),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              deleteIcon: Icon(
                                AppIcons.x,
                                size: 18,
                                color: colors.onPrimaryContainer,
                              ),
                              deleteIconBoxConstraints:
                                  const BoxConstraints.tightFor(
                                    width: 20,
                                    height: 20,
                                  ),
                              deleteButtonTooltipMessage:
                                  'Remove ${entry.value}',
                              onPressed: enabled
                                  ? () => _toggle(entry.value)
                                  : null,
                              onDeleted: enabled
                                  ? () => _toggle(entry.value)
                                  : null,
                            )
                          : ActionChip(
                              label: Text(
                                entry.value,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: style,
                              ),
                              avatar: const Icon(AppIcons.plus, size: 16),
                              avatarBoxConstraints:
                                  const BoxConstraints.tightFor(
                                    width: 20,
                                    height: 20,
                                  ),
                              labelPadding: EdgeInsets.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              visualDensity: VisualDensity.standard,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              backgroundColor: colors.surfaceContainerHighest,
                              side: BorderSide(color: colors.outlineVariant),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              onPressed: enabled && canAdd
                                  ? () => _toggle(entry.value)
                                  : null,
                            ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggle(String tag) {
    HapticFeedback.selectionClick();
    onToggle(tag);
  }

  ({Map<String, Offset> offsets, double height}) _wrap(
    List<String> ids,
    Map<String, Size> sizes,
    double width,
    TextDirection direction,
  ) {
    final offsets = <String, Offset>{};
    var x = 0.0, y = 0.0, lineHeight = 0.0;
    for (final id in ids) {
      final size = sizes[id]!;
      if (x > 0 && x + size.width > width) {
        x = 0;
        y += lineHeight + 8;
        lineHeight = 0;
      }
      offsets[id] = Offset(
        direction == TextDirection.rtl ? width - x - size.width : x,
        y,
      );
      x += size.width + 8;
      lineHeight = math.max(lineHeight, size.height);
    }
    return (offsets: offsets, height: ids.isEmpty ? 0 : y + lineHeight);
  }
}
