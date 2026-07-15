import 'package:attendance/config/wc_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';

class AttendanceButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  final Animation<double> pulseAnimation;
  final bool isUploadEnabled;
  final String uploadLabel;

  const AttendanceButton({
    super.key,
    required this.isLoading,
    required this.onTap,
    required this.pulseAnimation,
    required this.isUploadEnabled,
    required this.uploadLabel,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = !isUploadEnabled
        ? const Color(0xFF8E8E93)
        : const Color(0xFF1B1D1F);

    return GestureDetector(
      onTap: (isLoading || !isUploadEnabled) ? null : onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer decorative ring
          if (!isLoading && isUploadEnabled)
            ScaleTransition(
              scale: pulseAnimation,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: baseColor.withOpacity(0.05),
                    width: 1,
                  ),
                ),
              ),
            ),
          
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: baseColor,
              boxShadow: [
                BoxShadow(
                  color: baseColor.withOpacity(0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
                BoxShadow(
                  color: WC.white.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: ScaleTransition(
              scale: !isUploadEnabled
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
                        strokeWidth: 4,
                      ),
                    )
                  else ...[
                    Icon(
                      isUploadEnabled
                          ? Icons.fingerprint_rounded
                          : Icons.lock_clock_rounded,
                      size: 64,
                      color: WC.white,
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        uploadLabel.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          color: WC.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
