import 'package:attendance/config/wc_tokens.dart';
import 'package:flutter/material.dart';

class MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const MiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: WC.bg,
        borderRadius: WC.r8,
        border: Border.all(color: WC.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 10, color: WC.muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: WC.muted,
            ),
          ),
        ],
      ),
    );
  }
}
