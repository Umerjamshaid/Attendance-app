import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_icons.dart';
import '../../config/ui_tokens.dart';

enum EmployeeAccessFilter {
  all('All'),
  active('Active'),
  inactive('Inactive');

  const EmployeeAccessFilter(this.label);
  final String label;
}

/// A persistent, local search field with independent access filters.
class EmployeeDiscoveryBar extends StatefulWidget {
  const EmployeeDiscoveryBar({
    super.key,
    required this.query,
    required this.filter,
    required this.onQueryChanged,
    required this.onFilterChanged,
  });

  final String query;
  final EmployeeAccessFilter filter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<EmployeeAccessFilter> onFilterChanged;

  @override
  State<EmployeeDiscoveryBar> createState() => _EmployeeDiscoveryBarState();
}

class _EmployeeDiscoveryBarState extends State<EmployeeDiscoveryBar> {
  late final _controller = TextEditingController(text: widget.query);
  final _focus = FocusNode();

  @override
  void didUpdateWidget(EmployeeDiscoveryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.query) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppLayout.groupRadius),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Search employees',
          child: TextField(
            key: const ValueKey('employee-search-input'),
            controller: _controller,
            focusNode: _focus,
            autocorrect: false,
            enableSuggestions: false,
            style: AppTypography.body,
            textInputAction: TextInputAction.search,
            onChanged: widget.onQueryChanged,
            onSubmitted: (_) => _focus.unfocus(),
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(
                AppIcons.search,
                size: AppLayout.compactIconSize,
              ),
              suffixIcon: widget.query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(
                        AppIcons.x,
                        size: AppLayout.compactIconSize,
                      ),
                      onPressed: () {
                        _controller.clear();
                        widget.onQueryChanged('');
                      },
                    ),
              fillColor: colors.surfaceContainerLow,
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: BorderSide(color: colors.primary, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final filter in EmployeeAccessFilter.values)
              ChoiceChip(
                label: Text(filter.label),
                selected: filter == widget.filter,
                showCheckmark: false,
                selectedColor: colors.primaryContainer,
                backgroundColor: colors.surface,
                side: filter == widget.filter
                    ? BorderSide.none
                    : BorderSide(color: colors.outlineVariant),
                shape: const StadiumBorder(),
                labelStyle: AppTypography.label.copyWith(
                  color: filter == widget.filter
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                ),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (selected) {
                  if (!selected) return;
                  HapticFeedback.selectionClick();
                  widget.onFilterChanged(filter);
                },
              ),
          ],
        ),
      ],
    );
  }
}
