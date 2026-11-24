import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_icons.dart';
import '../../config/app_info.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_identity_footer.dart';
import '../profile/appearance_screen.dart';
import '../profile/settings_layout.dart';
import '../profile/settings_sheets.dart';

class OfflineHomeScreen extends StatelessWidget {
  const OfflineHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => SettingsLayout(
    title: AppInfo.name,
    showBackButton: false,
    children: [
      const Center(child: AttendanceMark(size: 56)),
      const SizedBox(height: 20),
      Text(
        'You\'re offline',
        style: Theme.of(context).textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      const Text(
        'Connect to sign in and access your office.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      if (context.watch<AuthProvider>().isPublicBuild)
        FilledButton(
          onPressed: () => context.read<AuthProvider>().enterPreview(),
          child: const Text('Explore demo'),
        ),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const AppearanceScreen()),
        ),
        icon: const Icon(AppIcons.moon, size: 20),
        label: const Text('Appearance'),
      ),
      TextButton(
        onPressed: () => showAboutApp(context),
        child: const Text('About app'),
      ),
    ],
  );
}

/// Keeps the dock visible but does not expose network-only office screens.
class OfflineOfficePane extends StatelessWidget {
  const OfflineOfficePane({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => SettingsLayout(
    title: title,
    showBackButton: false,
    children: const [
      Center(child: Icon(AppIcons.lock)),
      SizedBox(height: 12),
      Text('Available when you’re back online.', textAlign: TextAlign.center),
    ],
  );
}
