import 'package:flutter/material.dart';

import '../../config/app_info.dart';
import '../../widgets/app_identity_footer.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: Semantics(
                  label: 'Loading ${AppInfo.name}',
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: reduceMotion ? 1.0 : 0.94,
                            end: 1.0,
                          ),
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          builder: (_, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: const AttendanceMark(size: 112),
                        ),
                        const SizedBox(height: 20),
                        SizedBox.square(
                          dimension: 18,
                          child: reduceMotion
                              ? null
                              : const CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const AppIdentityFooter(showMark: false),
          ],
        ),
      ),
    );
  }
}
