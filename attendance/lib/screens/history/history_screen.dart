import 'package:attendance/config/app_icons.dart';
import 'dart:math' as math;

import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/attendance_record_model.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:attendance/widgets/demo_mode_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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

  // Memoized date groups. The provider mutates its record
  // list in place (insert / removeWhere), so the key is the list identity plus
  // its length and first record id, which together change on every mutation.
  List<AttendanceRecord>? _cachedRecords;
  int _cachedLength = -1;
  String? _cachedFirstId;
  List<AttendanceGroup> _cachedGroups = const [];

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

  // Rebuilds the groups only when the records actually changed.
  List<AttendanceGroup> _groupsFor(AttendanceHistoryProvider provider) {
    final records = provider.records;
    final firstId = records.isEmpty ? null : records.first.id;
    if (identical(_cachedRecords, records) &&
        _cachedLength == records.length &&
        _cachedFirstId == firstId) {
      return _cachedGroups;
    }

    _cachedRecords = records;
    _cachedLength = records.length;
    _cachedFirstId = firstId;
    _cachedGroups = provider.groups;
    return _cachedGroups;
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
    final groups = _groupsFor(historyProvider);

    final width = MediaQuery.sizeOf(context).width;
    final sidePad = width > _contentMaxWidth
        ? (width - _contentMaxWidth) / 2
        : 0.0;

    return Scaffold(
      body: RefreshIndicator(
        color: context.colors.primary,
        backgroundColor: context.colors.surfaceContainerLow,
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
            if (historyProvider.isDemoMode)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  sidePad + ProfileUi.gutter,
                  12,
                  sidePad + ProfileUi.gutter,
                  0,
                ),
                sliver: const SliverToBoxAdapter(child: DemoModeNotice()),
              ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: sidePad),
              sliver: SliverToBoxAdapter(
                child: _HistoryOverview(
                  present: historyProvider.presentCount,
                  absent: historyProvider.absentCount,
                  total:
                      historyProvider.presentCount +
                      historyProvider.absentCount,
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
                    strokeWidth: 3,
                    semanticsLabel: 'Loading history',
                  ),
                ),
              )
            else if (historyProvider.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  icon: AppIcons.alertCircle,
                  title: 'Something went wrong',
                  subtitle: historyProvider.error!,
                  isError: true,
                  onRefresh: _onRefresh,
                ),
              )
            else if (groups.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  icon: AppIcons.history,
                  title: 'No history yet',
                  subtitle: 'Your attendance activity will show up here.',
                  onRefresh: _onRefresh,
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  sidePad,
                  0,
                  sidePad,
                  40 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    return _AttendanceDateGroup(group: groups[index]);
                  },
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
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: true,
      title: Text(
        'History',
        style: ProfileUi.body(context, weight: FontWeight.w600),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: ValueListenableBuilder<bool>(
          valueListenable: _scrolled,
          builder: (_, scrolled, _) => AnimatedOpacity(
            opacity: scrolled ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Divider(
              height: 1,
              thickness: 1,
              color: context.colors.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = math.max(
                1.0,
                MediaQuery.textScalerOf(context).scale(18) / 18,
              );
              final ringSize = math.min(constraints.maxWidth, 84 * scale);
              final ring = _MonthRing(
                progress: monthlyRate,
                isLoading: isLoading,
                dimension: ringSize,
              );
              final streakFact = _Fact(
                value: isLoading ? null : _days(streak),
                label: 'Current streak',
                color: context.attendanceWarning,
              );
              final rateFact = _Fact(
                value: isLoading ? null : '$rate%',
                label: 'Overall rate',
                color: context.colors.primary,
              );
              if (constraints.maxWidth < ringSize + 20 + 120 * scale) {
                return Column(
                  children: [
                    ring,
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: streakFact),
                        const SizedBox(width: 20),
                        Expanded(child: rateFact),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  ring,
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        streakFact,
                        const SizedBox(height: 14),
                        rateFact,
                      ],
                    ),
                  ),
                ],
              );
            },
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
                  color: context.attendancePresent,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: context.colors.outlineVariant,
              ),
              Expanded(
                child: _Count(
                  value: isLoading ? null : absent,
                  label: 'Days absent',
                  color: context.attendanceAbsent,
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value ?? '—',
              style: GoogleFonts.inter(
                fontSize: 20,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
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
                  maxLines: 2,
                  style: ProfileUi.caption(context),
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

  TextStyle _numberStyle(BuildContext context) => GoogleFonts.inter(
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: context.colors.onSurface,
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: v == null
                ? Text('—', style: _numberStyle(context))
                : TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: v),
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (_, animated, _) =>
                        Text('$animated', style: _numberStyle(context)),
                  ),
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
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: ProfileUi.caption(context),
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
  final double dimension;

  const _MonthRing({
    required this.progress,
    required this.isLoading,
    required this.dimension,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final target = isLoading ? 0.0 : progress.clamp(0.0, 1.0).toDouble();

    return Semantics(
      label:
          'This month: ${isLoading ? 'loading' : '${(target * 100).round()} percent'}',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: dimension,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: target),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, value, _) => CustomPaint(
            painter: _RingPainter(
              progress: value,
              color: context.colors.primary,
              trackColor: context.colors.onSurface.withValues(alpha: 0.08),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLoading ? '—' : '${(value * 100).round()}%',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'This month',
                      style: ProfileUi.caption(
                        context,
                      ).copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Grouped attendance history ---

class _AttendanceDateGroup extends StatelessWidget {
  const _AttendanceDateGroup({required this.group});

  final AttendanceGroup group;

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      label: group.date,
      dividerIndent: ProfileUi.rowInset + 18 + 12,
      children: [
        for (final record in group.records)
          _AttendanceRecordRow(record: record),
      ],
    );
  }
}

class _AttendanceRecordRow extends StatelessWidget {
  const _AttendanceRecordRow({required this.record});

  final AttendanceRecord record;

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final isPresent = record.isPresent;
    final color = isPresent
        ? context.attendancePresent
        : context.attendanceAbsent;
    final timeStr = _formatTime(record.timestamp);
    final title = isPresent ? 'Present' : 'Absent';
    final device = record.device.isEmpty || record.device == 'unknown'
        ? null
        : record.device;

    return Semantics(
      container: true,
      label: '$title, $timeStr${device == null ? '' : ', $device'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ProfileUi.rowInset,
          vertical: 12,
        ),
        child: Row(
          children: [
            Icon(isPresent ? AppIcons.circleCheck : AppIcons.circleX, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: ProfileUi.small(
                      context,
                      color: color,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (device != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      device,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileUi.caption(context),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              timeStr,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.2,
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
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24),
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
                color: context.colors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: isError,
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: ProfileUi.small(context).copyWith(height: 1.45),
            ),
          ),
          if (onRefresh != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(AppIcons.refresh, size: 24),
              label: const Text('Refresh'),
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.surfaceContainerLow,
                foregroundColor: context.colors.onSurface,
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
