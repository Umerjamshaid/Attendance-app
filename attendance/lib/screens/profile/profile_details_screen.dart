import 'package:attendance/config/app_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/employees_model.dart';
import '../../providers/auth_provider.dart';
import 'settings_layout.dart';

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key, required this.user});

  final Employee user;

  static Future<void> open(BuildContext context, Employee user) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProfileDetailsScreen(user: user)),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile details saved.')));
    }
  }

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  late final _headline = TextEditingController(
    text: widget.user.headline ?? '',
  );
  final _tagDraft = TextEditingController();
  late final _tags = [...widget.user.chips];
  bool _saving = false;
  bool _failed = false;
  bool _leaving = false;
  String? get _inputError =>
      _tagsWithDraft.length > 12 || _tagsWithDraft.any((tag) => tag.length > 40)
      ? 'Use up to 12 tags, each no longer than 40 characters.'
      : null;

  List<String> get _tagsWithDraft {
    final known = _tags.map((tag) => tag.trim().toLowerCase()).toSet();
    return [
      ..._tags,
      for (final part in _tagDraft.text.split(','))
        if (part.trim().isNotEmpty && known.add(part.trim().toLowerCase()))
          part.trim(),
    ];
  }

  bool get _changed =>
      _headline.text.trim() != (widget.user.headline ?? '').trim() ||
      !listEquals(_tagsWithDraft, widget.user.chips);

  void _onChanged(String _) => setState(() => _failed = false);

  void _addTags() {
    if (_saving || _tagDraft.text.trim().isEmpty) return;
    final next = _tagsWithDraft;
    setState(() {
      _tags
        ..clear()
        ..addAll(next);
      _tagDraft.clear();
      _failed = false;
    });
  }

  Future<void> _save() async {
    if (_saving || !_changed || _inputError != null) return;
    final auth = context.read<AuthProvider>();
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await auth.updateProfile(
        headline: _headline.text.trim(),
        chips: _tagsWithDraft,
      );
      if (!mounted) return;
      setState(() => _leaving = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  void dispose() {
    _headline.dispose();
    _tagDraft.dispose();
    super.dispose();
  }

  InputDecoration _decoration(BuildContext context, String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PopScope(
      canPop: !_saving && (!_changed || _leaving),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving || _leaving) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard changes?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (discard != true || !mounted) return;
        setState(() => _leaving = true);
        await WidgetsBinding.instance.endOfFrame;
        if (context.mounted) Navigator.pop(context);
      },
      child: SettingsLayout(
        title: 'Profile details',
        children: [
          TextField(
            controller: _headline,
            maxLength: 160,
            readOnly: _saving,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            onChanged: _onChanged,
            decoration: _decoration(context, 'Headline'),
          ),
          const SizedBox(height: 16),
          if (_tags.isNotEmpty) ...[
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (var index = 0; index < _tags.length; index++)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                      ),
                      child: InputChip(
                        label: Text(_tags[index]),
                        deleteIcon: const Icon(AppIcons.x, size: 24),
                        backgroundColor: colors.surfaceContainerLow,
                        side: BorderSide(color: colors.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        deleteButtonTooltipMessage: 'Remove ${_tags[index]}',
                        onDeleted: _saving
                            ? null
                            : () => setState(() {
                                _tags.removeAt(index);
                                _failed = false;
                              }),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _tagDraft,
            readOnly: _saving,
            textInputAction: TextInputAction.done,
            onChanged: _onChanged,
            onSubmitted: (_) => _addTags(),
            decoration: _decoration(context, 'Add a tag').copyWith(
              errorText: _inputError,
              suffixIcon: IconButton(
                tooltip: 'Add tag',
                icon: const Icon(AppIcons.plus),
                onPressed: _saving || _tagDraft.text.trim().isEmpty
                    ? null
                    : _addTags,
              ),
            ),
          ),
          if (_failed) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                'Could not save changes. Try again.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving || !_changed || _inputError != null
                ? null
                : _save,
            style: FilledButton.styleFrom(
              disabledBackgroundColor: const Color(0xFFF1F5F9),
              disabledForegroundColor: const Color(0xFF64748B),
            ),
            child: Text(_saving ? 'Saving...' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
