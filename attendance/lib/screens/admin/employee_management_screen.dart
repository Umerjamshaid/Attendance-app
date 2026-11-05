import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_icons.dart';
import '../../models/employees_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/company_backend.dart';
import '../profile/settings_layout.dart';

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
  void _reload() => setState(() => _employees = _backend.employees());
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
        ScaffoldMessenger.of(
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
          return Column(
            children: [
              for (final employee in employees)
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
  bool _busy = false;
  String? _error;
  Future<void> _invite() async {
    if (_busy || !_form.currentState!.validate()) return;
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
                  child: TextFormField(
                    controller: field.controller,
                    readOnly: _busy,
                    maxLength: field.controller == _code ? 32 : 100,
                    keyboardType: field.controller == _email
                        ? TextInputType.emailAddress
                        : TextInputType.text,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: field.label,
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
                  ),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
