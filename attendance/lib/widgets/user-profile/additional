Here's what I improved in each file:

**`AttendanceStatsCard`** — extracted a `_StatColumn` widget to eliminate the triple repetition, made dividers subtler, tweaked label weight from `w100` → `w300` (more readable), and gave leaves a proper amber color instead of `white38`.

**`ProfileHeader`** — fixed the `•` separator (was a plain `.`), added a role `Chip` badge, removed the unused `wc_tokens` import, and `const`-ified fixed values.

**`ProfileMenuItem`** — **fixed a silent bug**: `textColor` was accepted but never applied. Now it colors both the title and leading icon, making the red logout actually red.

```dart
// attendance_stats_card.dart

import 'package:attendance/models/employees_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AttendanceStatsCard extends StatelessWidget {
  final Employee employee;
  const AttendanceStatsCard({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: const Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _StatColumn(
                value: '${employee.totalPresents}',
                label: 'Presents',
                valueColor: Colors.greenAccent,
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              _StatColumn(
                value: '${employee.totalAbsents}',
                label: 'Absents',
                valueColor: Colors.redAccent,
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              _StatColumn(
                value: '${employee.totalLeaves}',
                label: 'Leaves',
                valueColor: Colors.amber,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _StatColumn({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w300,
              color: Colors.grey[400],
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
```

```dart
// profile_header.dart

import 'package:attendance/models/employees_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileHeader extends StatelessWidget {
  final Employee employee;

  const ProfileHeader({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Banner
            Container(
              height: 150,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF03253D), Color(0xFF05446E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Avatar
            Positioned(
              bottom: -50,
              child: CircleAvatar(
                radius: 52,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 49,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: employee.avatarUrl != null
                      ? NetworkImage(employee.avatarUrl!)
                      : null,
                  child: employee.avatarUrl == null
                      ? const Icon(
                          Icons.person_2_rounded,
                          size: 50,
                          color: Colors.grey,
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 62),

        // Name
        Text(
          employee.name,
          style: GoogleFonts.dmSans(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),

        // Department · ID
        Text(
          '${employee.department} • ${employee.id}',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 10),

        // Role badge
        Chip(
          label: Text(
            employee.role,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF03253D),
            ),
          ),
          backgroundColor: const Color(0xFFD6EAF8),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
```

```dart
// profile_menu_item.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? textColor;

  const ProfileMenuItem({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? Theme.of(context).colorScheme.onSurface;

    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: Colors.grey[400],
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    );
  }
}
```

The silent `textColor` bug was the most important fix — without it your logout button appeared black like every other item, which undermines the whole visual warning signal.
