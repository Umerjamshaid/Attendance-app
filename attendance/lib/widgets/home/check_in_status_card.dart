import 'package:attendance/config/wc_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CheckInStatusCard extends StatelessWidget {
  final bool isCheckedIn;
  final String checkInTime;
  final Animation<double> scaleAnimation;

  const CheckInStatusCard({
    super.key,
    required this.isCheckedIn,
    required this.checkInTime,
    required this.scaleAnimation,
  });

  @override
  Widget build(BuildContext context) {
    if (!isCheckedIn) return const SizedBox.shrink();

    return ScaleTransition(
      scale: scaleAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: WC.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: Color(0xFF10B981),
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'PUNCH VERIFIED & LOGGED',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF059669),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Checked in at $checkInTime',
                    style: GoogleFonts.dmSans(
                      fontSize: 17,
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
