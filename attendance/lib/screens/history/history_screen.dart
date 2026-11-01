import 'dart:math' as math;

import 'package:attendance/config/app_theme.dart';
import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/models/attendance_record_model.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeline_tile/timeline_tile.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const double _contentMaxWidth = 560;

  // Scroll-driven app bar divider. Only the divider rebuilds.
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<bool> _scrolled = ValueNotifier(false);

  // Memoized flat list (headers + records). The provider mutates its record
  // list in place (insert / removeWhere), so the key is the list identity plus
  // its length and first record id, which together change on every mutation.
  List<AttendanceRecord>? _cachedRecords;
  int _cachedLength = -1;
  String? _cachedFirstId;
  List<Object> _cachedFlatItems = const [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().currentUser?.id;
      final historyProvider = context.read<AttendanceHistoryProvider>();

      if (userId != null && historyProvider.records.isEmpty) {
        historyProvider.loadHistory(userId);
      }
    });
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _scrolled.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    _scrolled.value = _scroll.offset > 4;
  }

  // Rebuilds the flat list only when the records actually changed, so
  // scrolling and unrelated rebuilds do not re-allocate headers and wrappers.
  List<Object> _flatItemsFor(AttendanceHistoryProvider provider) {
    final records = provider.records;
    final firstId = records.isEmpty ? null : records.first.id;
    if (identical(_cachedRecords, records) &&
        _cachedLength == records.length &&
        _cachedFirstId == firstId) {
      return _cachedFlatItems;
    }

    final flatItems = <Object>[];
    for (final group in provider.groups) {
      flatItems.add(_HeaderItem(date: group.date));
      for (final record in group.records) {
        flatItems.add(_RecordItem(record: record));
      }
    }
    _cachedRecords = records;
    _cachedLength = records.length;
    _cachedFirstId = firstId;
    _cachedFlatItems = flatItems;
    return flatItems;
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != null) {
      await context.read<AttendanceHistoryProvider>().loadHistory(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyProvider = context.watch<AttendanceHistoryProvider>();
    final flatItems = _flatItemsFor(historyProvider);

    final width = MediaQuery.sizeOf(context).width;
    final sidePad = width > _contentMaxWidth
        ? (width - _contentMaxWidth) / 2
        : 0.0;

    return Scaffold(
      backgroundColor: ProfileUi.page,
      body: RefreshIndicator(
        color: AppTheme.primaryNavy,
        backgroundColor: Colors.white,
        // Start the spinner below the pinned app bar.
        edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            _buildSliverAppBar(),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: sidePad),
              sliver: SliverToBoxAdapter(
                child: _HistoryOverview(
                  present: historyProvider.presentCount,
                  absent: historyProvider.absentCount,
                  total: historyProvider.totalCount,
                  streak: historyProvider.currentStreak,
                  monthlyRate: historyProvider.monthlyRate,
                  isLoading: historyProvider.isLoading,
                ),
              ),
            ),
            if (historyProvider.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryNavy,
                    strokeWidth: 3,
                    semanticsLabel: 'Loading history',
                  ),
                ),
              )
            else if (historyProvider.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Something went wrong',
                  subtitle: historyProvider.error!,
                  isError: true,
                  onRefresh: _onRefresh,
                ),
              )
            else if (flatItems.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No history yet',
                  subtitle: 'Your attendance activity will show up here.',
                  onRefresh: _onRefresh,
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  sidePad + ProfileUi.gutter,
                  0,
                  sidePad + ProfileUi.gutter,
                  40 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = flatItems[index];

                      if (item is _HeaderItem) {
                        return _TimelineDateHeader(date: item.date);
                      }

                      if (item is _RecordItem) {
                        final bool isFirst =
                            index == 0 || flatItems[index - 1] is _HeaderItem;
                        final bool isLast =
                            index == flatItems.length - 1 ||
                            flatItems[index + 1] is _HeaderItem;

                        return _TimelineRecord(
                          record: item.record,
                          isFirst: isFirst,
                          isLast: isLast,
                        );
                      }

                      return const SizedBox.shrink();
                    },
                    childCount: flatItems.length,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: ProfileUi.page,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: true,
      title: Text('History', style: ProfileUi.body(weight: FontWeight.w600)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: ValueListenableBuilder<bool>(
          valueListenable: _scrolled,
          builder: (_, scrolled, _) => AnimatedOpacity(
            opacity: scrolled ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Divider(height: 1, thickness: 1, color: ProfileUi.hairline),
          ),
        ),
      ),
    );
  }
}

// --- Data helpers for the flat list ---
class _HeaderItem {
  final String date;
  _HeaderItem({required this.date});
}

class _RecordItem {
  final AttendanceRecord record;
  _RecordItem({required this.record});
}

// --- Overview ---
class _HistoryOverview extends StatelessWidget {
  final int present;
  final int absent;
  final int total;
  final int streak;
  final double monthlyRate;
  final bool isLoading;

  const _HistoryOverview({
    required this.present,
    required this.absent,
    required this.total,
    required this.streak,
    required this.monthlyRate,
    required this.isLoading,
  });

  String _days(int n) => n == 1 ? '1 day' : '$n days';

  @override
  Widget build(BuildContext context) {
    final int rate = total > 0 ? ((present / total) * 100).round() : 0;

    return ProfileSectionCard(
      label: 'Overview',
      // Full-width separators: this card has no leading icon column.
      dividerIndent: ProfileUi.rowInset,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              _MonthRing(progress: monthlyRate, isLoading: isLoading),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Fact(
                      value: isLoading ? null : _days(streak),
                      label: 'Current streak',
                      color: ProfileUi.warning,
                    ),
                    const SizedBox(height: 14),
                    _Fact(
                      value: isLoading ? null : '$rate%',
                      label: 'Overall rate',
                      color: AppTheme.primaryNavy,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: _Count(
                  value: isLoading ? null : present,
                  label: 'Days present',
                  color: WC.present,
                ),
              ),
              Container(width: 1, height: 36, color: ProfileUi.hairline),
              Expanded(
                child: _Count(
                  value: isLoading ? null : absent,
                  label: 'Days absent',
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

/// Dot + label under a value, left aligned. A null [value] shows a dash.
class _Fact extends StatelessWidget {
  final String? value;
  final String label;
  final Color color;

  const _Fact({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: ${value ?? 'loading'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 20,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
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

/// Centered count with a dot + label below; counts up when it changes.
class _Count extends StatelessWidget {
  final int? value;
  final String label;
  final Color color;

  const _Count({required this.value, required this.label, required this.color});

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

/// Progress ring for the current month. Animates to its value.
class _MonthRing extends StatelessWidget {
  final double progress;
  final bool isLoading;

  const _MonthRing({required this.progress, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final target = isLoading ? 0.0 : progress.clamp(0.0, 1.0).toDouble();

    return Semantics(
      label:
          'This month: ${isLoading ? 'loading' : '${(target * 100).round()} percent'}',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 84,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: target),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, value, _) => CustomPaint(
            painter: _RingPainter(
              progress: value,
              color: AppTheme.primaryNavy,
              trackColor: AppTheme.textPrimary.withValues(alpha: 0.08),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLoading ? '—' : '${(value * 100).round()}%',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    'This month',
                    style: ProfileUi.caption().copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Timeline components ---

class _TimelineDateHeader extends StatelessWidget {
  final String date;

  const _TimelineDateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8, left: 4),
      child: Semantics(
        header: true,
        child: Text(date, style: ProfileUi.small(weight: FontWeight.w600)),
      ),
    );
  }
}

class _TimelineRecord extends StatelessWidget {
  final AttendanceRecord record;
  final bool isFirst;
  final bool isLast;

  const _TimelineRecord({
    required this.record,
    required this.isFirst,
    required this.isLast,
  });

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final isPresent = record.isPresent;
    final color = isPresent ? WC.present : WC.absent;
    final timeStr = _formatTime(record.timestamp);
    final title = isPresent ? 'Present' : 'Absent';
    final badge = isPresent ? 'Verified' : 'Pending';
    final device = record.device.isNotEmpty ? record.device : 'Mobile App';
    final line = LineStyle(
      color: AppTheme.textPrimary.withValues(alpha: 0.1),
      thickness: 2,
    );

    return TimelineTile(
      alignment: TimelineAlign.start,
      lineXY: 24.0,
      isFirst: isFirst,
      isLast: isLast,
      indicatorStyle: IndicatorStyle(
        width: 14,
        height: 14,
        color: color,
        drawGap: true,
        padding: const EdgeInsets.only(top: 18, left: 6),
      ),
      beforeLineStyle: line,
      afterLineStyle: line,
      endChild: Padding(
        padding: const EdgeInsets.only(left: 20, bottom: 16, top: 8),
        child: Semantics(
          container: true,
          label: '$title, $timeStr, $device, $badge',
          excludeSemantics: true,
          child: Material(
            color: ProfileUi.cardFill,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPresent ? Icons.verified_rounded : Icons.cancel_rounded,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: ProfileUi.body(weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          device,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ProfileUi.caption(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeStr,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isPresent
                              ? color.withValues(alpha: 0.15)
                              : AppTheme.textPrimary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: isPresent ? color : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isError;
  final VoidCallback? onRefresh;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isError = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ProfileUi.gutter + 4,
        ProfileUi.gutter + 4,
        ProfileUi.gutter + 4,
        ProfileUi.gutter + 4 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: ProfileUi.cardFill,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: isError ? AppTheme.errorRed : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: isError,
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: ProfileUi.small().copyWith(height: 1.45),
            ),
          ),
          if (onRefresh != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              style: FilledButton.styleFrom(
                backgroundColor: ProfileUi.cardFill,
                foregroundColor: AppTheme.textPrimary,
                elevation: 0,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: const StadiumBorder(),
                textStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --- Custom painter ---

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  static const double _stroke = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - _stroke / 2;

    // Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc (skipped at 0 so a round cap doesn't draw a stray dot)
    if (progress <= 0) return;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start from the top
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
