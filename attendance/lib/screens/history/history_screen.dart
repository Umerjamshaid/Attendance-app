import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/wc_tokens.dart';
import '../../models/attendance_model.dart';

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
      if (userId != null) {
        context.read<AttendanceHistoryProvider>().loadHistory(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyProvider = context.watch<AttendanceHistoryProvider>();
    final groups = historyProvider.groups;

    return Column(
      children: [
        _HistoryHeader(
          present: historyProvider.presentCount,
          absent: historyProvider.absentCount,
        ),
        Expanded(
          child: historyProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : historyProvider.error != null
                  ? Center(child: Text(historyProvider.error!))
                  : groups.isEmpty
                      ? const Center(child: Text('No history found'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          itemCount: groups.length,
                          itemBuilder: (_, i) =>
                              _AttendanceGroup(group: groups[i]),
                        ),
        ),
      ],
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  final int present;
  final int absent;

  const _HistoryHeader({required this.present, required this.absent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: WC.black,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Attendance',
                style: TextStyle(
                  color: WC.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your check-in history',
                style: TextStyle(
                  color: WC.white.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _StatChip(label: '$present Present', color: WC.present),
                  const SizedBox(width: 10),
                  _StatChip(label: '$absent Absent', color: WC.absent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AttendanceGroup extends StatelessWidget {
  final AttendanceGroup group;
  const _AttendanceGroup({required this.group});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Text(
            group.date,
            style: const TextStyle(
              color: WC.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...group.records.asMap().entries.map((e) {
          final isLast = e.key == group.records.length - 1;
          return _TimelineItem(record: e.value, isLast: isLast);
        }),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final AttendanceRecord record;
  final bool isLast;
  const _TimelineItem({required this.record, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = record.isPresent ? WC.present : WC.absent;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1.5, color: WC.border)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: WC.card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: WC.shadowSm,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        record.isPresent ? 'Present' : 'Absent',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      record.timestamp.toString(),
                      style: const TextStyle(
                        color: WC.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
