import 'package:attendance/config/app_icons.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/widgets/user-profile/profile_menu_item.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const double _contentMaxWidth = 560;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(AppIcons.chevronLeft, size: 24),
          color: context.colors.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Privacy & security',
          style: ProfileUi.body(context, weight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Intro(),
                    const ProfileSectionCard(
                      label: 'How your data is used',
                      children: [
                        _PolicyRow(
                          icon: AppIcons.moodSmile,
                          title: 'Check-in photo',
                          summary:
                              'A front-camera photo helps confirm that the right person is checking in.',
                          details:
                              'A photo is captured only after you tap the attendance button. It is encoded for submission to the configured attendance service and is not used for advertising or profiling.',
                        ),
                        _PolicyRow(
                          icon: AppIcons.currentLocation,
                          title: 'Point-in-time location',
                          summary:
                              'Your location is read once when you submit attendance.',
                          details:
                              'The app does not continuously track your location. The coordinates captured at check-in are sent with the attendance record so the organization can verify where the submission came from.',
                        ),
                        _PolicyRow(
                          icon: AppIcons.shieldLock,
                          title: 'Submission integrity',
                          summary:
                              'The app performs basic device and location checks before sending a record.',
                          details:
                              'Permission checks and location validation help the organization keep attendance records trustworthy. The exact checks may vary by build and configured attendance service.',
                        ),
                        _PolicyRow(
                          icon: AppIcons.cloudCheck,
                          title: 'Secure transmission',
                          summary:
                              'Attendance details are sent to the configured organization service.',
                          details:
                              'The submission includes the employee identifier, check-in time, location, device details, and captured photo as required by the active service. Transport security is provided by the organization’s backend configuration.',
                        ),
                        _PolicyRow(
                          icon: AppIcons.fileCertificate,
                          title: 'Retention and access',
                          summary:
                              'Attendance records are managed by your organization.',
                          details:
                              'Retention, access, and deletion requests are handled according to your organization’s policy. Contact your HR or IT administrator if you need to inspect or correct a record.',
                        ),
                      ],
                    ),
                    ProfileSectionCard(
                      label: 'Permissions',
                      children: [
                        ProfileMenuItem(
                          icon: AppIcons.adjustments,
                          title: 'Open system settings',
                          onTap: openAppSettings,
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        ProfileUi.gutter + 4,
                        0,
                        ProfileUi.gutter,
                        0,
                      ),
                      child: Text(
                        'Review camera and location access at any time.',
                        style: ProfileUi.caption(context),
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

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileUi.gutter,
        8,
        ProfileUi.gutter,
        16,
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.attendancePresent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(AppIcons.shield, size: 24),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              'Your data, handled with care',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 22,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Attendance uses your camera and location only when you choose to check in. Nothing runs continuously in the background.',
            textAlign: TextAlign.center,
            style: ProfileUi.small(context).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// A tappable row that expands to reveal the full explanation.
class _PolicyRow extends StatefulWidget {
  const _PolicyRow({
    required this.icon,
    required this.title,
    required this.summary,
    required this.details,
  });

  final IconData icon;
  final String title;
  final String summary;
  final String details;

  @override
  State<_PolicyRow> createState() => _PolicyRowState();
}

class _PolicyRowState extends State<_PolicyRow> {
  bool _expanded = false;

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return MergeSemantics(
      child: Semantics(
        button: true,
        expanded: _expanded,
        child: InkWell(
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ProfileUi.rowInset,
              vertical: 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(widget.icon, size: 24),
                    const SizedBox(width: ProfileUi.rowInset),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: ProfileUi.body(
                              context,
                              weight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.summary,
                            style: ProfileUi.small(
                              context,
                            ).copyWith(height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      child: Icon(AppIcons.chevronDown, size: 24),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _expanded
                      ? Padding(
                          // Align the details with the title, past the icon.
                          padding: const EdgeInsets.only(
                            left: ProfileUi.dividerIndent - ProfileUi.rowInset,
                            top: 12,
                          ),
                          child: Text(
                            widget.details,
                            style: ProfileUi.small(
                              context,
                              color: context.colors.onSurface.withValues(
                                alpha: 0.8,
                              ),
                            ).copyWith(height: 1.55),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
