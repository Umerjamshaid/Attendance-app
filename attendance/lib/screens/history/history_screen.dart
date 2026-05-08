import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/widgets/history/attendance_card.dart';
import 'package:attendance/widgets/history/history_header.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
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
        HistoryHeader(
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
                    horizontal: 20,
                    vertical: 16,
                  ),
                  itemCount: groups.length,
                  itemBuilder: (_, i) => AttendanceGroupCard(group: groups[i]),
                ),
        ),
      ],
    );
  }
}
