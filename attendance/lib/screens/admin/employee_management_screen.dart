import 'package:attendance/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:portal_labs/portal_labs.dart';
import 'package:provider/provider.dart';
import '../../config/app_icons.dart';
import '../../config/ui_tokens.dart';
import '../../models/employees_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/office_provider.dart';
import '../../services/company_backend.dart';
import '../office/office_roles_screen.dart';
import '../profile/settings_layout.dart';
import '../../widgets/error_shake.dart';
import '../../widgets/admin/employee_discovery_bar.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});
  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  late final CompanyBackend _backend = context.read<AuthProvider>().backend!;
  late Future<List<Employee>> _employees = _backend.employees();
  String? _busy;
  String _query = '';
  EmployeeAccessFilter _filter = EmployeeAccessFilter.all;
  void _reload() => setState(() {
    _employees = _backend.employees();
  });
  Future<void> _toggle(Employee employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${employee.isActive ? 'Deactivate' : 'Reactivate'} ${employee.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = employee.id);
    try {
      await _backend.setEmployeeActive(employee.id, !employee.isActive);
      if (mounted) _reload();
    } catch (e) {
      if (mounted) {
        AppToast.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManageRoles =
        context.watch<OfficeProvider?>()?.canManageActiveRoles ?? false;
    final colors = Theme.of(context).colorScheme;
    final actionStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: const StadiumBorder(),
    );
    return SettingsLayout(
      title: 'Employees',
      children: [
        EmployeeDiscoveryBar(
          query: _query,
          filter: _filter,
          onQueryChanged: (value) => setState(() => _query = value),
          onFilterChanged: (value) => setState(() => _filter = value),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              icon: const Icon(AppIcons.plus, size: AppLayout.compactIconSize),
              label: const Text('Invite employee'),
              style: actionStyle,
              onPressed: () async {
                final invited = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const InviteEmployeeScreen(),
                  ),
                );
                if (invited == true && mounted) _reload();
              },
            ),
            if (canManageRoles)
              FilledButton.tonalIcon(
                icon: const Icon(
                  AppIcons.shield,
                  size: AppLayout.compactIconSize,
                ),
                label: const Text('Roles'),
                style: actionStyle.copyWith(
                  backgroundColor: WidgetStatePropertyAll(
                    colors.primaryContainer,
                  ),
                  foregroundColor: WidgetStatePropertyAll(
                    colors.onPrimaryContainer,
                  ),
                ),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const OfficeRolesScreen()),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        FutureBuilder(
          future: _employees,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Column(
                children: [
                  Text(snapshot.error.toString()),
                  TextButton(onPressed: _reload, child: const Text('Retry')),
                ],
              );
            }
            final employees = snapshot.data ?? [];
            final terms = _query
                .trim()
                .toLowerCase()
                .split(RegExp(r'\s+'))
                .where((term) => term.isNotEmpty);
            final visible = employees.where((employee) {
              final accessMatches = switch (_filter) {
                EmployeeAccessFilter.all => true,
                EmployeeAccessFilter.active => employee.isActive,
                EmployeeAccessFilter.inactive => !employee.isActive,
              };
              final text =
                  '${employee.name} ${employee.id} ${employee.department} ${employee.email}'
                      .toLowerCase();
              return accessMatches && terms.every(text.contains);
            }).toList();
            if (visible.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(
                      employees.isEmpty
                          ? 'No employees yet'
                          : 'No employees found',
                    ),
                    if (_query.isNotEmpty ||
                        _filter != EmployeeAccessFilter.all)
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _query = '';
                          _filter = EmployeeAccessFilter.all;
                        }),
                        icon: const Icon(AppIcons.x, size: 18),
                        label: const Text('Clear filters'),
                      ),
                  ],
                ),
              );
            }
            return SettingsSection(
              title: 'Roster (${visible.length})',
              rows: [
                for (final employee in visible)
                  _EmployeeRosterRow(
                    key: ValueKey(employee.id),
                    employee: employee,
                    onToggle: _busy != null ? null : (_) => _toggle(employee),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EmployeeRosterRow extends StatelessWidget {
  const _EmployeeRosterRow({
    super.key,
    required this.employee,
    required this.onToggle,
  });

  final Employee employee;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = employee.name.trim();
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => String.fromCharCode(part.runes.first))
        .join()
        .toUpperCase();
    final details = [
      [
        employee.id,
        employee.department,
      ].where((value) => value.trim().isNotEmpty).join(' · '),
      employee.email,
    ].where((value) => value.trim().isNotEmpty).join('\n');
    return ListTile(
      minTileHeight: 88,
      minLeadingWidth: 36,
      horizontalTitleGap: 12,
      titleAlignment: ListTileTitleAlignment.center,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: ExcludeSemantics(
        child: CircleAvatar(
          radius: 18,
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
      title: Text(
        name.isEmpty ? 'Unnamed employee' : name,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: details.isEmpty ? null : Text(details),
      isThreeLine: details.contains('\n'),
      trailing: Semantics(
        label: 'Active access for ${employee.name}',
        child: Switch(value: employee.isActive, onChanged: onToggle),
      ),
    );
  }
}

class InviteEmployeeScreen extends StatefulWidget {
  const InviteEmployeeScreen({super.key});
  @override
  State<InviteEmployeeScreen> createState() => _InviteEmployeeScreenState();
}

class _InviteEmployeeScreenState extends State<InviteEmployeeScreen> {
  late final CompanyBackend _backend = context.read<AuthProvider>().backend!;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _code = TextEditingController(),
      _department = TextEditingController();
  late final _fieldKeys = {
    for (final controller in [_name, _email, _code, _department])
      controller: GlobalKey<FormFieldState<String>>(),
  };
  bool _busy = false;
  bool _useCode = false;
  String? _issuedCode;
  String? _error;
  int _errorRevision = 0;
  Future<void> _invite() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) {
      setState(() => _errorRevision++);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final field in _fieldKeys.values) {
          final fieldContext = field.currentContext;
          if (field.currentState?.hasError == true && fieldContext != null) {
            Scrollable.ensureVisible(
              fieldContext,
              alignment: .25,
              duration: AppMotion.duration(context, AppMotion.standard),
            );
            break;
          }
        }
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      final name = _name.text.trim();
      final employeeCode = _code.text.trim().toUpperCase();
      final department = _department.text.trim();
      if (_useCode) {
        final code = await _backend.createOfficeInviteCode(
          email: email,
          name: name,
          employeeCode: employeeCode,
          department: department,
        );
        if (mounted) setState(() => _issuedCode = code);
      } else {
        await _backend.invite(
          email: email,
          name: name,
          employeeCode: employeeCode,
          department: department,
        );
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _errorRevision++;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final field in [_name, _email, _code, _department]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SettingsLayout(
      title: 'Invite employee',
      children: [Builder(builder: _buildInviteContent)],
    ),
  );

  Widget _buildInviteContent(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final actionStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, AppLayout.controlHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: const StadiumBorder(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_issuedCode case final code?) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: colors.secondaryContainer,
              foregroundColor: colors.onSecondaryContainer,
              child: Icon(
                AppIcons.check,
                size: AppLayout.iconSize,
                color: colors.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              'Office code ready',
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 4),
          Text(_email.text.trim(), style: theme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text(
            'Single use. Expires after 24 hours.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          RevealCopyInteraction(
            value: code,
            backgroundColor: colors.surfaceContainerLow,
            borderColor: colors.outlineVariant,
            successColor: colors.primary,
            revealDuration: const Duration(seconds: 12),
            textStyle: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurface,
              fontFamily: 'monospace',
            ),
            onCopied: () => AppToast.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Office code copied'))),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: actionStyle,
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ] else ...[
          if (_backend.supportsOfficeInviteCodes) ...[
            const _InviteSectionLabel('Invitation method'),
            RadioGroup<bool>(
              groupValue: _useCode,
              onChanged: (useCode) {
                if (_busy || useCode == null) return;
                setState(() {
                  _useCode = useCode;
                  _error = null;
                });
              },
              child: Column(
                children: [
                  _methodOption(context, false),
                  const SizedBox(height: 2),
                  _methodOption(context, true),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          const _InviteSectionLabel('Employee details'),
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (controller, label, icon) in [
                  (_name, 'Full name', AppIcons.user),
                  (_email, 'Work email', AppIcons.mail),
                  (_code, 'Employee number', AppIcons.idBadge2),
                  (_department, 'Department', AppIcons.users),
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: ErrorShake(
                      error: _fieldKeys[controller]!.currentState?.errorText,
                      revision: _errorRevision,
                      child: TextFormField(
                        key: _fieldKeys[controller],
                        controller: controller,
                        readOnly: _busy,
                        maxLength: controller == _code ? 32 : 100,
                        keyboardType: controller == _email
                            ? TextInputType.emailAddress
                            : TextInputType.text,
                        textInputAction: controller == _department
                            ? TextInputAction.done
                            : TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: label,
                          prefixIcon: Icon(
                            icon,
                            size: AppLayout.compactIconSize,
                          ),
                          fillColor: colors.surfaceContainerLow,
                          counterText: '',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (controller == _email &&
                              !RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(value.trim())) {
                            return 'Enter a valid email.';
                          }
                          if (controller == _code &&
                              !RegExp(
                                r'^[A-Za-z0-9_-]{1,32}$',
                              ).hasMatch(value.trim())) {
                            return 'Use letters, numbers, hyphens or underscores.';
                          }
                          return null;
                        },
                        onChanged: (_) {
                          if (_errorRevision > 0) {
                            _form.currentState?.validate();
                          }
                          setState(() => _error = null);
                        },
                      ),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  ErrorShake(
                    error: _error,
                    revision: _errorRevision,
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  style: actionStyle,
                  onPressed: _busy ? null : _invite,
                  child: Text(
                    _useCode
                        ? (_busy ? 'Creating code...' : 'Create office code')
                        : (_busy ? 'Sending invitation...' : 'Send invitation'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _methodOption(BuildContext context, bool useCode) {
    final colors = Theme.of(context).colorScheme;
    final selected = _useCode == useCode;
    final foreground = selected ? colors.onPrimaryContainer : colors.onSurface;
    const outer = Radius.circular(AppLayout.groupRadius);
    const inner = Radius.circular(4);
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainer,
      borderRadius: useCode
          ? const BorderRadius.vertical(top: inner, bottom: outer)
          : const BorderRadius.vertical(top: outer, bottom: inner),
      clipBehavior: Clip.antiAlias,
      animationDuration: AppMotion.duration(context, AppMotion.fast),
      child: RadioListTile<bool>(
        value: useCode,
        enabled: !_busy,
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        secondary: Icon(
          useCode ? AppIcons.lock : AppIcons.mail,
          size: AppLayout.compactIconSize,
          color: foreground,
        ),
        title: Text(
          useCode ? 'Office code' : 'Email',
          style: TextStyle(color: foreground),
        ),
      ),
    );
  }
}

class _InviteSectionLabel extends StatelessWidget {
  const _InviteSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
