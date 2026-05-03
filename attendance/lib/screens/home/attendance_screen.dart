import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../config/wc_tokens.dart';
import '../../widgets/option_card_widget.dart';

class AttendanceScreen extends StatefulWidget {
  final String employeeName;
  final String employeeId;
  final String department;

  const AttendanceScreen({
    super.key,
    required this.employeeName,
    required this.employeeId,
    required this.department,
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
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );
  }

  void _handleCheckIn() async {
    final attendanceProvider = context.read<AttendanceProvider>();

    final success = await attendanceProvider.submitAttendance(
      userId: widget.employeeId,
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

    final avatarUrl =
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(widget.employeeName)}&background=000&color=fff&size=200';

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
                        'WorkCheck',
                        style: TextStyle(
                          color: WC.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                // Profile Section
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      // Avatar
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: WC.present, width: 2.5),
                          image: DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.employeeName,
                        style: const TextStyle(
                          color: WC.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: WC.white.withOpacity(0.1),
                          borderRadius: WC.rFull,
                        ),
                        child: Text(
                          widget.department,
                          style: const TextStyle(
                            color: WC.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

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

                          // Check-in Status
                          if (_isCheckedIn)
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: WC.present.withOpacity(0.08),
                                  borderRadius: WC.r16,
                                  border: Border.all(
                                    color: WC.present.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: WC.present,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Checked in today at',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: WC.muted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            _checkInTime,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              color: WC.present,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 32),

                          // Fingerprint Button
                          GestureDetector(
                            onTap: (_isCheckedIn || isLoading)
                                ? null
                                : _handleCheckIn,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isCheckedIn ? WC.present : WC.black,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (_isCheckedIn ? WC.present : WC.black)
                                            .withOpacity(0.2),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ScaleTransition(
                                scale: _isCheckedIn
                                    ? const AlwaysStoppedAnimation(1.0)
                                    : _pulseAnimation,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isLoading)
                                      const CircularProgressIndicator(
                                        color: WC.white,
                                      )
                                    else ...[
                                      Icon(
                                        _isCheckedIn
                                            ? Icons.check_circle_rounded
                                            : Icons.fingerprint_rounded,
                                        size: 64,
                                        color: WC.white,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _isCheckedIn
                                            ? 'Checked In'
                                            : 'Mark\nAttendance',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: WC.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
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
