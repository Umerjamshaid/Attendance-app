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
import 'package:attendance/widgets/home/attendance_summary_card.dart';
import 'package:attendance/widgets/home/check_in_status_card.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
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

  // Scroll-driven app bar divider. Only the divider rebuilds.
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<bool> _scrolled = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);

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
      CurvedAnimation(parent: _successController, curve: Curves.easeOutBack),
    );

    if (_isCheckedIn) {
      _successController.forward();
    }
    _syncPulse();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    _scrolled.value = _scroll.offset > 4;
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
        throw Exception(
          attendanceProvider.error ?? 'Location validation failed.',
        );
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
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _scrolled.dispose();
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
    final historyLoading =
        historyProvider.isLoading && historyProvider.records.isEmpty;

    return Scaffold(
      backgroundColor: ProfileUi.page,
      body: RefreshIndicator(
        color: AppTheme.primaryNavy,
        backgroundColor: Colors.white,
        // Start the spinner below the pinned app bar.
        edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
        onRefresh: () async {
          HapticFeedback.lightImpact();
          await Future.wait([
            context.read<AttendanceProvider>().initialize(),
            context.read<AttendanceHistoryProvider>().loadHistory(
              widget.employee.id,
            ),
          ]);
        },
        child: CustomScrollView(
          controller: _scroll,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AttendanceProfileHeader(employee: widget.employee),
                      const SizedBox(height: 24),
                      _LiveClockHero(isCheckedIn: isCheckedIn),
                      const SizedBox(height: 16),
                      Center(
                        child: AttendanceButton(
                          isLoading:
                          _isLocalLoading || attendanceProvider.isLoading,
                          pulseAnimation: _pulseAnimation,
                          onTap: _handleCheckIn,
                          isUploadEnabled:
                          attendanceProvider.isUploadEnabled &&
                              submissionService.isAvailable,
                          uploadLabel: submissionService.isAvailable
                              ? attendanceProvider.uploadButtonLabel
                              : submissionService.unavailableMessage,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CheckInStatusCard(
                        isCheckedIn: isCheckedIn,
                        checkInTime: attendanceProvider.checkInTime.isNotEmpty
                            ? attendanceProvider.checkInTime
                            : _checkInTime,
                        scaleAnimation: _scaleAnimation,
                      ),
                      AttendanceSummaryCard(
                        isCheckedIn: isCheckedIn,
                        monthlyRate: historyProvider.monthlyRate,
                        streak: historyProvider.currentStreak,
                        isLoading: historyLoading,
                      ),
                      const _LocationNote(),
                      SizedBox(
                        height: 32 + MediaQuery.paddingOf(context).bottom,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: ProfileUi.page,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: true,
      title: Text('Attendance', style: ProfileUi.body(weight: FontWeight.w600)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: ValueListenableBuilder<bool>(
          valueListenable: _scrolled,
          builder: (_, scrolled, _) => AnimatedOpacity(
            opacity: scrolled ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Divider(height: 1, thickness: 1, color: ProfileUi.hairline),
          ),
        ),
      ),
    );
  }
}

/// Reassurance under the summary: location is not tracked in the background.
class _LocationNote extends StatelessWidget {
  const _LocationNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileUi.gutter + 4,
        4,
        ProfileUi.gutter,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.location_on_outlined,
              size: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Your location is captured only when you submit.',
              style: ProfileUi.caption(),
            ),
          ),
        ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ProfileUi.gutter),
      child: Column(
        children: [
          Text(dateStr, style: ProfileUi.small(weight: FontWeight.w500)),
          const SizedBox(height: 6),
          // The time changes every second, so it is kept out of the
          // accessibility tree and repainted in isolation.
          ExcludeSemantics(
            child: RepaintBoundary(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  timeStr,
                  maxLines: 1,
                  style: GoogleFonts.inter(
                    fontSize: 44,
                    height: 1.15,
                    letterSpacing: -1,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              widget.isCheckedIn
                  ? 'You’re checked in for today'
                  : 'Tap below to mark attendance',
              key: ValueKey(widget.isCheckedIn),
              textAlign: TextAlign.center,
              style: ProfileUi.small(
                weight: FontWeight.w500,
                color: widget.isCheckedIn ? WC.present : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}