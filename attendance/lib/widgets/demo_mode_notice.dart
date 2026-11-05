import 'package:attendance/config/app_icons.dart';
import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class DemoModeNotice extends StatelessWidget {
  const DemoModeNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          context.attendanceWarning.withValues(alpha: .08),
          context.colors.surface,
        ),
        border: Border.all(
          color: context.attendanceWarning.withValues(alpha: .35),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.infoCircle, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Demo data only. This screen is not connected to a live attendance backend.',
              style: TextStyle(
                color: context.colors.onSurface,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
