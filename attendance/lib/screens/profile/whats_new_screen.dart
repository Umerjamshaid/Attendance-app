import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/app_info.dart';
import 'settings_layout.dart';

const _releaseNotes = {
  '1.1.0': [
    (
      'Appearance',
      'Olive and gold accents, a softer dark theme, and a light and dark preview in Appearance.',
    ),
    (
      'Profile and history',
      'Animated attendance gauge, custom banner colors, profile tags, and grouped dates in History.',
    ),
    (
      'Office invitations',
      'Administrators can share an office code or send an email invitation.',
    ),
    (
      'Sign-in and recovery',
      'Invitation and recovery codes can be entered in the app when an email link won\'t open.',
    ),
    (
      'Startup',
      'Attendance opens with a single splash and shows a clear message if it can\'t start.',
    ),
  ],
};

class WhatsNewScreen extends StatefulWidget {
  const WhatsNewScreen({super.key});

  @override
  State<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends State<WhatsNewScreen> {
  late final _package = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) => SettingsLayout(
    title: "What's new",
    children: [
      FutureBuilder(
        future: _package,
        builder: (context, snapshot) {
          final info = snapshot.data;
          if (info == null) {
            return snapshot.connectionState == ConnectionState.done
                ? const Text('Could not read the installed version.')
                : const Center(child: CircularProgressIndicator());
          }
          final notes = _releaseNotes[info.version];
          final theme = Theme.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppInfo.versionLabel(info),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (notes == null)
                const Text('No release notes for this version.'),
              if (notes != null)
                for (final (title, detail) in notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(detail, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
            ],
          );
        },
      ),
    ],
  );
}
