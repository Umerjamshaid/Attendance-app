import 'dart:async';

import 'package:attendance/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/employees_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/office_provider.dart';
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
  late Future<List<Employee>> _employees = _loadEmployees();
  Map<String, String?> _avatars = const {};
  int _loadRevision = 0;
  bool _busy = false;

  Future<List<Employee>> _loadEmployees() async {
    final revision = ++_loadRevision;
    final employees =
        (await _backend.employees())
            .where((employee) => !employee.isRemoved)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    if (mounted && revision == _loadRevision) {
      unawaited(_loadAvatars(employees, revision));
    }
    return employees;
  }

  Future<void> _loadAvatars(List<Employee> employees, int revision) async {
    try {
      final avatars = await _backend.employeeAvatars(employees);
      if (mounted && revision == _loadRevision && avatars.isNotEmpty) {
        setState(() => _avatars = {..._avatars, ...avatars});
      }
    } catch (_) {
      // The roster remains usable with initials when photos are unavailable.
    }
  }

  Future<bool> _change(Employee employee, String role) async {
    if (_busy || employee.authUserId == null || employee.role == role) {
      return false;
    }
    setState(() => _busy = true);
    try {
      await _backend.setEmployeeRole(employee.authUserId!, role);
      if (!mounted) return true;
      setState(() {
        _employees = _loadEmployees();
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
                _employees = _loadEmployees();
              }),
              child: const Text('Retry'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final employees = snapshot.data!;
        if (employees.isEmpty) {
          return const Center(child: Text('No office members yet'));
        }
        final owner = context.watch<OfficeProvider?>()?.activeOffice?.createdBy;
        bool isOwner(Employee employee) =>
            owner != null && employee.authUserId == owner;
        return CustomScrollView(
          slivers: [
            _section(
              'Office owner',
              employees.where(isOwner).toList(),
              locked: true,
            ),
            _section(
              'Administrators',
              employees.where((e) => e.isAdmin && !isOwner(e)).toList(),
            ),
            _section(
              'Employees',
              employees.where((e) => !e.isAdmin && !isOwner(e)).toList(),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 16 + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _section(
    String title,
    List<Employee> employees, {
    bool locked = false,
  }) {
    if (employees.isEmpty) return const SliverToBoxAdapter();
    final theme = Theme.of(context);
    const corner = Radius.circular(8);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.gutter,
        16,
        AppLayout.gutter,
        4,
      ),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.labelMedium),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final member = employees[index];
              final employee = member.copyWith(
                avatarUrl: _avatars[member.authUserId],
                clearAvatarUrl:
                    _avatars.containsKey(member.authUserId) &&
                    _avatars[member.authUserId] == null,
              );
              final canEdit = !locked && employee.authUserId != null;
              return Material(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? corner : Radius.zero,
                  bottom: index == employees.length - 1 ? corner : Radius.zero,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (index != 0)
                      const Divider(height: 1, indent: 68, endIndent: 12),
                    ListTile(
                      leading: OfficeRoleAvatar(employee: employee),
                      title: Text(
                        employee.name.trim().isEmpty
                            ? employee.id
                            : employee.name,
                      ),
                      subtitle: Wrap(
                        spacing: 8,
                        children: [
                          Text(
                            locked
                                ? 'Owner'
                                : employee.isAdmin
                                ? 'Administrator'
                                : 'Employee',
                          ),
                          if (employee.department.trim().isNotEmpty)
                            Text(employee.department),
                          if (!employee.isActive) const Text('Paused'),
                          if (employee.authUserId == null)
                            const Text('Invitation pending'),
                        ],
                      ),
                      trailing: canEdit
                          ? const Icon(AppIcons.chevronRight, size: 20)
                          : null,
                      onTap: !canEdit || _busy
                          ? null
                          : () => _openRoleSheet(employee),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
