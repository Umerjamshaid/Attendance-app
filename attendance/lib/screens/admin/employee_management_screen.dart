import 'dart:async';

import 'package:attendance/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:portal_labs/portal_labs.dart';
import 'package:provider/provider.dart';
import '../../config/app_icons.dart';
import '../../config/ui_tokens.dart';
import '../../config/utility_surface_theme.dart';
import '../../models/employees_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/office_provider.dart';
import '../../services/company_backend.dart';
import '../office/office_roles_screen.dart';
import '../profile/settings_layout.dart';
import '../profile/settings_sheets.dart';
import '../../widgets/error_shake.dart';
import '../../widgets/user-profile/profile_section_card.dart';

enum _RosterAction {
  pause('Pause access'),
  restore('Restore access'),
  remove('Remove from office'),
  reinvite('Reinvite');

  const _RosterAction(this.label);
  final String label;
}

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});
  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  late final CompanyBackend _backend = context.read<AuthProvider>().backend!;
  late Future<List<Employee>> _employees = _backend.employees();
  final _search = TextEditingController();
  bool _busy = false;
  bool _searching = false;
  bool _removed = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final request = _backend.employees();
    setState(() {
      _employees = request;
    });
    // The FutureBuilder presents read errors and the retry action.
    try {
      await request;
    } catch (_) {}
  }

  void _closeSearch() {
    setState(() {
      _search.clear();
      _searching = false;
    });
  }

  Future<void> _openInvite() async {
    final invited = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const InviteEmployeeScreen()),
    );
    if (invited == true && mounted) await _reload();
  }

  Future<void> _openEmployee(Employee employee) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final canChange = !_backend.isPreview && employee.isEmployee;
    final action = await showSettingsSheet<_RosterAction>(
      context,
      (context) => SettingsSheetBody(
        title: _employeeName(employee),
        detail: [
          employee.email,
          _employeeSubtitle(employee),
        ].where((part) => part.isNotEmpty).join('\n'),
        leading: _RosterAvatar(employee),
        actions: [
          if (!canChange)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          if (canChange && employee.isRemoved)
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, _RosterAction.reinvite),
              icon: const Icon(AppIcons.mail, size: 20),
              label: const Text('Reinvite'),
            ),
          if (canChange && !employee.isRemoved) ...[
            OutlinedButton(
              onPressed: () => Navigator.pop(
                context,
                employee.isActive ? _RosterAction.pause : _RosterAction.restore,
              ),
              child: Text(
                employee.isActive ? 'Pause access' : 'Restore access',
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, _RosterAction.remove),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              icon: const Icon(AppIcons.userOff, size: 20),
              label: const Text('Remove from office'),
            ),
          ],
        ],
      ),
    );
    if (action == null || !mounted) return;
    if (action != _RosterAction.reinvite &&
        !await _confirmChange(employee, action)) {
      return;
    }
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    try {
      switch (action) {
        case _RosterAction.remove:
          await _backend.removeOfficeEmployee(employee.id);
        case _RosterAction.pause:
        case _RosterAction.restore:
          await _backend.setEmployeeActive(
            employee.id,
            action == _RosterAction.restore,
          );
        case _RosterAction.reinvite:
          final code = await _backend.reinviteRemovedEmployee(employee.id);
          if (!mounted) return;
          setState(() => _busy = false);
          await showSettingsSheet<void>(
            context,
            (context) => SettingsSheetBody(
              title: 'Office code ready',
              detail: [
                employee.email,
                'Single use. Expires after 24 hours.',
              ].where((part) => part.isNotEmpty).join('\n'),
              leading: _RosterAvatar(employee),
              actions: [
                _OfficeInviteCode(code: code),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          );
      }
      if (mounted && action != _RosterAction.reinvite) {
        unawaited(context.read<AdminProvider?>()?.loadDashboard());
        await _reload();
      }
    } catch (e) {
      if (mounted) {
        AppToast.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmChange(Employee employee, _RosterAction action) async =>
      await showSettingsSheet<bool>(context, (context) {
        final colors = Theme.of(context).colorScheme;
        final removing = action == _RosterAction.remove;
        return SettingsSheetBody(
          title: '${action.label}?',
          detail: switch (action) {
            _RosterAction.remove =>
              '${_employeeName(employee)} will lose access to this office. Past check-ins stay on record. You can reinvite them from Removed.',
            _RosterAction.pause =>
              '${_employeeName(employee)} will lose access until you restore it.',
            _ =>
              '${_employeeName(employee)} will regain access to this office.',
          },
          leading: _RosterAvatar(employee),
          actions: [
            FilledButton(
              style: removing
                  ? FilledButton.styleFrom(
                      backgroundColor: colors.error,
                      foregroundColor: colors.onError,
                    )
                  : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(action.label),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ],
        );
      }) ??
      false;

  @override
  Widget build(BuildContext context) => Theme(
    data: utilitySurfaceThemeData(ProfileUi.themeOf(context)),
    child: Builder(builder: _content),
  );

  Widget _content(BuildContext context) {
    final canManageRoles = context.select(
      (OfficeProvider? offices) => offices?.canManageActiveRoles ?? false,
    );
    return PopScope(
      canPop: !_searching && !_busy,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && _searching && !_busy) _closeSearch();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _searching
              ? IconButton(
                  tooltip: 'Close search',
                  icon: const Icon(AppIcons.chevronLeft),
                  onPressed: _closeSearch,
                )
              : null,
          title: _searching
              ? TextField(
                  key: const ValueKey('employee-search-input'),
                  controller: _search,
                  autofocus: true,
                  autocorrect: false,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search employees',
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                )
              : const Text('Employees'),
          actions: [
            if (_searching)
              IconButton(
                tooltip: 'Clear search',
                icon: const Icon(AppIcons.x),
                onPressed: _search.text.isEmpty
                    ? null
                    : () => setState(_search.clear),
              )
            else ...[
              IconButton(
                tooltip: 'Search employees',
                icon: const Icon(AppIcons.search),
                onPressed: _busy
                    ? null
                    : () => setState(() => _searching = true),
              ),
              if (!_backend.isPreview)
                IconButton(
                  tooltip: 'Invite employee',
                  icon: const Icon(AppIcons.plus),
                  onPressed: _busy ? null : _openInvite,
                ),
            ],
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<bool>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Current'),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Removed'),
                              ),
                            ],
                            selected: {_removed},
                            onSelectionChanged: _busy
                                ? null
                                : (value) =>
                                      setState(() => _removed = value.single),
                          ),
                        ),
                        if (canManageRoles && !_searching) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Roles',
                            icon: const Icon(AppIcons.shield),
                            onPressed: _busy
                                ? null
                                : () async {
                                    await Navigator.of(context).push<void>(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const OfficeRolesScreen(),
                                      ),
                                    );
                                    if (mounted) await _reload();
                                  },
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_busy) const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: FutureBuilder<List<Employee>>(
                      future: _employees,
                      builder: (context, snapshot) =>
                          _roster(context, snapshot),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roster(BuildContext context, AsyncSnapshot<List<Employee>> snapshot) {
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(snapshot.error.toString(), textAlign: TextAlign.center),
              TextButton(onPressed: _reload, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    final terms = _search.text.toLowerCase().trim().split(RegExp(r'\s+'));
    final visible = snapshot.data!.where((employee) {
      if (employee.isRemoved != _removed) return false;
      final text =
          '${employee.name} ${employee.id} ${employee.department} ${employee.email}'
              .toLowerCase();
      return terms.every(text.contains);
    }).toList();
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        key: PageStorageKey((_removed, _searching)),
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: visible.isEmpty ? 1 : visible.length + 1,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
        itemBuilder: (context, index) {
          if (visible.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _search.text.trim().isNotEmpty
                    ? 'No employees found'
                    : _removed
                    ? 'No removed employees'
                    : 'No employees yet',
                textAlign: TextAlign.center,
              ),
            );
          }
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: Text(
                '${visible.length} ${visible.length == 1 ? 'employee' : 'employees'}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final employee = visible[index - 1];
          return ListTile(
            key: ValueKey(employee.id),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            leading: _RosterAvatar(employee),
            title: Text(
              _employeeName(employee),
              style: theme.textTheme.titleSmall,
            ),
            subtitle: Text(_employeeSubtitle(employee)),
            trailing: const Icon(AppIcons.chevronRight, size: 20),
            onTap: _busy ? null : () => _openEmployee(employee),
          );
        },
      ),
    );
  }
}

String _employeeName(Employee employee) =>
    employee.name.trim().isEmpty ? employee.id : employee.name;

String _employeeSubtitle(Employee employee) => [
  employee.id,
  if (employee.department.trim().isNotEmpty) employee.department,
  if (employee.isAdmin) 'Admin',
  if (!employee.isActive && !employee.isRemoved) 'Paused',
].join(' · ');

class _RosterAvatar extends StatelessWidget {
  const _RosterAvatar(this.employee);
  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initials = _employeeName(employee)
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: 20,
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: FittedBox(child: Text(initials.isEmpty ? '?' : initials)),
        ),
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
          _OfficeInviteCode(code: code),
          const SizedBox(height: 24),
          FilledButton(
            style: actionStyle,
            onPressed: () => Navigator.pop(context, true),
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

class _OfficeInviteCode extends StatelessWidget {
  const _OfficeInviteCode({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return RevealCopyInteraction(
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
    );
  }
}
