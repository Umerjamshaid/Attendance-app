import 'package:flutter/material.dart';

class DemoModeNotice extends StatelessWidget {
  const DemoModeNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        border: Border.all(color: const Color(0xFFF2D39B)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF8A5A00), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Demo data only. This screen is not connected to a live attendance backend.',
              style: TextStyle(
                color: Color(0xFF684400),
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
