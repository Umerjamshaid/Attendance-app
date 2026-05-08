import 'package:attendance/config/wc_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(
          'PRIVACY POLICY',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1B1D1F),
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Data Collection',
              'We collect the following information:\n'
                  '• Employee ID\n'
                  '• Device information (model, OS)\n'
                  '• Location data (GPS coordinates)\n'
                  '• Attendance timestamps\n\n'
                  'This information is used solely for attendance tracking purposes.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Data Storage',
              'Your data is securely encrypted and stored on our secure servers. Access tokens are encrypted using industry-standard encryption protocols.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Data Usage',
              'Your attendance data will be used to:\n'
                  '• Track your attendance records\n'
                  '• Generate attendance reports\n'
                  '• Prevent attendance fraud through GPS verification\n\n'
                  'We do not share your data with third parties.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Device Permissions',
              'The app requests:\n'
                  '• Location Permission - For GPS-based attendance\n'
                  '• Device ID - For device identification\n\n'
                  'You can revoke these permissions anytime in your device settings.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Data Retention',
              'Attendance records are retained for 1 year. You can request data deletion by contacting your administrator.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Contact',
              'For privacy concerns, please contact your IT administrator or email: privacy@company.com',
            ),
            const SizedBox(height: 32),
            Text(
              'Last Updated: May 2026',
              style: GoogleFonts.inter(fontSize: 12, color: WC.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1B1D1F),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: GoogleFonts.inter(fontSize: 14, color: WC.muted, height: 1.6),
        ),
      ],
    );
  }
}
