import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/widgets/home/attendance_button.dart';
import 'package:attendance/widgets/home/attendance_profile_header.dart';
import 'package:attendance/widgets/home/check_in_status_card.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../config/wc_tokens.dart';
import '../../widgets/option_card_widget.dart';

import 'package:flutter/material.dart';

class AttendanceScreen extends StatefulWidget {
  final Employee employee;

  const AttendanceScreen({
    super.key,
    required this.employee,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with TickerProviderStateMixin {
  bool _isCheckedIn = false;
  String _checkInTime = '';
  late AnimationController _pulseController;
  late AnimationController _successController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _isCheckedIn = widget.employee.isPresentToday;
    _checkInTime = widget.employee.checkInTime ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().initialize();
    });

    // Pulse animation for fingerprint
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Success animation
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    if (_isCheckedIn) {
      _pulseController.stop();
      _successController.forward();
    }
  }

  void _handleCheckIn() async {
    final attendanceProvider = context.read<AttendanceProvider>();

    final success = await attendanceProvider.submitAttendance(
      userId: widget.employee.id,
      isPresent: true,
      device: attendanceProvider.deviceModel,
    );

    if (success) {
      setState(() => _isCheckedIn = true);
      _pulseController.stop();
      _successController.forward();

      // Haptic feedback
      HapticFeedback.mediumImpact();

      final now = DateTime.now();
      setState(() {
        _checkInTime =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
      });

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: WC.white),
              SizedBox(width: 12),
              Text('Successfully checked in!'),
            ],
          ),
          backgroundColor: WC.present,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: WC.r12),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(attendanceProvider.error ?? 'Failed to check in'),
          backgroundColor: WC.absent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final isLoading = attendanceProvider.isLoading;

    final now = DateTime.now();
    final dateStr =
        '${_getWeekday(now.weekday)}, ${_getMonth(now.month)} ${now.day}, ${now.year}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

    return Scaffold(
      backgroundColor: WC.bg,
      body: Stack(
        children: [
          // Header Background
          Container(
            height: 320,
            width: double.infinity,
            decoration: const BoxDecoration(color: WC.black),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: WC.white.withOpacity(0.15),
                          borderRadius: WC.r12,
                        ),
                        child: const Icon(
                          Icons.location_city_rounded,
                          color: WC.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Attendance',
                        style: TextStyle(
                          color: WC.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                // Profile Section (EXTRACTED)
                AttendanceProfileHeader(employee: widget.employee),

                const SizedBox(height: 16),

                // White Card Section
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: WC.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Date & Time
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: WC.muted,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: WC.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_filled_rounded,
                                size: 18,
                                color: WC.black,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  fontSize: 22,
                                  color: WC.black,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Check-in Status (EXTRACTED)
                          CheckInStatusCard(
                            isCheckedIn: _isCheckedIn,
                            checkInTime: _checkInTime,
                            scaleAnimation: _scaleAnimation,
                          ),

                          const SizedBox(height: 32),

                          // Fingerprint Button (EXTRACTED)
                          AttendanceButton(
                            isCheckedIn: _isCheckedIn,
                            isLoading: isLoading,
                            pulseAnimation: _pulseAnimation,
                            onTap: _handleCheckIn,
                          ),

                          const SizedBox(height: 48),

                          // Options Row
                          Row(
                            children: [
                              Expanded(
                                child: OptionCard(
                                  icon: Icons.location_on_rounded,
                                  label: 'GPS',
                                  subtitle: 'Enabled',
                                  color: WC.accentBlue,
                                  onTap: () {},
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OptionCard(
                                  icon: Icons.business_rounded,
                                  label:
                                      attendanceProvider.officeLocation?.name ??
                                      'Office',
                                  subtitle:
                                      '${attendanceProvider.officeLocation?.radiusInMeters.toInt() ?? 0} m',
                                  color: WC.present,
                                  onTap: () {},
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OptionCard(
                                  icon: Icons.devices_rounded,
                                  label: 'Device',
                                  subtitle: attendanceProvider.deviceModel,
                                  color: WC.black,
                                  onTap: () {},
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getWeekday(int day) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
