import 'package:attendance/config/wc_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';

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
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFF0F0F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: WC.present.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: WC.present.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: WC.present,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STATUS: CHECKED IN',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFF999999),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Today at $checkInTime',
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      color: const Color(0xFF1B1D1F),
                      fontWeight: FontWeight.w900,
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
