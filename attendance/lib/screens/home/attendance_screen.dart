import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => AttendanceScreen();
}

class AttendanceScreen extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<double> _rippleRadius;

  @override
  void initState() {
    super.initState();

    // Single controller orchestrates the entire sequence smoothly
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Logo pop-in effect
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    // Ripple expands behind the logo
    _rippleRadius = Tween<double>(begin: 40.0, end: 180.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    // Text fades in slightly after the logo
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.8, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Navigate to the main app after the animation completes
    // _controller.addStatusListener((status) {
    //   if (status == AnimationStatus.completed) {
    //     // Slight delay to let the user appreciate the splash screen
    //     Future.delayed(const Duration(milliseconds: 400), () {
    //       if (mounted) {
    //         Navigator.pushReplacement(
    //           context,
    //           PageRouteBuilder(
    //             pageBuilder: (_, __, ___) =>
    //                 AttendanceScreen(), // Change to your main screen
    //             transitionsBuilder: (_, animation, __, child) {
    //               // Smooth fade transition instead of a harsh slide
    //               return FadeTransition(opacity: animation, child: child);
    //             },
    //           ),
    //         );
    //       }
    //     });
    //   }
    // });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Container(
        // Subtle ambient gradient background
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.8,
            colors: [
              const Color(0xFF1E1E33).withOpacity(0.8),
              const Color(0xFF0F0F1A),
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo & Ripple Container
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Expanding Ripple 1
                      if (_rippleRadius.value > 40)
                        Container(
                          width: _rippleRadius.value,
                          height: _rippleRadius.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(
                                0xFF7C5CFC,
                              ).withOpacity(0.3 * (1 - _controller.value)),
                              width: 2,
                            ),
                          ),
                        ),
                      // Expanding Ripple 2 (Delayed)
                      if (_rippleRadius.value > 80)
                        Container(
                          width: _rippleRadius.value - 40,
                          height: _rippleRadius.value - 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(
                                0xFF7C5CFC,
                              ).withOpacity(0.2 * (1 - _controller.value)),
                              width: 1.5,
                            ),
                          ),
                        ),

                      // Glowing Logo Box
                      Transform.scale(
                        scale: _logoScale.value,
                        child: Opacity(
                          opacity: _logoOpacity.value,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C5CFC),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF7C5CFC,
                                  ).withOpacity(0.5),
                                  blurRadius: 40,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons
                                  .bolt_rounded, // Change to your app logo asset/icon
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // App Name
                  Opacity(
                    opacity: _textOpacity.value,
                    child: Column(
                      children: [
                        Text(
                          'ATTENDANCE', // Your App Name
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ' Seamless. Smart. Secure.', // Tagline
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
