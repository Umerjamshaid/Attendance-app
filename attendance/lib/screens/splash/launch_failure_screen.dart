import 'package:flutter/material.dart';

import '../../config/app_icons.dart';
import '../../config/app_info.dart';
import '../../config/ui_tokens.dart';

class LaunchFailureScreen extends StatelessWidget {
  const LaunchFailureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: colors.errorContainer,
                    foregroundColor: colors.onErrorContainer,
                    child: const Icon(AppIcons.alertCircle, size: 28),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "${AppInfo.name} couldn't start",
                    textAlign: TextAlign.center,
                    style: AppTypography.title.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Close the app, then open it again.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
