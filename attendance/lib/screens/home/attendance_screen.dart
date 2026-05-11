import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/models/attendance_record_model.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/widgets/home/attendance_button.dart';
import 'package:attendance/widgets/home/attendance_profile_header.dart';
import 'package:attendance/widgets/home/check_in_status_card.dart';
import 'package:attendance/widgets/option_card_widget.dart';
import 'package:flutter/material.dart';
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
      // Load history so we know if we are already checked in
      context.read<AttendanceHistoryProvider>().loadHistory(widget.employee.id);
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
    final historyProvider = context.read<AttendanceHistoryProvider>();

    // 1. Instant UI Feedback (Local Screen State)
    setState(() {
      _isCheckedIn = true;
      final now = DateTime.now();
      _checkInTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
    _pulseController.stop();
    _successController.forward();

    // 2. Trigger Optimistic Update in Provider (for History Screen)
    final success = await historyProvider.markAttendanceNow(
      userId: widget.employee.id,
      isPresent: true,
      device: attendanceProvider.deviceModel,
    );

    if (!mounted) return; // Exit if the widget is no longer in the tree

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Attendance marked instantly!'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Revert if failed
      setState(() {
        _isCheckedIn = false;
        _checkInTime = '';
      });
      _pulseController.repeat(reverse: true);
      _successController.reverse();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✗ Failed to mark attendance. Reverting...'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant AttendanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the logged in user changed, reset the local optimistic state
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
      // Reload history for the new user
      context.read<AttendanceHistoryProvider>().loadHistory(widget.employee.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final historyProvider = context.watch<AttendanceHistoryProvider>();
    
    // The "Single Source of Truth" strategy:
    // 1. If history is already loaded, trust its 'isPresentToday' getter completely.
    // 2. If history is still loading or empty, fallback to the initial employee state OR our local optimistic state.
    
    bool isCheckedIn;
    if (historyProvider.records.isNotEmpty) {
      isCheckedIn = historyProvider.isPresentToday || _isCheckedIn;
    } else {
      isCheckedIn = _isCheckedIn;
    }
    
    final isLoading = attendanceProvider.isLoading || historyProvider.isLoading;

    final now = DateTime.now();
    final dateStr = '${_getWeekday(now.weekday)}, ${_getMonth(now.month)} ${now.day}, ${now.year}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

    return Scaffold(
      backgroundColor: WC.bg,
      body: Stack(
        children: [
          Container(
            height: 320,
            width: double.infinity,
            decoration: const BoxDecoration(color: WC.black),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: WC.white.withOpacity(0.15),
                          borderRadius: WC.r12,
                        ),
                        child: const Icon(Icons.location_city_rounded, color: WC.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Attendance',
                        style: TextStyle(color: WC.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                AttendanceProfileHeader(employee: widget.employee),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: WC.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 16, color: WC.muted),
                              const SizedBox(width: 10),
                              Text(dateStr, style: const TextStyle(fontSize: 14, color: WC.muted, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time_filled_rounded, size: 18, color: WC.black),
                              const SizedBox(width: 8),
                              Text(timeStr, style: const TextStyle(fontSize: 22, color: WC.black, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          CheckInStatusCard(
                            isCheckedIn: isCheckedIn,
                            checkInTime: _checkInTime,
                            scaleAnimation: _scaleAnimation,
                          ),
                          const SizedBox(height: 32),
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
                                  subtitle: 'Enabled',
                                  color: WC.accentBlue,
                                  onTap: () {},
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OptionCard(
                                  icon: Icons.business_rounded,
                                  label: attendanceProvider.officeLocation?.name ?? 'Office',
                                  subtitle: '${attendanceProvider.officeLocation?.radiusInMeters.toInt() ?? 0} m',
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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
