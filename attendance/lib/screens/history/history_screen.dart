import 'dart:math' as math;

import 'package:attendance/config/app_theme.dart';
import 'package:attendance/config/wc_tokens.dart';
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
            else if (groups.isEmpty)
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
    final color = isPresent ? WC.present : WC.absent;
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
            Icon(
              isPresent
                  ? Icons.check_circle_outline_rounded
                  : Icons.highlight_off_rounded,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: ProfileUi.small(
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
                      style: ProfileUi.caption(),
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
                color: AppTheme.textPrimary,
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
