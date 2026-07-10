import 'package:attendance/config/wc_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DeviceInfoWidget extends StatelessWidget {
  final String device;
  final String? label;
  final bool compact;

  const DeviceInfoWidget({
    super.key,
    required this.device,
    this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayDevice = device.trim().isEmpty ? 'Unknown device' : device;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 7 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WC.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.phone_android_rounded,
            size: compact ? 14 : 16,
            color: WC.accentBlue,
          ),
          SizedBox(width: compact ? 6 : 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null && label!.trim().isNotEmpty) ...[
                  Text(
                    label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: WC.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  displayDevice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B1D1F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
