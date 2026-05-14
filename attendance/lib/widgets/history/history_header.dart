import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HistoryHeader extends StatelessWidget {
  final int present;
  final int absent;

  const HistoryHeader({super.key, required this.present, required this.absent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: WC.black,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HISTORY',
                style: GoogleFonts.dmSans(
                  color: WC.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _DarkStatBadge(
                    label: 'Present',
                    count: present,
                    color: WC.present,
                  ),
                  const SizedBox(width: 12),
                  _DarkStatBadge(
                    label: 'Absent',
                    count: absent,
                    color: WC.absent,
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

class _DarkStatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _DarkStatBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF222222), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.4), blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: GoogleFonts.dmSans(
                    color: WC.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: const Color(0xFF666666),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
