import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/app_info.dart';
import '../../widgets/app_identity_footer.dart';
import 'settings_layout.dart';
import 'settings_sheets.dart';

const _officeAndSettingsHighlights = '''
### Cleaner employee roster

Search from the toolbar. Remove an employee without losing check-ins, or reinvite them with a new office code.

### Faster Office Switch

The switcher opens with the office list already loaded and refreshes it in the background.

### Clearer Graphite dividers

Separators are easier to see in Settings and Appearance in Graphite dark mode.

### New Settings sheets

Sign out, Help Centre, and About slide up from the bottom. Email, GitHub, and the installed version are easier to find.

### Interactive maker credits

Tap the handwritten credit in Profile or Settings to open the maker contact sheet.
''';

const _releaseNotes = {
  '1.1.0': '''$_officeAndSettingsHighlights
### New app icon

An emerald icon with a punched timecard, on the launcher and startup screen.

### Color palettes

Choose Olive & Gold, Tide, Iris, or Graphite in Settings, with light and dark versions of each.

### Startup recovery

If startup fails or stalls, Attendance leaves the splash and shows a restart message.

### Appearance

Olive and gold accents, a softer dark theme, and a light and dark preview in Appearance.

### Profile and history

Animated attendance gauge, custom banner colors, profile tags, and grouped dates in History.

### Office invitations

Administrators can share an office code or send an email invitation.

### Sign-in and recovery

Invitation and recovery codes can be entered in the app when an email link won't open.
''',
};

const _releaseHighlights = {'1.1.0': _officeAndSettingsHighlights};

bool hasReleaseHighlights(String version) =>
    _releaseHighlights.containsKey(version);

Future<void> showWhatsNewSheet(BuildContext context, PackageInfo info) {
  final highlights = _releaseHighlights[info.version];
  if (highlights == null) return Future.value();
  return showSettingsSheet<void>(
    context,
    (context) => SettingsSheetBody(
      title: "What's new",
      detail: AppInfo.versionLabel(info),
      leading: const AttendanceMark(size: 48),
      actions: [_ReleaseNotes(highlights)],
      footer: FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Got it'),
      ),
    ),
  );
}

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
              Row(
                children: [
                  const AttendanceMark(size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppInfo.versionLabel(info),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (notes == null)
                const Text('No release notes for this version.')
              else
                _ReleaseNotes(notes),
            ],
          );
        },
      ),
    ],
  );
}

class _ReleaseNotes extends StatelessWidget {
  const _ReleaseNotes(this.notes);

  final String notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GptMarkdownTheme(
      gptThemeData: GptMarkdownThemeData(
        brightness: theme.brightness,
        h3: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: GptMarkdown(
        notes.trim(),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.45,
        ),
      ),
    );
  }
}
