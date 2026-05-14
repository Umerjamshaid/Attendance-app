import 'package:attendance/config/app_theme.dart';
import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/widgets/home/attendance_button.dart';
import 'package:attendance/widgets/home/attendance_profile_header.dart';
import 'package:attendance/widgets/home/check_in_status_card.dart';
import 'package:attendance/widgets/option_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AttendanceScreen extends StatefulWidget {
  final Employee employee;

  const AttendanceScreen({super.key, required this.employee});

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
      context.read<AttendanceHistoryProvider>().loadHistory(widget.employee.id);
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

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
      _pulseController.stop();
      _successController.forward();
    }
  }

  void _handleCheckIn() async {
    final attendanceProvider = context.read<AttendanceProvider>();
    final historyProvider = context.read<AttendanceHistoryProvider>();

    // 1. Perform Secure Geofence Check
    final canCheckIn = await attendanceProvider.attemptCheckIn(widget.employee.id);

    if (!canCheckIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✗ ${attendanceProvider.error}',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 2. Successful Geofence check - Update local UI state
    setState(() {
      _isCheckedIn = true;
      _checkInTime = attendanceProvider.checkInTime;
    });
    _pulseController.stop();
    _successController.forward();

    // 3. Mark attendance in history (Persists to backend)
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
      // Revert if backend submission failed
      setState(() {
        _isCheckedIn = false;
        _checkInTime = '';
      });
      _pulseController.repeat(reverse: true);
      _successController.reverse();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✗ ${historyProvider.error ?? 'Connection failed. Try again.'}',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.errorRed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
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
        _pulseController.stop();
        _successController.forward();
      } else {
        _pulseController.repeat(reverse: true);
        _successController.reverse();
      }
      context.read<AttendanceHistoryProvider>().loadHistory(widget.employee.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final historyProvider = context.watch<AttendanceHistoryProvider>();

    bool isCheckedIn;
    if (historyProvider.records.isNotEmpty) {
      isCheckedIn = historyProvider.isPresentToday || _isCheckedIn;
    } else {
      isCheckedIn = _isCheckedIn;
    }

    final isLoading = attendanceProvider.isLoading || historyProvider.isLoading;

    final now = DateTime.now();
    final dateStr =
        '${_getWeekday(now.weekday)}, ${_getMonth(now.month)} ${now.day}, ${now.year}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

    return Scaffold(
      backgroundColor: WC.black,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2A2A2A)),
                        ),
                        child: Icon(
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
                      _StatusDot(active: true),
                    ],
                  ),
                ),
                AttendanceProfileHeader(employee: widget.employee),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    width: double.infinity,
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
                          // Surprise: Quick Stats Indicator
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFF0F0F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                _StatCircle(
                                  label: 'Today',
                                  value: isCheckedIn ? '100%' : '0%',
                                  color: isCheckedIn ? WC.present : WC.absent,
                                ),
                                const Spacer(),
                                _StatCircle(
                                  label: 'Month',
                                  value: '92%',
                                  color: Colors.blue[700]!,
                                ),
                                const Spacer(),
                                _StatCircle(
                                  label: 'On-time',
                                  value: '98%',
                                  color: Colors.orange[700]!,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: Color(0xFF999999),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                dateStr,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF999999),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            timeStr,
                            style: GoogleFonts.dmSans(
                              fontSize: 32,
                              color: const Color(0xFF1B1D1F),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          CheckInStatusCard(
                            isCheckedIn: isCheckedIn,
                            checkInTime: _checkInTime,
                            scaleAnimation: _scaleAnimation,
                          ),
                          const SizedBox(height: 36),
                          AttendanceButton(
                            isCheckedIn: isCheckedIn,
                            isLoading: isLoading,
                            pulseAnimation: _pulseAnimation,
                            onTap: _handleCheckIn,
                          ),
                          const SizedBox(height: 48),
                          Row(
                            children: [
                              Expanded(
                                child: OptionCard(
                                  icon: Icons.location_on_rounded,
                                  label: 'GPS',
                                  subtitle: 'Active',
                                  color: Colors.blue[700]!,
                                  onTap: () {},
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OptionCard(
                                  icon: Icons.business_rounded,
                                  label:
                                      attendanceProvider
                                          .officeLocation
                                          ?.name ??
                                      'Office',
                                  subtitle:
                                      '${attendanceProvider.officeLocation?.radiusInMeters.toInt() ?? 0}m',
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
                                  color: const Color(0xFF1B1D1F),
                                  onTap: () {},
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
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
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? WC.present : WC.absent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (active ? WC.present : WC.absent).withValues(alpha: 0.5),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }
}

class _StatCircle extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCircle({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF999999),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
