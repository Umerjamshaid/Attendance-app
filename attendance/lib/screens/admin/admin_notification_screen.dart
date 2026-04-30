// Screens imports
import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/widgets/notification_tile.dart';

// dart packages
import 'package:flutter/material.dart';
// google fonts
import 'package:google_fonts/google_fonts.dart';

// --- Font Suggestion for a Cleaner, More Professional Look ---
//
// The 'Akatab' font you used is quite stylized and perhaps better for a specific theme.
// For a standard, professional "Admin" screen, a clean, highly readable geometric
// sans-serif font is generally preferred.
//
// I highly recommend 'Inter'. It's incredibly versatile, clean, and has a great
// range of weights, making it a favorite for UI design.
// Other great alternatives: 'Poppins', 'Montserrat', 'Roboto', 'Public Sans'.
//
// Let's use 'Inter' for this screen transformation!

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() =>
      _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  @override
  Widget build(BuildContext context) {
    // --- Body Content based on the image style ---
    return Scaffold(
      backgroundColor: Colors.white, // Clean background
      appBar: AppBar(
        backgroundColor: Colors.white, // Clean background
        elevation: 0, // No shadow
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: WC.muted, // Standard dark red color from the image
            size: 18, // Adjust size
          ),
          onPressed: () =>
              Navigator.of(context).pop(), // Functional back button
        ),
        title: Text(
          'NOTIFICATIONS', // Capitalized title
          style: GoogleFonts.inter(
            // Use Inter font here
            fontSize: 16, // Size similar to image
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1B1D1F), // Dark charcoal, not pure black
            letterSpacing: 1.2, // To mimic the geometric spacing
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          SizedBox(height: 16), // Top padding
          // Replicating Item 1 from the image
          NotificationTile(
            isUnread: true,
            titleSpans: [
              TextSpan(text: 'Admin, você ganhou '),
              TextSpan(
                text: '2 meses grátis',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextSpan(text: ' 💰'),
            ],
            description: 'Em cupons pra qualquer restaurante! Aproveite aqui',
            time: '09:22',
          ),

          // Replicating Item 2 from the image
          NotificationTile(
            isUnread: false,
            titleSpans: [
              TextSpan(
                text: '😁 Pra fazer sua alegria!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
            description: 'Vem pro canal do zap aproveitar as ofertas. Bora!',
            time: '18/06',
          ),

          // Add a couple more examples to fill the space
          NotificationTile(
            isUnread: false,
            titleSpans: [
              TextSpan(
                text: 'Sua entrega foi confirmada!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
            description: 'Aproveite seu prato! Nos avalie.',
            time: '23/06',
          ),
          NotificationTile(
            isUnread: true,
            titleSpans: [
              TextSpan(
                text: 'Nova oferta de ',
                style: TextStyle(color: Colors.black87),
              ),
              TextSpan(
                text: 'Pizza Hut',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
              TextSpan(
                text: '!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ],
            description: '50% de desconto na sua próxima compra.',
            time: '24/06',
          ),

          SizedBox(height: 32), // Bottom padding
        ],
      ),
    );
  }
}
