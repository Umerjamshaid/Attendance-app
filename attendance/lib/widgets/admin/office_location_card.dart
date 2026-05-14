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
        color: WC.white,
        borderRadius: WC.r20,
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: WC.r16,
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: const Icon(
              Icons.business_rounded,
              color: Color(0xFF1B1D1F),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1D1F),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Osquare Headquarters',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _LightMiniChip(
                      icon: Icons.location_on_rounded,
                      label: '24.00, 67.00',
                    ),
                    const SizedBox(width: 6),
                    _LightMiniChip(icon: Icons.radar_rounded, label: '100 m'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1D1F),
                borderRadius: WC.rFull,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, color: WC.white, size: 13),
                  SizedBox(width: 6),
                  Text(
                    'Edit',
                    style: TextStyle(
                      color: WC.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
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

class _LightMiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _LightMiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: WC.r8,
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 10, color: Color(0xFF888888)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF888888),
            ),
          ),
        ],
      ),
    );
  }
}
