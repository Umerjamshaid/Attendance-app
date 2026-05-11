import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/wc_tokens.dart';

class AttendanceButton extends StatelessWidget {
  final bool isCheckedIn;
  final bool isLoading;
  final VoidCallback onTap;
  final Animation<double> pulseAnimation;

  const AttendanceButton({
    super.key,
    required this.isCheckedIn,
    required this.isLoading,
    required this.onTap,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (isCheckedIn || isLoading) ? null : onTap,
      child: MouseRegion(
        cursor: (isCheckedIn || isLoading)
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCheckedIn ? WC.present : WC.black,
            boxShadow: [
              BoxShadow(
                color: (isCheckedIn ? WC.present : WC.black).withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              if (!isCheckedIn && !isLoading)
                BoxShadow(
                  color: WC.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: ScaleTransition(
            scale: isCheckedIn
                ? const AlwaysStoppedAnimation(1.0)
                : pulseAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      color: WC.white,
                      strokeWidth: 3,
                    ),
                  )
                else ...[
                  Icon(
                    isCheckedIn
                        ? Icons.check_circle_rounded
                        : Icons.fingerprint_rounded,
                    size: 64,
                    color: WC.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isCheckedIn ? 'Checked In' : 'Mark\nAttendance',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: WC.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
