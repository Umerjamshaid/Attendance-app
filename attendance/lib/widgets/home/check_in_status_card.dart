import 'package:flutter/material.dart';
import '../../config/wc_tokens.dart';

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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: WC.present.withOpacity(0.08),
          borderRadius: WC.r16,
          border: Border.all(
            color: WC.present.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: WC.present,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Checked in today at',
                    style: TextStyle(
                      fontSize: 12,
                      color: WC.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    checkInTime,
                    style: const TextStyle(
                      fontSize: 18,
                      color: WC.present,
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
