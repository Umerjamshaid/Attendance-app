// Adapted from Portal Labs Scrollable Subgroups (MIT), copyright 2026 Luis Portal.
// Source and licence: assets/licenses/PortalLabs-MIT.txt.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/attendance_record_model.dart';
import '../user-profile/profile_section_card.dart';

/// One History viewport, with office-scoped records under pinned date headers.
class HistorySubgroups extends StatefulWidget {
  const HistorySubgroups({
    super.key,
    required this.groups,
    required this.leadingSlivers,
    required this.controller,
    required this.itemBuilder,
    required this.sidePadding,
    required this.pinnedTop,
    required this.bottomPadding,
  });

  final List<AttendanceGroup> groups;
  final List<Widget> leadingSlivers;
  final ScrollController controller;
  final Widget Function(BuildContext, AttendanceRecord) itemBuilder;
  final double sidePadding;
  final double pinnedTop;
  final double bottomPadding;

  @override
  State<HistorySubgroups> createState() => _HistorySubgroupsState();
}

class _HistorySubgroupsState extends State<HistorySubgroups> {
  final _viewportKey = GlobalKey();
  final _motions = <String, _GroupMotion>{};
  bool _updateScheduled = false;
  double _headerHeight = 48;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _syncGroups();
    _scheduleUpdate();
  }

  @override
  void didUpdateWidget(HistorySubgroups oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncGroups();
    _scheduleUpdate();
  }

  void _syncGroups() {
    final dates = widget.groups.map((group) => group.date).toSet();
    for (final date in _motions.keys.toList()) {
      if (!dates.contains(date)) _motions.remove(date)!.dispose();
    }
    for (final date in dates) {
      _motions.putIfAbsent(date, _GroupMotion.new);
    }
  }

  void _scheduleUpdate() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (mounted) _updateScrollStates();
    });
  }

  void _updateScrollStates() {
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final top = viewport.localToGlobal(Offset.zero).dy + widget.pinnedTop;
    for (var index = 0; index < widget.groups.length; index++) {
      final motion = _motions[widget.groups[index].date]!;
      final bottom = motion.bottomKey.currentContext?.findRenderObject();
      var radius = 0.0;
      if (bottom is RenderBox && bottom.hasSize) {
        final clearance =
            bottom.localToGlobal(Offset.zero).dy +
            bottom.size.height -
            top -
            _headerHeight;
        radius = (ProfileUi.cardRadius - clearance).clamp(
          0.0,
          ProfileUi.cardRadius,
        );
      }
      var opacity = 1.0;
      if (!_reduceMotion && index < widget.groups.length - 1) {
        final next = _motions[widget.groups[index + 1].date]!
            .headerKey
            .currentContext
            ?.findRenderObject();
        if (next is RenderBox && next.hasSize) {
          final distance = next.localToGlobal(Offset.zero).dy - top;
          opacity = ((distance - _headerHeight + 24) / 24).clamp(0.0, 1.0);
        }
      }
      motion.visual.value = (opacity: opacity, bottomRadius: radius);
    }
  }

  @override
  void dispose() {
    for (final motion in _motions.values) {
      motion.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = ProfileUi.small(context, weight: FontWeight.w600);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final width = math.max(
      1.0,
      MediaQuery.sizeOf(context).width -
          2 * (widget.sidePadding + ProfileUi.rowInset),
    );
    _headerHeight = 48;
    for (final group in widget.groups) {
      final text = TextPainter(
        text: TextSpan(text: group.date, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 2,
      )..layout(maxWidth: width);
      _headerHeight = math.max(
        _headerHeight,
        (text.height + 24).ceilToDouble(),
      );
      text.dispose();
    }
    _scheduleUpdate();
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _scheduleUpdate();
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 &&
              notification.metrics.axis == Axis.vertical) {
            _scheduleUpdate();
          }
          return false;
        },
        child: CustomScrollView(
          key: _viewportKey,
          controller: widget.controller,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            ...widget.leadingSlivers,
            for (final group in widget.groups)
              SliverPadding(
                key: ValueKey('history-group:${group.date}'),
                padding: EdgeInsets.symmetric(horizontal: widget.sidePadding),
                sliver:
                    ValueListenableBuilder<
                      ({double opacity, double bottomRadius})
                    >(
                      valueListenable: _motions[group.date]!.visual,
                      builder: (_, visual, child) => SliverOpacity(
                        opacity: visual.opacity,
                        sliver: child!,
                      ),
                      child: SliverMainAxisGroup(
                        slivers: [
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _DateHeader(
                              date: group.date,
                              motion: _motions[group.date]!,
                              height: _headerHeight,
                              textStyle: style,
                              surface: theme.colorScheme.surfaceContainerLow,
                              backdrop: theme.scaffoldBackgroundColor,
                            ),
                          ),
                          SliverList.builder(
                            itemCount: group.records.length,
                            itemBuilder: (context, index) {
                              final last = index == group.records.length - 1;
                              final record = group.records[index];
                              Widget row = Material(
                                key: ValueKey('history-record:${record.id}'),
                                color: theme.colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.vertical(
                                  bottom: last
                                      ? const Radius.circular(
                                          ProfileUi.cardRadius,
                                        )
                                      : Radius.zero,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (index > 0)
                                      Divider(
                                        height: 1,
                                        thickness: 1,
                                        indent: ProfileUi.rowInset + 18 + 12,
                                        endIndent: ProfileUi.rowInset,
                                        color: theme.colorScheme.outlineVariant,
                                      ),
                                    widget.itemBuilder(context, record),
                                  ],
                                ),
                              );
                              if (last) {
                                row = KeyedSubtree(
                                  key: _motions[group.date]!.bottomKey,
                                  child: row,
                                );
                              }
                              return row;
                            },
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        ],
                      ),
                    ),
              ),
            if (widget.groups.isNotEmpty)
              SliverToBoxAdapter(child: SizedBox(height: widget.bottomPadding)),
          ],
        ),
      ),
    );
  }
}

class _GroupMotion {
  final headerKey = GlobalKey();
  final bottomKey = GlobalKey();
  final visual = ValueNotifier((opacity: 1.0, bottomRadius: 0.0));
  void dispose() => visual.dispose();
}

class _DateHeader extends SliverPersistentHeaderDelegate {
  _DateHeader({
    required this.date,
    required this.motion,
    required this.height,
    required this.textStyle,
    required this.surface,
    required this.backdrop,
  });
  final String date;
  final _GroupMotion motion;
  final double height;
  final TextStyle textStyle;
  final Color surface, backdrop;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ValueListenableBuilder<({double opacity, double bottomRadius})>(
    valueListenable: motion.visual,
    builder: (_, visual, child) => ColoredBox(
      color: backdrop,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(ProfileUi.cardRadius),
          bottom: Radius.circular(visual.bottomRadius),
        ),
        child: child!,
      ),
    ),
    child: Container(
      key: motion.headerKey,
      color: surface,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(
        horizontal: ProfileUi.rowInset,
        vertical: 12,
      ),
      child: Semantics(
        header: true,
        child: Text(
          date,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        ),
      ),
    ),
  );

  @override
  bool shouldRebuild(_DateHeader oldDelegate) =>
      date != oldDelegate.date ||
      motion != oldDelegate.motion ||
      height != oldDelegate.height ||
      textStyle != oldDelegate.textStyle ||
      surface != oldDelegate.surface ||
      backdrop != oldDelegate.backdrop;
}
