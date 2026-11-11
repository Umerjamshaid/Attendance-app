import 'package:attendance/config/app_icons.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../widgets/user-profile/profile_section_card.dart';

class SettingsLayout extends StatelessWidget {
  const SettingsLayout({
    super.key,
    required this.title,
    required this.children,
    this.close = false,
  });

  final String title;
  final List<Widget> children;
  final bool close;

  @override
  Widget build(BuildContext context) {
    final theme = ProfileUi.themeOf(context);
    final colors = theme.colorScheme;
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return Theme(
      data: theme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          centerTitle: true,
          title: Text(title, style: theme.textTheme.titleMedium),
          leading: close
              ? IconButton(
                  tooltip: 'Close settings',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(AppIcons.x),
                )
              : const BackButton(),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor.withValues(alpha: .92),
                  border: Border(
                    bottom: BorderSide(color: colors.outlineVariant),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, top + 20, 20, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Material(
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 14, endIndent: 14),
                  rows[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow(
    this.title, {
    super.key,
    this.detail,
    this.onTap,
    this.destructive = false,
  });

  final String title;
  final String? detail;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      minTileHeight: 52,
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: destructive ? theme.colorScheme.error : null,
        ),
      ),
      subtitle: detail == null ? null : Text(detail!),
      trailing: onTap != null && !destructive
          ? const Icon(AppIcons.chevronRight, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
