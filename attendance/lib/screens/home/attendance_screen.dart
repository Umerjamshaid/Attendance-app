import 'dart:async';
import 'dart:convert';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/config/wc_tokens.dart';
import 'package:flutter/services.dart';
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
        employeeId: widget.employee.id,
        latitude: position.latitude,
        longitude: position.longitude,
        base64Image: base64Image,
        attendanceDateTime: DateTime.now(),
      );

      // 6. Run the local location validation and update check-in state.
      final canCheckIn = await attendanceProvider.attemptCheckIn(
        widget.employee.id,
      );

      if (!mounted) return;

      if (!canCheckIn) {
        throw Exception(attendanceProvider.error ?? 'Location validation failed.');
      }

      // 7. Successful validation and submission - update local state.
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: RefreshIndicator(
        color: const Color(0xFF1A1F71),
        backgroundColor: Colors.white,
        onRefresh: () async {
          HapticFeedback.lightImpact();
          await Future.wait([
            context.read<AttendanceProvider>().initialize(),
            context.read<AttendanceHistoryProvider>().loadHistory(widget.employee.id),
          ]);
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // ─── Executive Obsidian Header with Profile ───────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0B132B),
                      Color(0xFF0F172A),
                      Color(0xFF1E293B),
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(36),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x330B132B),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // Top Navigation Bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                        child: Row(
                          children: [
                            // App icon with executive emerald shield halo
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF10B981),
                                    Color(0xFF059669),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.fingerprint_rounded,
                                color: WC.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ATTENDANCE',
                                  style: GoogleFonts.dmSans(
                                    color: WC.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Secure point-in-time attendance',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Live status indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF334155),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const _StatusDot(active: true),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ACTIVE',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF10B981),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Profile Header
                      AttendanceProfileHeader(employee: widget.employee),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Body Content ───────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ─── Check-in trust cue ─────────────────────────────
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: WC.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.radar_rounded,
                            color: Color(0xFF0EA5E9),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CHECK-IN LOCATION',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Captured only when you submit',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: Color(0xFF10B981),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'READY',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF059669),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── Executive Stats Card ─────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      color: WC.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatItem(
                            label: 'Today',
                            value: isCheckedIn ? '100%' : '0%',
                            color: isCheckedIn
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            icon: isCheckedIn
                                ? Icons.check_circle_outline_rounded
                                : Icons.radio_button_unchecked,
                          ),
                        ),
                        _StatDivider(),
                        Expanded(
                          child: _StatItem(
                            label: 'Month',
                            value: '92%',
                            color: const Color(0xFF0EA5E9),
                            icon: Icons.calendar_month_rounded,
                          ),
                        ),
                        _StatDivider(),
                        Expanded(
                          child: _StatItem(
                            label: 'On-time',
                            value: '98%',
                            color: const Color(0xFFF59E0B),
                            icon: Icons.timer_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ─── Live Date & Time Hero Section ───────────────────
                  _LiveClockHero(isCheckedIn: isCheckedIn),
                  const SizedBox(height: 28),

                  // ─── Check-in Status Card ─────────────────────────────
                  CheckInStatusCard(
                    isCheckedIn: isCheckedIn,
                    checkInTime: attendanceProvider.checkInTime.isNotEmpty
                        ? attendanceProvider.checkInTime
                        : _checkInTime,
                    scaleAnimation: _scaleAnimation,
                  ),
                  const SizedBox(height: 36),

                  // ─── Attendance Button ────────────────────────────────
                  AttendanceButton(
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
      ),
    );
  }
}

// ─── Live Clock Hero ──────────────────────────────────────────────────
class _LiveClockHero extends StatefulWidget {
  final bool isCheckedIn;
  const _LiveClockHero({required this.isCheckedIn});

  @override
  State<_LiveClockHero> createState() => _LiveClockHeroState();
}

class _LiveClockHeroState extends State<_LiveClockHero> {
  late DateTime _currentTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      if (now.second != _currentTime.second) {
        setState(() {
          _currentTime = now;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final now = _currentTime;
    final dateStr =
        '${_getWeekday(now.weekday)}, ${_getMonth(now.month)} ${now.day}, ${now.year}';
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final timeStr =
        '${hour12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 26),
        decoration: BoxDecoration(
          color: WC.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Date pill
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: Color(0xFF0EA5E9),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateStr,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Large live time display
            Text(
              timeStr,
              style: GoogleFonts.dmSans(
                fontSize: 38,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.isCheckedIn
                  ? "✓ You're checked in for today"
                  : 'Tap below to mark attendance',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: widget.isCheckedIn
                    ? const Color(0xFF10B981)
                    : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Live Status Dot ──────────────────────────────────────────────────
class _StatusDot extends StatelessWidget {
  final bool active;
  const _StatusDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF4ADE80) : const Color(0xFFEF4444),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (active
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFEF4444))
                  .withValues(alpha: 0.5),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Divider ─────────────────────────────────────────────────────
class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFE5E7EB).withValues(alpha: 0),
            const Color(0xFFE5E7EB),
            const Color(0xFFE5E7EB).withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Item with Icon ──────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon badge
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF9CA3AF),
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}
