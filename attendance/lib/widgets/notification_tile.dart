// Reusable Notification Tile Widget
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationTile extends StatelessWidget {
  final List<TextSpan> titleSpans;
  final String description;
  final String time;
  final bool isUnread;

  const NotificationTile({
    super.key,
    required this.titleSpans,
    required this.description,
    required this.time,
    required this.isUnread,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isUnread ? Colors.grey[200] : Colors.transparent,
      // padding: const EdgeInsets.symmetric(vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Tile (Placeholder for the pink pattern)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE), // Light pink background
                borderRadius: BorderRadius.circular(10),
                // We'll mimic the pattern with small icons
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Icon(Icons.cake, color: Color(0xFFEF9A9A), size: 10),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Icon(
                      Icons.room_service,
                      color: Color(0xFFEF9A9A),
                      size: 10,
                    ),
                  ),
                  Positioned(
                    top: 18,
                    right: 18,
                    child: Icon(
                      Icons.delivery_dining,
                      color: Color(0xFFEF9A9A),
                      size: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                      children: titleSpans,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF71777C),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Time
            Text(
              time,
              style: GoogleFonts.inter(
                color: const Color(0xFF71777C),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
