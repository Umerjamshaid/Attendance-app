import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/models/attendance_record_model.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeline_tile/timeline_tile.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().currentUser?.id;
      final historyProvider = context.read<AttendanceHistoryProvider>();

      if (userId != null && historyProvider.records.isEmpty) {
        historyProvider.loadHistory(userId);
      }
    });
  }

  // Flattens the grouped data into a 1D list to allow a single SliverList
  // This eliminates the need for nested ListViews and shrinkWrap entirely.
  List<dynamic> _buildFlatList(List<AttendanceGroup> groups) {
    final List<dynamic> flatItems = [];
    for (final group in groups) {
      flatItems.add(_HeaderItem(date: group.date));
      for (final record in group.records) {
        flatItems.add(_RecordItem(record: record));
      }
    }
    return flatItems;
  }

  @override
  Widget build(BuildContext context) {
    final historyProvider = context.watch<AttendanceHistoryProvider>();
    final groups = historyProvider.groups;

    // Calculate flat list for rendering
    final flatItems = _buildFlatList(groups);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Premium Apple Fitness / Linear inspired Header
          SliverToBoxAdapter(
            child: _HistoryOverview(
              present: historyProvider.presentCount,
              absent: historyProvider.absentCount,
              total: historyProvider.totalCount,
              streak: historyProvider.currentStreak,
              monthlyRate: historyProvider.monthlyRate,
            ),
          ),

          if (historyProvider.isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF1B1D1F)),
              ),
            )
          else if (historyProvider.error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Something went wrong',
                subtitle: historyProvider.error!,
              ),
            )
          else if (groups.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                icon: Icons.history_rounded,
                title: 'No History Yet',
                subtitle: 'Your attendance activity will show up here.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = flatItems[index];

                    if (item is _HeaderItem) {
                      return _TimelineDateHeader(date: item.date);
                    }

                    if (item is _RecordItem) {
                      // Determine if this is the first or last item in the timeline sequence
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
    );
  }
}

// --- Data Helpers for Flat List ---
class _HeaderItem {
  final String date;
  _HeaderItem({required this.date});
}

class _RecordItem {
  final AttendanceRecord record;
  _RecordItem({required this.record});
}

// --- Overview Section ---
class _HistoryOverview extends StatelessWidget {
  final int present;
  final int absent;
  final int total;
  final int streak;
  final double monthlyRate;

  const _HistoryOverview({
    required this.present,
    required this.absent,
    required this.total,
    required this.streak,
    required this.monthlyRate,
  });

  @override
  Widget build(BuildContext context) {
    final int rate = total > 0 ? ((present / total) * 100).round() : 0;

    return Container(
      decoration: const BoxDecoration(
        color: WC.black,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ATTENDANCE LOG',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8E8E93),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const Icon(
                    Icons.bar_chart_rounded,
                    color: Color(0xFF8E8E93),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'History Overview',
                style: GoogleFonts.dmSans(
                  color: WC.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),

              // Apple Fitness style rings and stats
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Monthly Ring
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CustomPaint(
                      painter: _RingPainter(
                        progress: monthlyRate,
                        color: Colors.blueAccent,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(monthlyRate * 100).toInt()}%',
                              style: GoogleFonts.dmSans(
                                color: WC.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'THIS MONTH',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF8E8E93),
                                fontSize: 7,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Streak & Ratio
                  Expanded(
                    child: Column(
                      children: [
                        _MiniStat(
                          icon: Icons.local_fire_department_rounded,
                          color: Colors.orangeAccent,
                          label: 'CURRENT STREAK',
                          value: '$streak Days',
                        ),
                        const SizedBox(height: 12),
                        _MiniStat(
                          icon: Icons.pie_chart_rounded,
                          color: Colors.greenAccent,
                          label: 'OVERALL RATIO',
                          value: '$rate%',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Present / Absent blocks
              Row(
                children: [
                  Expanded(
                    child: _StatBlock(
                      label: 'Present',
                      count: '$present d',
                      color: WC.present,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatBlock(
                      label: 'Absent',
                      count: '$absent d',
                      color: WC.absent,
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

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8E8E93),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    color: WC.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String count;
  final Color color;

  const _StatBlock({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                color: const Color(0xFF8E8E93),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            count,
            style: GoogleFonts.dmSans(
              color: WC.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Timeline Components ---

class _TimelineDateHeader extends StatelessWidget {
  final String date;

  const _TimelineDateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 16),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            size: 14,
            color: Color(0xFF8E8E93),
          ),
          const SizedBox(width: 8),
          Text(
            date.toUpperCase(),
            style: GoogleFonts.inter(
              color: const Color(0xFF8E8E93),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
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
      beforeLineStyle: const LineStyle(color: Color(0xFFE5E5EA), thickness: 2),
      afterLineStyle: const LineStyle(color: Color(0xFFE5E5EA), thickness: 2),
      endChild: Padding(
        padding: const EdgeInsets.only(left: 20, right: 0, bottom: 16, top: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEFEFF4), width: 1),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPresent ? Icons.verified_rounded : Icons.cancel_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              // Text Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPresent ? 'Present' : 'Absent',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1B1D1F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      record.device.isNotEmpty ? record.device : 'Mobile App',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF8E8E93),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Time & Badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1B1D1F),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isPresent
                          ? color.withOpacity(0.1)
                          : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isPresent ? 'VERIFIED' : 'PENDING',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        color: isPresent ? color : const Color(0xFF8E8E93),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F7),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: const Color(0xFF8E8E93)),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFF1B1D1F),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF8E8E93),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Custom Painters ---

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background Track
    final bgPaint = Paint()
      ..color = const Color(0xFF2C2C2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius - 3, bgPaint);

    // Progress Arc
    final rect = Rect.fromCircle(center: center, radius: radius - 3);
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;

    canvas.drawArc(
      rect,
      -3.14 / 2, // Start from top
      2 * 3.14 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
