import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/screens/admin/admin_dashboard_screen.dart';
import 'package:attendance/screens/admin/admin_notification_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.white, // Clean background
      appBar: AppBar(
        backgroundColor: Colors.white, // Clean background
        elevation: 0, // No shadow

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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (user != null) ...[
              Text(
                'Welcome, ${user.name}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ID: ${user.id} | ${user.department}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => auth.logout(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
