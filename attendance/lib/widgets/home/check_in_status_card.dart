import 'package:attendance/config/app_icons.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';

/// Confirmation card shown once the employee has checked in. It expands into
/// place (and collapses on a rolled-back check-in) instead of popping in.
class CheckInStatusCard extends StatelessWidget {
  const CheckInStatusCard({
    super.key,
    required this.isCheckedIn,
    required this.checkInTime,
    required this.scaleAnimation,
  });

  final bool isCheckedIn;
  final String checkInTime;
  final Animation<double> scaleAnimation;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final time = checkInTime.trim();
    final title = time.isEmpty ? 'Checked in' : 'Checked in at $time';

    return AnimatedSize(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !isCheckedIn
          ? const SizedBox(width: double.infinity)
          : ScaleTransition(
              scale: scaleAnimation,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ProfileUi.gutter,
                  8,
                  ProfileUi.gutter,
                  8,
                ),
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  label: '$title. Verified and logged.',
                  excludeSemantics: true,
                  child: Material(
                    color: context.colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(ProfileUi.cardRadius),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: context.attendancePresent.withValues(
                                alpha: 0.15,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              AppIcons.rosetteDiscountCheck,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: ProfileUi.body(
                                    context,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Verified and logged',
                                  style: ProfileUi.small(
                                    context,
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
