import 'package:flutter/material.dart';

import '../../config/app_icons.dart';
import '../../config/ui_tokens.dart';
import '../../models/employees_model.dart';

/// Edits an existing office role through the caller's authorized save action.
class OfficeRoleSheet extends StatefulWidget {
  const OfficeRoleSheet({
    super.key,
    required this.employee,
    required this.onSave,
  });

  final Employee employee;
  final Future<bool> Function(String role) onSave;

  @override
  State<OfficeRoleSheet> createState() => _OfficeRoleSheetState();
}

class _OfficeRoleSheetState extends State<OfficeRoleSheet> {
  late String _role = widget.employee.role;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving || _role == widget.employee.role) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.onSave(_role);
      if (mounted && saved) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not update the role. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppLayout.gutter,
          0,
          AppLayout.gutter,
          20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Office role',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(AppIcons.x),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(widget.employee.name, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              widget.employee.id,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            RadioGroup<String>(
              groupValue: _role,
              onChanged: (role) {
                if (!_saving && role != null) {
                  setState(() {
                    _role = role;
                    _error = null;
                  });
                }
              },
              child: Column(
                children: [
                  for (final role in ['employee', 'admin'])
                    RadioListTile<String>(
                      value: role,
                      enabled: !_saving,
                      selected: _role == role,
                      selectedTileColor: theme.colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      secondary: Icon(
                        role == 'admin' ? AppIcons.shield : AppIcons.user,
                        size: AppLayout.compactIconSize,
                      ),
                      title: Text(
                        role == 'admin' ? 'Administrator' : 'Employee',
                      ),
                    ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving || _role == widget.employee.role
                  ? null
                  : _save,
              child: _saving
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                        semanticsLabel: 'Saving role',
                      ),
                    )
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
