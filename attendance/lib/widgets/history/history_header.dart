import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/widgets/history/state_chip.dart';
import 'package:flutter/material.dart';

class HistoryHeader extends StatelessWidget {
  final int present;
  final int absent;

  const HistoryHeader({required this.present, required this.absent});

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
                  color: WC.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  StatChip(label: '$present Present', color: WC.present),
                  const SizedBox(width: 10),
                  StatChip(label: '$absent Absent', color: WC.absent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
