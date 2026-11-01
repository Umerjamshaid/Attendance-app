import 'package:attendance/config/app_theme.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// The primary check-in control: a flat circular button with a soft pulsing
/// ring while it is available.
class AttendanceButton extends StatefulWidget {
  const AttendanceButton({
    super.key,
    required this.isLoading,
    required this.onTap,
    required this.pulseAnimation,
    required this.isUploadEnabled,
    required this.uploadLabel,
  });

  final bool isLoading;
  final VoidCallback onTap;
  final Animation<double> pulseAnimation;
  final bool isUploadEnabled;
  final String uploadLabel;

  @override
  State<AttendanceButton> createState() => _AttendanceButtonState();
}

class _AttendanceButtonState extends State<AttendanceButton> {
  static const double _size = 168;
  static const double _ringSize = 204;

  bool _isPressed = false;

  void _setPressed(bool pressed) {
    if (_isPressed != pressed) setState(() => _isPressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.isUploadEnabled && !widget.isLoading;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final showRing = isEnabled && !reduceMotion;
    final fill = widget.isUploadEnabled
        ? AppTheme.primaryNavy
        : ProfileUi.cardFill;
    final foreground = widget.isUploadEnabled
        ? Colors.white
        : AppTheme.textSecondary;

    return RepaintBoundary(
      child: Semantics(
        button: true,
        enabled: isEnabled,
        label: widget.isLoading ? 'Submitting attendance' : widget.uploadLabel,
        // excludeSemantics drops the GestureDetector's own tap action, so it
        // is exposed here for screen readers.
        onTap: isEnabled ? widget.onTap : null,
        excludeSemantics: true,
        child: GestureDetector(
          onTapDown: isEnabled
              ? (_) {
                  _setPressed(true);
                  HapticFeedback.mediumImpact();
                }
              : null,
          onTapUp: isEnabled ? (_) => _setPressed(false) : null,
          onTapCancel: isEnabled ? () => _setPressed(false) : null,
          onTap: isEnabled ? widget.onTap : null,
          child: AnimatedScale(
            scale: _isPressed ? 0.96 : 1.0,
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: SizedBox(
              width: _ringSize,
              height: _ringSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (showRing)
                    ScaleTransition(
                      scale: widget.pulseAnimation,
                      child: Container(
                        width: _ringSize,
                        height: _ringSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primaryNavy.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  AnimatedContainer(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
                    width: _size,
                    height: _size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fill,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.isLoading)
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(
                              color: foreground,
                              strokeWidth: 3.5,
                            ),
                          )
                        else ...[
                          Icon(
                            widget.isUploadEnabled
                                ? Icons.fingerprint_rounded
                                : Icons.lock_clock_rounded,
                            size: 56,
                            color: foreground,
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Text(
                              widget.uploadLabel,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                                color: foreground,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
