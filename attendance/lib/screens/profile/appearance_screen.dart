import 'package:attendance/widgets/app_toast.dart';
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

  Future<void> _save(BuildContext context, Future<void> Function() save) async {
    try {
      await save();
    } catch (_) {
      if (!context.mounted) return;
      AppToast.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save appearance. Try again.')),
        kind: ToastKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();
    final brightness = Theme.of(context).brightness;
    return SettingsLayout(
      title: 'Appearance',
      children: [
        SettingsSection(
          title: 'Theme',
          rows: [
            for (final mode in ThemeMode.values)
              _AppearanceOption(
                label: themeModeLabel(mode),
                preview: _ThemePreview(mode: mode, palette: provider.palette),
                selected: provider.mode == mode,
                onTap: provider.busy
                    ? null
                    : () => _save(context, () => provider.select(mode)),
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              useSafeArea: true,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (_) => _PalettePreview(
                startsDark: brightness == Brightness.dark,
                palette: provider.palette,
              ),
            ),
            icon: const Icon(AppIcons.eye, size: 20),
            label: const Text('Preview theme'),
          ),
        ),
        const SizedBox(height: 24),
        SettingsSection(
          title: 'Color palette',
          rows: [
            for (final palette in AppPalette.values)
              _AppearanceOption(
                label: palette.label,
                preview: _PaletteSwatch(
                  AppTheme.forPalette(palette, brightness).colorScheme,
                ),
                selected: provider.palette == palette,
                onTap: provider.busy
                    ? null
                    : () =>
                          _save(context, () => provider.selectPalette(palette)),
              ),
          ],
        ),
        if (provider.busy) const Center(child: LinearProgressIndicator()),
      ],
    );
  }
}

class _PalettePreview extends StatefulWidget {
  const _PalettePreview({required this.startsDark, required this.palette});

  final bool startsDark;
  final AppPalette palette;

  @override
  State<_PalettePreview> createState() => _PalettePreviewState();
}

class _PalettePreviewState extends State<_PalettePreview> {
  late bool _dark = widget.startsDark;

  @override
  Widget build(BuildContext context) {
    final preview = AppTheme.forPalette(
      widget.palette,
      _dark ? Brightness.dark : Brightness.light,
    );
    final colors = preview.colorScheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.palette.label} preview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(AppIcons.sun),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(AppIcons.moon),
                  label: Text('Dark'),
                ),
              ],
              selected: {_dark},
              onSelectionChanged: (value) =>
                  setState(() => _dark = value.single),
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance',
                      style: preview.textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PreviewLabel(
                          'Check in',
                          AppIcons.fingerprint,
                          colors.primary,
                          colors.onPrimary,
                        ),
                        Theme(
                          data: preview,
                          child: Builder(
                            builder: (context) => _PreviewLabel(
                              'Present',
                              AppIcons.circleCheck,
                              colors.surfaceContainerHighest,
                              context.attendancePresent,
                            ),
                          ),
                        ),
                        _PreviewLabel(
                          'Day streak',
                          AppIcons.flame,
                          colors.tertiaryContainer,
                          colors.onTertiaryContainer,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewLabel extends StatelessWidget {
  const _PreviewLabel(this.label, this.icon, this.background, this.foreground);

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label, style: TextStyle(color: foreground)),
          ),
        ],
      ),
    ),
  );
}

class _AppearanceOption extends StatelessWidget {
  const _AppearanceOption({
    required this.label,
    required this.preview,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Widget preview;
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
              SizedBox(width: 76, child: preview),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
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
  const _ThemePreview({required this.mode, required this.palette});

  final ThemeMode mode;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final light = AppTheme.forPalette(palette, Brightness.light).colorScheme;
    final dark = AppTheme.forPalette(palette, Brightness.dark).colorScheme;
    return SizedBox(
      height: 54,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (mode != ThemeMode.dark) Expanded(child: _PreviewSurface(light)),
            if (mode != ThemeMode.light) Expanded(child: _PreviewSurface(dark)),
          ],
        ),
      ),
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch(this.colors);

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      position: DecorationPosition.foreground,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 2, child: ColoredBox(color: colors.primary)),
            Expanded(child: ColoredBox(color: colors.primaryContainer)),
            Expanded(child: ColoredBox(color: colors.surface)),
          ],
        ),
      ),
    ),
  );
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
