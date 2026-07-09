import 'dart:convert';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/services/attendance_submission_service_factory.dart';
import 'package:attendance/services/location_service.dart';
import 'package:attendance/widgets/home/attendance_button.dart';
import 'package:attendance/widgets/home/attendance_profile_header.dart';
import 'package:attendance/widgets/home/check_in_status_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class AttendanceScreen extends StatefulWidget {
  final Employee employee;

  /// Whether this screen is the currently visible tab. When false (e.g. the
  /// user is on another tab inside the [IndexedStack]) the pulsing animation is
  /// paused so the app stops rendering frames continuously in the background.
  final bool isActive;

  const AttendanceScreen({
    super.key,
    required this.employee,
    this.isActive = true,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isCheckedIn = false;
  String _checkInTime = '';
  bool _isLocalLoading = false;
  bool _appResumed = true;
  late AnimationController _pulseController;
  late AnimationController _successController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _isCheckedIn = widget.employee.isPresentToday;
    _checkInTime = widget.employee.checkInTime ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AttendanceProvider>().initialize();
      context.read<AttendanceHistoryProvider>().loadHistory(widget.employee.id);
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    if (_isCheckedIn) {
      _successController.forward();
    }
    _syncPulse();
  }

  /// Runs the looping pulse animation only when it is actually needed: the tab
  /// is visible, the app is in the foreground and the user has not checked in
  /// yet. This prevents the never-ending frame rendering that floods logcat
  /// with `BLASTBufferQueue ... acquireNextBufferLocked` errors.
  void _syncPulse() {
    final shouldPulse = widget.isActive && _appResumed && !_isCheckedIn;
    if (shouldPulse) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else if (_pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _syncPulse();
  }

  void _handleCheckIn() async {
    final attendanceProvider = context.read<AttendanceProvider>();
    final historyProvider = context.read<AttendanceHistoryProvider>();

    // 1. Check Camera Permission (shows the system prompt if not yet granted)
    var cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      cameraStatus = await Permission.camera.request();
    }

    if (!cameraStatus.isGranted) {
      if (!mounted) return;

      // If the user permanently denied it, guide them to app settings.
      if (cameraStatus.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✗ Camera permission is blocked. Enable it in Settings.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Settings',
              textColor: WC.white,
              onPressed: openAppSettings,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✗ Camera permission is required to check in.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // 2. Open front camera and take a photo
    final ImagePicker picker = ImagePicker();
    XFile? image;
    try {
      image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✗ Failed to open camera: $e',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (image == null) return; // User cancelled

    setState(() {
      _isLocalLoading = true;
    });

    try {
      // 3. Convert image to base64
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      // 4. Fetch verified GPS location
      final position = await LocationService().getVerifiedLocation();

      // 5. Submit through the configured attendance service.
      await attendanceSubmissionService.submit(
        latitude: position.latitude,
        longitude: position.longitude,
        base64Image: base64Image,
        attendanceDateTime: DateTime.now(),
      );

      // 6. Perform the regular Geofence Check and check-in
      final canCheckIn = await attendanceProvider.attemptCheckIn(
        widget.employee.id,
      );

      if (!mounted) return;

      if (!canCheckIn) {
        throw Exception(attendanceProvider.error ?? 'Geofence check failed.');
      }

      // 7. Successful geofence and submission - update local state and persist upload status.
      await attendanceProvider.markImageUploaded();

      setState(() {
        _isCheckedIn = true;
        _checkInTime = attendanceProvider.checkInTime;
      });
      _successController.forward();
      _syncPulse();

      // 8. Mark attendance in history (Persists to backend)
      final success = await historyProvider.markAttendanceNow(
        userId: widget.employee.id,
        isPresent: true,
        device: attendanceProvider.deviceModel,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Attendance marked successfully!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.successGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        throw Exception(
          historyProvider.error ?? 'Connection failed. Try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Revert states
      setState(() {
        _isCheckedIn = false;
        _checkInTime = '';
      });
      _successController.reverse();
      _syncPulse();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✗ ${e.toString().replaceAll('Exception: ', '')}',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.errorRed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLocalLoading = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant AttendanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employee.id != widget.employee.id) {
      setState(() {
        _isCheckedIn = widget.employee.isPresentToday;
        _checkInTime = widget.employee.checkInTime ?? '';
      });
      if (_isCheckedIn) {
        _successController.forward();
      } else {
        _successController.reverse();
      }
      _syncPulse();
      context.read<AttendanceHistoryProvider>().loadHistory(widget.employee.id);
    }

    // Pause/resume the pulse when this tab's visibility changes.
    if (oldWidget.isActive != widget.isActive) {
      _syncPulse();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final historyProvider = context.watch<AttendanceHistoryProvider>();
    final submissionService = attendanceSubmissionService;

    bool isCheckedIn;
    if (historyProvider.records.isNotEmpty) {
      isCheckedIn = historyProvider.isPresentToday || _isCheckedIn;
    } else {
      isCheckedIn = _isCheckedIn;
    }

    final now = DateTime.now();
    final dateStr =
        '${_getWeekday(now.weekday)}, ${_getMonth(now.month)} ${now.day}, ${now.year}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Dark Header with Profile
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: WC.black,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Top Navigation Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.fingerprint_rounded,
                              color: WC.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'ATTENDANCE',
                            style: GoogleFonts.dmSans(
                              color: WC.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const Spacer(),
                          const _StatusDot(active: true),
                        ],
                      ),
                    ),
                    // Profile Header
                    AttendanceProfileHeader(employee: widget.employee),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),

          // Body Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Quick Stats Indicator Card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: WC.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFEFEFF4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatItem(
                          label: 'Today',
                          value: isCheckedIn ? '100%' : '0%',
                          color: isCheckedIn ? WC.present : WC.absent,
                        ),
                      ),
                      Container(
                        height: 32,
                        width: 1,
                        color: const Color(0xFFF2F2F7),
                      ),
                      Expanded(
                        child: _StatItem(
                          label: 'Month',
                          value: '92%',
                          color: Colors.blue[600]!,
                        ),
                      ),
                      Container(
                        height: 32,
                        width: 1,
                        color: const Color(0xFFF2F2F7),
                      ),
                      Expanded(
                        child: _StatItem(
                          label: 'On-time',
                          value: '98%',
                          color: Colors.orange[600]!,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Date & Time Display
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F2F7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.calendar_today_rounded,
                              size: 12,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            dateStr,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF8E8E93),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        timeStr,
                        style: GoogleFonts.dmSans(
                          fontSize: 36,
                          color: const Color(0xFF1B1D1F),
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Check-in status display
                CheckInStatusCard(
                  isCheckedIn: isCheckedIn,
                  checkInTime: attendanceProvider.checkInTime.isNotEmpty
                      ? attendanceProvider.checkInTime
                      : _checkInTime,
                  scaleAnimation: _scaleAnimation,
                ),
                const SizedBox(height: 32),

                // Attendance Interaction Button
                AttendanceButton(
                  isCheckedIn: isCheckedIn,
                  isLoading: _isLocalLoading || attendanceProvider.isLoading,
                  pulseAnimation: _pulseAnimation,
                  onTap: _handleCheckIn,
                  isUploadEnabled:
                      attendanceProvider.isUploadEnabled &&
                      submissionService.isAvailable,
                  uploadLabel: submissionService.isAvailable
                      ? attendanceProvider.uploadButtonLabel
                      : submissionService.unavailableMessage,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _getWeekday(int day) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[day - 1];
  }

  String _getMonth(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

class _StatusDot extends StatelessWidget {
  final bool active;
  const _StatusDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: active ? WC.present : WC.absent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (active ? WC.present : WC.absent).withOpacity(0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF8E8E93),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
