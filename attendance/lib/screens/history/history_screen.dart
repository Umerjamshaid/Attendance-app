import 'package:attendance/config/wc_tokens.dart';
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
      final historyProvider = context.read<AttendanceHistoryProvider>();
      
      // Only load if we don't have records yet
      if (userId != null && historyProvider.records.isEmpty) {
        historyProvider.loadHistory(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyProvider = context.watch<AttendanceHistoryProvider>();
    final groups = historyProvider.groups;

    return Container(
      color: WC.bg,
      child: Column(
        children: [
          HistoryHeader(
            present: historyProvider.presentCount,
            absent: historyProvider.absentCount,
          ),
          Expanded(
            child: historyProvider.isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B1D1F)))
                : historyProvider.error != null
                ? Center(child: Text(historyProvider.error!, style: const TextStyle(color: Color(0xFF999999))))
                : groups.isEmpty
                ? const Center(child: Text('No history found', style: TextStyle(color: Color(0xFF999999))))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    itemCount: groups.length,
                    itemBuilder: (_, i) =>
                        AttendanceGroupCard(group: groups[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
