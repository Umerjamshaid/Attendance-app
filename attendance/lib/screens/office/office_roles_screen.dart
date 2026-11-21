import 'package:attendance/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/employees_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/company_backend.dart';
import '../../config/ui_tokens.dart';
import '../../config/app_icons.dart';
import '../../widgets/office/office_role_sheet.dart';

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
  Future<bool> _change(Employee employee, String role) async {
    if (_busy || employee.authUserId == null || employee.role == role) {
      return false;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 480),
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (_) => OfficeRoleConfirmation(
        employeeName: employee.name,
        isAdmin: role == 'admin',
      ),
    );
    if (confirmed != true || !mounted) return false;
    setState(() => _busy = true);
    try {
      await _backend.setEmployeeRole(employee.authUserId!, role);
      if (!mounted) return true;
      setState(() {
        _employees = _backend.employees();
      });
      await context.read<AuthProvider>().refreshSession();
      return true;
    } catch (error) {
      if (mounted) {
        AppToast.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
          kind: ToastKind.error,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openRoleSheet(Employee employee) {
    if (_busy || employee.authUserId == null) return;
    showModalBottomSheet<void>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 520),
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (_) => OfficeRoleSheet(
        employee: employee,
        onSave: (role) => _change(employee, role),
      ),
    );
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
              onPressed: () => setState(() {
                _employees = _backend.employees();
              }),
              child: const Text('Retry'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          children: [
            for (final employee in snapshot.data!.where((e) => !e.isRemoved))
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
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        employee.isAdmin ? AppIcons.shield : AppIcons.user,
                        size: AppLayout.compactIconSize,
                      ),
                      title: Text(
                        employee.isAdmin ? 'Administrator' : 'Employee',
                      ),
                      trailing: const Icon(AppIcons.chevronRight, size: 20),
                      onTap: _busy || employee.authUserId == null
                          ? null
                          : () => _openRoleSheet(employee),
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
