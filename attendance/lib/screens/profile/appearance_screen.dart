import 'package:attendance/config/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/theme_provider.dart';
import 'settings_layout.dart';

String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'System',
  ThemeMode.light => 'Light',
  ThemeMode.dark => 'Dark',
};

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  Future<void> _select(BuildContext context, ThemeMode mode) async {
    try {
      await context.read<ThemeProvider>().select(mode);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save appearance. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();
    return SettingsLayout(
      title: 'Appearance',
      children: [
        SettingsSection(
          title: 'Theme',
          rows: [
            for (final mode in ThemeMode.values)
              _ThemeOption(
                mode: mode,
                selected: provider.mode == mode,
                onTap: provider.busy ? null : () => _select(context, mode),
              ),
          ],
        ),
        if (provider.busy) const Center(child: LinearProgressIndicator()),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          color: selected ? colors.primary.withValues(alpha: .08) : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SizedBox(width: 76, height: 54, child: _ThemePreview(mode: mode)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  themeModeLabel(mode),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              AnimatedSwitcher(
                duration: duration,
                child: Icon(
                  selected ? AppIcons.circleCheck : AppIcons.circle,
                  key: ValueKey(selected),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.mode});

  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final light = AppTheme.theme.colorScheme;
    final dark = AppTheme.darkTheme.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mode != ThemeMode.dark) Expanded(child: _PreviewSurface(light)),
          if (mode != ThemeMode.light) Expanded(child: _PreviewSurface(dark)),
        ],
      ),
    );
  }
}

class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface(this.colors);

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: colors.surface,
      border: Border.all(color: colors.outlineVariant),
    ),
    padding: const EdgeInsets.all(6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 12, height: 3, color: colors.primary),
        const SizedBox(height: 5),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            color: colors.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(width: 24, height: 2, color: colors.onSurfaceVariant),
                Container(width: 16, height: 2, color: colors.outline),
                Container(width: 10, height: 3, color: colors.secondary),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
