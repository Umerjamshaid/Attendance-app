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
                    child: Text('Office role', style: AppTypography.title),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(AppIcons.x),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const _RoleEmblem(icon: AppIcons.idBadge2),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.employee.name,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.employee.id,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 8),
              child: Semantics(
                header: true,
                child: Text(
                  'Role',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
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
                  _roleOption(context, 'employee'),
                  const SizedBox(height: 2),
                  _roleOption(context, 'admin'),
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
              style: _roleActionStyle,
              onPressed: _saving || _role == widget.employee.role
                  ? null
                  : _save,
              child: _saving
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onSurfaceVariant,
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

  Widget _roleOption(BuildContext context, String role) {
    final colors = Theme.of(context).colorScheme;
    final isAdmin = role == 'admin';
    final selected = _role == role;
    final foreground = selected ? colors.onPrimaryContainer : colors.onSurface;
    const outer = Radius.circular(AppLayout.groupRadius);
    const inner = Radius.circular(4);
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainer,
      borderRadius: isAdmin
          ? const BorderRadius.vertical(top: inner, bottom: outer)
          : const BorderRadius.vertical(top: outer, bottom: inner),
      clipBehavior: Clip.antiAlias,
      animationDuration: AppMotion.duration(context, AppMotion.fast),
      child: RadioListTile<String>(
        value: role,
        enabled: !_saving,
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        secondary: Icon(
          isAdmin ? AppIcons.shield : AppIcons.user,
          color: foreground,
          size: AppLayout.compactIconSize,
        ),
        title: Text(
          isAdmin ? 'Administrator' : 'Employee',
          style: TextStyle(color: foreground),
        ),
        subtitle: widget.employee.role == role
            ? const Text('Current role')
            : null,
      ),
    );
  }
}

final _roleActionStyle = FilledButton.styleFrom(
  minimumSize: const Size(0, AppLayout.controlHeight),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  shape: const StadiumBorder(),
);

class OfficeRoleConfirmation extends StatelessWidget {
  const OfficeRoleConfirmation({
    super.key,
    required this.employeeName,
    required this.isAdmin,
  });

  final String employeeName;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppLayout.sheetRadius),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: _RoleEmblem(
                  icon: isAdmin ? AppIcons.shield : AppIcons.user,
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  'Make $employeeName ${isAdmin ? 'an administrator' : 'an employee'}?',
                  textAlign: TextAlign.center,
                  style: AppTypography.title,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: _roleActionStyle,
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: _roleActionStyle,
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleEmblem extends StatelessWidget {
  const _RoleEmblem({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 24,
      backgroundColor: colors.secondaryContainer,
      foregroundColor: colors.onSecondaryContainer,
      child: Icon(
        icon,
        size: AppLayout.iconSize,
        color: colors.onSecondaryContainer,
      ),
    );
  }
}
