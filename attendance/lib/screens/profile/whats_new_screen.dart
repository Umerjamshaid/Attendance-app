import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../config/app_info.dart';
import '../../services/release_notes_service.dart';
import '../../services/network_status.dart';
import '../../widgets/app_identity_footer.dart';
import 'settings_layout.dart';
import 'settings_sheets.dart';

const _officeAndSettingsHighlights = '''
### Unread check-in activity

The Admin bell shows new check-ins. See today's activity separately and mark it all as read for this office.

### Clearer office roles

See owners, admins, and employees at a glance, and confirm role changes in the same sheet.

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

const _patchHighlights = '''
### What's New

Read the release notes for your installed version. Bundled notes are available offline.

### Download CV

Save the CV from About, even offline. The download arrow becomes a checkmark when the PDF is saved.

### Invitation activity

See recent invitation emails sent from this device. After two confirmed sends in an hour, a live counter shows when the oldest send drops out of that window.

### Profile gauge

The pointer now follows your attendance percentage around the arc.

### Check-in feedback

Successful check-ins show a banner you can swipe away.

### Location details

Location icons are smaller and better aligned on Home and in check-in evidence.

$_officeAndSettingsHighlights''';

const _releaseNotes = {
  '1.1.1': _patchHighlights,
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

const _releaseHighlights = {
  '1.1.0': _officeAndSettingsHighlights,
  '1.1.1': _patchHighlights,
};

Future<String?> _loadNotes(BuildContext context, PackageInfo info) =>
    (context.read<ReleaseNotesService?>() ?? ReleaseNotesService.shared)
        .notesFor(
          info,
          allowNetwork: context.read<NetworkStatus?>()?.offline != true,
        );

Future<void> showWhatsNewSheet(BuildContext context, PackageInfo info) {
  final notes = _loadNotes(context, info);
  return showSettingsSheet<void>(
    context,
    (context) => SettingsSheetBody(
      title: "What's new",
      detail: AppInfo.versionLabel(info),
      leading: const AttendanceMark(size: 48),
      actions: [
        _ReleaseNotes(notes, fallback: _releaseHighlights[info.version]),
      ],
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
  Future<String?>? _notes;

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
          final notes = _notes ??= _loadNotes(context, info);
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
              _ReleaseNotes(notes, fallback: _releaseNotes[info.version]),
            ],
          );
        },
      ),
    ],
  );
}

class _ReleaseNotes extends StatelessWidget {
  const _ReleaseNotes(this.notes, {this.fallback});

  final Future<String?> notes;
  final String? fallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder(
      future: notes,
      builder: (context, snapshot) {
        final markdown = snapshot.data ?? fallback;
        if (markdown == null) {
          return Text(
            snapshot.connectionState == ConnectionState.done
                ? 'Release notes are unavailable for this version.'
                : 'Loading release notes...',
          );
        }
        return GptMarkdownTheme(
          gptThemeData: GptMarkdownThemeData(
            brightness: theme.brightness,
            h3: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: GptMarkdown(
            markdown.trim(),
            // Release notes must not load external images or HTML embeds.
            html: false,
            imageBuilder: (_, _, _, _) => const SizedBox.shrink(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        );
      },
    );
  }
}
