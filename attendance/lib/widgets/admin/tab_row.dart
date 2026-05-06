import 'package:attendance/config/wc_tokens.dart';
import 'package:flutter/material.dart';

class TabItem extends StatelessWidget {
  final String label;
  final int index, activeTab;
  final ValueChanged<int> onTap;
  const TabItem({
    required this.label,
    required this.index,
    required this.activeTab,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == activeTab;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? WC.white : const Color(0xFF555555),
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ),
          Container(
            height: 2.5,
            width: isActive ? 28 : 0,
            decoration: BoxDecoration(color: WC.white, borderRadius: WC.rFull),
          ),
        ],
      ),
    );
  }
}

class TabRow extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTap;
  const TabRow({required this.activeTab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TabItem(label: 'All', index: 0, activeTab: activeTab, onTap: onTap),
        TabItem(label: 'Present', index: 1, activeTab: activeTab, onTap: onTap),
        TabItem(label: 'Absent', index: 2, activeTab: activeTab, onTap: onTap),
      ],
    );
  }
}
