import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_icons.dart';
import '../../config/app_info.dart';
import '../../config/ui_tokens.dart';
import '../../widgets/app_identity_footer.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/user-profile/profile_section_card.dart';

Future<bool> confirmSignOut(BuildContext context) async =>
    await showSettingsSheet<bool>(context, (context) {
      final colors = Theme.of(context).colorScheme;
      return SettingsSheetBody(
        title: 'Sign out?',
        detail: 'You can sign back in without losing your attendance records.',
        leading: _SheetIcon(AppIcons.logout, destructive: true),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            child: const Text('Sign out'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
        ],
      );
    }) ??
    false;

Future<void> showHelpCentre(BuildContext context) => showSettingsSheet<void>(
  context,
  (_) => const SettingsSheetBody(
    title: 'Help Centre',
    detail: 'Contact Umer for an office invitation or help with Attendance.',
    leading: _SheetIcon(AppIcons.help),
    actions: [
      Text(AppInfo.supportEmail, textAlign: TextAlign.center),
      _ContactActions(),
    ],
  ),
);

Future<void> showAboutApp(BuildContext context) => showSettingsSheet<void>(
  context,
  (context) => SettingsSheetBody(
    title: AppInfo.name,
    detail: 'Photo check-ins and attendance history for teams across offices.',
    leading: const AttendanceMark(size: 56),
    actions: [
      const _InstalledVersion(),
      OutlinedButton.icon(
        onPressed: () =>
            _openLink(context, Uri.parse(AppInfo.sourceRepository)),
        icon: const Icon(AppIcons.brandGithub, size: 20),
        label: const Text('Source on GitHub'),
      ),
    ],
  ),
);

class _InstalledVersion extends StatefulWidget {
  const _InstalledVersion();

  @override
  State<_InstalledVersion> createState() => _InstalledVersionState();
}

class _InstalledVersionState extends State<_InstalledVersion> {
  late final _version = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _version,
    builder: (context, snapshot) => Text(
      snapshot.hasData
          ? AppInfo.versionLabel(snapshot.data!)
          : snapshot.hasError
          ? 'Version unavailable'
          : 'Reading installed version...',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelMedium,
    ),
  );
}

Future<void> showMakerCredit(BuildContext context) => showSettingsSheet<void>(
  context,
  (_) => SettingsSheetBody(
    title: AppInfo.maker,
    detail: 'Maker of Attendance.',
    leading: ClipOval(
      child: Image.asset(
        AppInfo.makerPhoto,
        width: 64,
        height: 64,
        cacheWidth: 192,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      ),
    ),
    actions: const [_ContactActions()],
  ),
);

Future<T?> showSettingsSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 520),
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (context) => SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Theme(
          data: ProfileUi.themeOf(context),
          child: Builder(builder: builder),
        ),
      ),
    );

class SettingsSheetBody extends StatelessWidget {
  const SettingsSheetBody({
    super.key,
    required this.title,
    required this.detail,
    required this.leading,
    required this.actions,
    this.footer,
  });

  final String title, detail;
  final Widget leading;
  final List<Widget> actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.sheetRadius),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: leading),
                  const SizedBox(height: 12),
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (final (index, action) in actions.indexed) ...[
                    if (index > 0) const SizedBox(height: 8),
                    action,
                  ],
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(width: double.infinity, child: footer),
            ),
        ],
      ),
    );
  }
}

class _SheetIcon extends StatelessWidget {
  const _SheetIcon(this.icon, {this.destructive = false});
  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 28,
      backgroundColor: destructive
          ? colors.errorContainer
          : colors.secondaryContainer,
      child: Icon(
        icon,
        size: 24,
        color: destructive
            ? colors.onErrorContainer
            : colors.onSecondaryContainer,
      ),
    );
  }
}

class _ContactActions extends StatelessWidget {
  const _ContactActions();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        onPressed: () => _openLink(
          context,
          Uri(scheme: 'mailto', path: AppInfo.supportEmail),
        ),
        icon: const Icon(AppIcons.mail, size: 20),
        label: const Text('Email Umer'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => _openLink(context, Uri.parse(AppInfo.makerGitHub)),
        icon: const Icon(AppIcons.brandGithub, size: 20),
        label: const Text('GitHub profile'),
      ),
      TextButton.icon(
        onPressed: () async {
          try {
            await Clipboard.setData(
              const ClipboardData(text: AppInfo.supportEmail),
            );
            if (context.mounted) _feedback(context, 'Email address copied.');
          } catch (_) {
            if (context.mounted) {
              _feedback(context, 'Could not copy the email address.');
            }
          }
        },
        icon: const Icon(AppIcons.copy, size: 20),
        label: const Text('Copy email address'),
      ),
    ],
  );
}

Future<void> _openLink(BuildContext context, Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // A browser or email client may not be installed.
  }
  if (!context.mounted) return;
  _feedback(
    context,
    uri.scheme == 'mailto'
        ? 'Could not open an email app. Copy the address instead.'
        : 'Could not open GitHub.',
  );
}

void _feedback(BuildContext context, String message) =>
    AppToast.of(context).showSnackBar(SnackBar(content: Text(message)));
