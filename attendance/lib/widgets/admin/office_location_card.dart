import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/widgets/admin/mini_chip.dart';
import 'package:flutter/material.dart';

class OfficeLocationCard extends StatelessWidget {
  final VoidCallback onEdit;
  const OfficeLocationCard({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WC.card,
        borderRadius: WC.r16,
        border: Border.all(color: WC.border),
        boxShadow: WC.shadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: WC.bg, borderRadius: WC.r12),
            child: const Icon(
              Icons.business_rounded,
              color: WC.black,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Office Location',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: WC.black,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Osquare',
                  style: TextStyle(fontSize: 12, color: WC.muted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    MiniChip(
                      icon: Icons.location_on_rounded,
                      label: '24.00, 67.00',
                    ),
                    const SizedBox(width: 6),
                    MiniChip(icon: Icons.radar_rounded, label: '100 m'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: WC.black,
                borderRadius: WC.rFull,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, color: WC.white, size: 13),
                  SizedBox(width: 5),
                  Text(
                    'Edit',
                    style: TextStyle(
                      color: WC.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
