import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/auth_provider.dart';

import 'package:attendance/screens/admin/admin_notification_screen.dart';
import 'package:attendance/widgets/user-profile/attendance_stats_card.dart';
import 'package:attendance/widgets/user-profile/profile_header.dart';
import 'package:attendance/widgets/user-profile/profile_menu_item.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dummyUser = Employee(
      id: 'PIP-2024-118',
      name: 'Jamshiad-Riaz',
      email: 'jamshiad.riaz@example.com',
      role: 'Dupty-Admin',
      department: 'Exam',
      avatarUrl: null,
      totalAbsents: 5,
      totalPresents: 203,
      totalLeaves: 15,
    );

    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50], // Clean background
        elevation: 0, // No shadow
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: WC.muted,
              size: 22,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AdminNotificationScreen(),
                ),
              );
            },
          ),
        ],

        title: Text(
          'YOUR PROFILE',
          style: GoogleFonts.inter(
            // Use Inter font here
            fontSize: 20, // Size similar to image
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1B1D1F), // Dark charcoal, not pure black
            letterSpacing: 1.2, // To mimic the geometric spacing
          ),
        ),
        // centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              ProfileHeader(employee: dummyUser),

              SizedBox(height: 30),

              AttendanceStatsCard(employee: dummyUser),

              SizedBox(height: 20),

              Column(
                children: [
                  ProfileMenuItem(
                    icon: Icons.lock_outline,
                    title: 'Privacy Policy',
                    onTap: () => print('Privacy Pressed'),
                  ),
                  Divider(indent: 20, endIndent: 20),
                  ProfileMenuItem(
                    icon: Icons.logout,
                    title: 'Log Out',
                    onTap: () => {context.read<AuthProvider>().logout()},
                    textColor: Colors
                        .red, // Senior move: Allow custom colors for logout
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
