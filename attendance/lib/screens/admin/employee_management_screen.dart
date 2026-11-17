import 'package:attendance/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_icons.dart';
import '../../models/employees_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/company_backend.dart';
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
  Widget build(BuildContext context) => SettingsLayout(
    title: 'Employees',
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          icon: const Icon(AppIcons.plus),
          label: const Text('Invite employee'),
          onPressed: () async {
            final invited = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const InviteEmployeeScreen()),
            );
            if (invited == true && mounted) _reload();
          },
        ),
      ),
      const SizedBox(height: 20),
      EmployeeDiscoveryBar(
        query: _query,
        filter: _filter,
        onQueryChanged: (value) => setState(() => _query = value),
        onFilterChanged: (value) => setState(() => _filter = value),
      ),
      const SizedBox(height: 16),
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
                  if (_query.isNotEmpty || _filter != EmployeeAccessFilter.all)
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
          return Column(
            children: [
              for (final employee in visible)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(employee.name),
                  subtitle: Text(
                    '${employee.id} · ${employee.department}\n${employee.email}',
                  ),
                  isThreeLine: true,
                  trailing: Semantics(
                    label: 'Active access for ${employee.name}',
                    child: Switch(
                      value: employee.isActive,
                      onChanged: _busy != null
                          ? null
                          : (_) => _toggle(employee),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class InviteEmployeeScreen extends StatefulWidget {
  const InviteEmployeeScreen({super.key});
  @override
  State<InviteEmployeeScreen> createState() => _InviteEmployeeScreenState();
}

class _InviteEmployeeScreenState extends State<InviteEmployeeScreen> {
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
  String? _error;
  int _errorRevision = 0;
  Future<void> _invite() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) {
      setState(() => _errorRevision++);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().backend!.invite(
        email: _email.text.trim(),
        name: _name.text.trim(),
        employeeCode: _code.text.trim().toUpperCase(),
        department: _department.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
          _errorRevision++;
        });
      }
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
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final field in [
                (controller: _name, label: 'Full name'),
                (controller: _email, label: 'Work email'),
                (controller: _code, label: 'Employee number'),
                (controller: _department, label: 'Department'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ErrorShake(
                    error:
                        _fieldKeys[field.controller]!.currentState?.errorText,
                    revision: _errorRevision,
                    child: TextFormField(
                      key: _fieldKeys[field.controller],
                      controller: field.controller,
                      readOnly: _busy,
                      maxLength: field.controller == _code ? 32 : 100,
                      keyboardType: field.controller == _email
                          ? TextInputType.emailAddress
                          : TextInputType.text,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: field.label,
                        errorMaxLines: 8,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        if (field.controller == _email &&
                            !RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(value.trim())) {
                          return 'Enter a valid email.';
                        }
                        if (field.controller == _code &&
                            !RegExp(
                              r'^[A-Za-z0-9_-]{1,32}$',
                            ).hasMatch(value.trim())) {
                          return 'Use letters, numbers, hyphens or underscores.';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        if (_errorRevision > 0) _form.currentState?.validate();
                        setState(() => _error = null);
                      },
                    ),
                  ),
                ),
              if (_error != null)
                ErrorShake(
                  error: _error,
                  revision: _errorRevision,
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _invite,
                child: Text(
                  _busy ? 'Sending invitation...' : 'Send invitation',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
