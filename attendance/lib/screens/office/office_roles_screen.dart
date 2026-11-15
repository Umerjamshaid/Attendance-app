import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/employees_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/company_backend.dart';
import '../../config/ui_tokens.dart';

/// Owner-authorized role changes; existing employee invitation/activation UI is unchanged.
class OfficeRolesScreen extends StatefulWidget {
  const OfficeRolesScreen({super.key});
  @override
  State<OfficeRolesScreen> createState() => _OfficeRolesScreenState();
}

class _OfficeRolesScreenState extends State<OfficeRolesScreen> {
  late final CompanyBackend _backend = context.read<AuthProvider>().backend!;
  late Future<List<Employee>> _employees = _backend.employees();
  bool _busy = false;
  Future<void> _change(Employee employee, String role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Make ${employee.name} ${role == 'admin' ? 'an administrator' : 'an employee'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _backend.setEmployeeRole(employee.authUserId!, role);
      if (!mounted) return;
      setState(() => _employees = _backend.employees());
      await context.read<AuthProvider>().refreshSession();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTypography.themeOf(context),
    child: Builder(builder: _content),
  );
  Widget _content(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Office roles')),
    body: FutureBuilder<List<Employee>>(
      future: _employees,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () =>
                  setState(() => _employees = _backend.employees()),
              child: const Text('Retry'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          children: [
            for (final employee in snapshot.data!)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.gutter,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      employee.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      employee.id,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: employee.role,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: const [
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Administrator'),
                        ),
                        DropdownMenuItem(
                          value: 'employee',
                          child: Text('Employee'),
                        ),
                      ],
                      onChanged: _busy || employee.authUserId == null
                          ? null
                          : (role) {
                              if (role != null && role != employee.role) {
                                _change(employee, role);
                              }
                            },
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}
