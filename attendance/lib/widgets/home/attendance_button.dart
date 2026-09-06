import 'package:attendance/config/wc_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AttendanceButton extends StatefulWidget {
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
  State<AttendanceButton> createState() => _AttendanceButtonState();
}

class _AttendanceButtonState extends State<AttendanceButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.isUploadEnabled && !widget.isLoading;
    final baseColor = !widget.isUploadEnabled
        ? const Color(0xFF64748B)
        : const Color(0xFF0F172A);

    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: isEnabled
            ? (_) {
                setState(() => _isPressed = true);
                HapticFeedback.mediumImpact();
              }
            : null,
        onTapUp: isEnabled
            ? (_) {
                setState(() => _isPressed = false);
              }
            : null,
        onTapCancel: isEnabled
            ? () {
                setState(() => _isPressed = false);
              }
            : null,
        onTap: isEnabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _isPressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer decorative pulsing ring
              if (!widget.isLoading && widget.isUploadEnabled)
                ScaleTransition(
                  scale: widget.pulseAnimation,
                  child: Container(
                    width: 215,
                    height: 215,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        width: 1.5,
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
                  gradient: isEnabled
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0F172A),
                            Color(0xFF1E293B),
                          ],
                        )
                      : null,
                  color: !isEnabled ? baseColor : null,
                  border: Border.all(
                    color: isEnabled
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isEnabled
                          ? const Color(0xFF10B981).withValues(alpha: _isPressed ? 0.15 : 0.25)
                          : const Color(0xFF0F172A).withValues(alpha: 0.15),
                      blurRadius: _isPressed ? 18 : 32,
                      offset: Offset(0, _isPressed ? 6 : 14),
                    ),
                    BoxShadow(
                      color: WC.white.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: ScaleTransition(
                  scale: !widget.isUploadEnabled
                      ? const AlwaysStoppedAnimation(1.0)
                      : widget.pulseAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.isLoading)
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
                          widget.isUploadEnabled
                              ? Icons.fingerprint_rounded
                              : Icons.lock_clock_rounded,
                          size: 64,
                          color: WC.white,
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            widget.uploadLabel.toUpperCase(),
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
        ),
      ),
    );
  }
}
