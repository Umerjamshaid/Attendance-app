import 'package:flutter/material.dart';
import '../../config/wc_tokens.dart';
import '../../models/employees_model.dart';

class AttendanceProfileHeader extends StatelessWidget {
  final Employee employee;

  const AttendanceProfileHeader({
    super.key,
    required this.employee,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = employee.avatarUrl ??
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(employee.name)}&background=000&color=fff&size=200';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 12,
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: WC.present, width: 2.5),
              image: DecorationImage(
                image: NetworkImage(avatarUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            employee.name,
            style: const TextStyle(
              color: WC.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: WC.white.withOpacity(0.1),
              borderRadius: WC.rFull,
            ),
            child: Text(
              employee.department,
              style: const TextStyle(
                color: WC.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
