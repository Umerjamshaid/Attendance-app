import 'package:flutter/material.dart';
import 'package:portal_labs/portal_labs.dart' as portal;

import '../../config/app_icons.dart';
import '../../config/app_theme.dart';
import '../../config/ui_tokens.dart';
import '../error_shake.dart';
import 'profile_section_card.dart';

/// Color choices are drafts until the existing banner upload succeeds.
class BannerColorSheet extends StatefulWidget {
  const BannerColorSheet({super.key, required this.onSave});
  final Future<void> Function(Color) onSave;

  static Future<bool?> open(
    BuildContext context, {
    required Future<void> Function(Color) onSave,
  }) => showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(ProfileUi.sheetRadius),
      ),
    ),
    builder: (_) => BannerColorSheet(onSave: onSave),
  );

  @override
  State<BannerColorSheet> createState() => _BannerColorSheetState();
}

class _BannerColorSheetState extends State<BannerColorSheet> {
  Color _color = AppTheme.primaryPetrol;
  bool _saving = false;
  String? _error;
  int _revision = 0;

  Future<void> _save() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_color.withValues(alpha: 1));
      if (!mounted) return;
      setState(() => _saving = false);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the banner color. Try again.';
          _revision++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ProfileUi.themeOf(context),
    child: Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final reduced = MediaQuery.disableAnimationsOf(context);
        return PopScope(
          canPop: !_saving,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Banner color',
                              style: ProfileUi.body(
                                context,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close color picker',
                            onPressed: _saving
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(AppIcons.x, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        label: 'Banner color preview',
                        value:
                            '#${_color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                        child: AnimatedContainer(
                          key: const ValueKey('banner-color-preview'),
                          duration: AppMotion.duration(context, AppMotion.fast),
                          height: 112,
                          decoration: BoxDecoration(
                            color: _color,
                            borderRadius: BorderRadius.circular(
                              ProfileUi.cardRadius,
                            ),
                            border: Border.all(color: colors.outlineVariant),
                          ),
                        ),
                      ),
                      // Extra vertical room keeps the package's anchored wheel inside
                      // the safe area rather than over the preview or Save action.
                      SizedBox(
                        height: 300,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: AbsorbPointer(
                            absorbing: _saving,
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                inputDecorationTheme:
                                    const InputDecorationTheme(
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                    ),
                              ),
                              child: portal.BloomColorPicker(
                                key: ValueKey('$reduced:$_saving'),
                                initialColor: _color,
                                onColorChanged: (color) => setState(() {
                                  _color = color;
                                  _error = null;
                                }),
                                style: portal.BloomColorPickerStyle(
                                  closedRadius: 18,
                                  bloomRadius:
                                      MediaQuery.sizeOf(context).width < 360
                                      ? 120
                                      : 140,
                                  sliderWidth: 16,
                                  pillBackgroundColor:
                                      colors.surfaceContainerHighest,
                                  pillTextColor: colors.onSurface,
                                  iconColor: colors.onSurfaceVariant,
                                  textStyle: ProfileUi.body(
                                    context,
                                    weight: FontWeight.w500,
                                  ),
                                  animationDuration: reduced
                                      ? Duration.zero
                                      : const Duration(milliseconds: 500),
                                  hapticFeedback: !reduced,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ErrorShake(
                            error: _error,
                            revision: _revision,
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                _error!,
                                style: ProfileUi.small(
                                  context,
                                  color: colors.error,
                                ),
                              ),
                            ),
                          ),
                        ),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving...' : 'Save color'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
