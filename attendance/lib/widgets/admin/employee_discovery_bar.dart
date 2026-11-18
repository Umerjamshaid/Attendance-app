// Adapted from Portal Labs Discovery Bar (MIT), copyright 2026 Luis Portal.
// See assets/licenses/PortalLabs-MIT.txt.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_icons.dart';
import '../../config/ui_tokens.dart';
import '../portal_spring_curve.dart';
import '../user-profile/profile_section_card.dart';

enum EmployeeAccessFilter {
  all('All'),
  active('Active'),
  inactive('Inactive');

  const EmployeeAccessFilter(this.label);
  final String label;
}

/// Controlled, local-only search with the reference's two morphing surfaces.
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
  bool _searching = false;

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

  void _openSearch() {
    HapticFeedback.selectionClick();
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _searching) _focus.requestFocus();
    });
  }

  void _closeSearch() {
    _focus.unfocus();
    _controller.clear();
    widget.onQueryChanged('');
    HapticFeedback.selectionClick();
    setState(() => _searching = false);
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
    final textStyle = ProfileUi.small(context, weight: FontWeight.w500);
    final height = math.max(
      52.0,
      MediaQuery.textScalerOf(context).scale(14) * 1.3 + 20,
    );
    final duration = AppMotion.duration(context, AppMotion.entrance);
    return LayoutBuilder(
      builder: (context, constraints) {
        final pillWidth = math.max(height, constraints.maxWidth - height - 8);
        Widget surface(Widget child) => Material(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(height / 2),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              AnimatedPositionedDirectional(
                duration: duration,
                curve: const PortalSpringCurve(),
                start: 0,
                top: 0,
                bottom: 0,
                width: _searching ? pillWidth : height,
                child: surface(
                  AnimatedSwitcher(
                    duration: duration,
                    child: _searching
                        ? OverflowBox(
                            key: const ValueKey('employee-search-field'),
                            alignment: AlignmentDirectional.centerStart,
                            minWidth: pillWidth,
                            maxWidth: pillWidth,
                            child: SizedBox(
                              width: pillWidth,
                              height: height,
                              child: Row(
                                children: [
                                  const SizedBox(width: 16),
                                  const Icon(AppIcons.search, size: 24),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      key: const ValueKey(
                                        'employee-search-input',
                                      ),
                                      controller: _controller,
                                      focusNode: _focus,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      style: textStyle,
                                      textInputAction: TextInputAction.search,
                                      decoration: InputDecoration(
                                        hintText: 'Search employees',
                                        hintStyle: textStyle.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                        filled: false,
                                        isDense: true,
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                      ),
                                      onChanged: widget.onQueryChanged,
                                      onSubmitted: (_) => _focus.unfocus(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                              ),
                            ),
                          )
                        : IconButton(
                            key: const ValueKey('employee-search-button'),
                            tooltip: 'Search employees',
                            enableFeedback: false,
                            onPressed: _openSearch,
                            icon: const Icon(AppIcons.search, size: 24),
                          ),
                  ),
                ),
              ),
              AnimatedPositionedDirectional(
                duration: duration,
                curve: const PortalSpringCurve(),
                end: 0,
                top: 0,
                bottom: 0,
                width: _searching ? height : pillWidth,
                child: surface(
                  AnimatedSwitcher(
                    duration: duration,
                    child: _searching
                        ? IconButton(
                            key: const ValueKey('employee-close-search'),
                            tooltip: 'Clear and close search',
                            enableFeedback: false,
                            onPressed: _closeSearch,
                            icon: const Icon(AppIcons.x, size: 24),
                          )
                        : OverflowBox(
                            key: const ValueKey('employee-access-filters'),
                            alignment: AlignmentDirectional.centerEnd,
                            minWidth: pillWidth,
                            maxWidth: pillWidth,
                            child: SizedBox(
                              width: pillWidth,
                              height: height,
                              child: LayoutBuilder(
                                builder: (context, box) => SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (final filter
                                          in EmployeeAccessFilter.values)
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minWidth: box.maxWidth / 3,
                                            minHeight: height,
                                          ),
                                          child: Semantics(
                                            selected: widget.filter == filter,
                                            child: TextButton(
                                              onPressed: () {
                                                if (filter != widget.filter) {
                                                  HapticFeedback.selectionClick();
                                                }
                                                widget.onFilterChanged(filter);
                                              },
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    widget.filter == filter
                                                    ? colors.onPrimaryContainer
                                                    : colors.onSurfaceVariant,
                                                backgroundColor:
                                                    widget.filter == filter
                                                    ? colors.primaryContainer
                                                    : Colors.transparent,
                                                textStyle: textStyle,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                shape: const StadiumBorder(),
                                              ),
                                              child: Text(
                                                filter.label,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
