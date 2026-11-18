import 'package:attendance/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/app_icons.dart';
import '../../config/ui_tokens.dart';
import '../../models/office_model.dart';
import '../../providers/office_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/office/office_selector_header.dart';
import '../../widgets/error_shake.dart';
import '../admin/employee_management_screen.dart';
import '../login/office_code_screen.dart';
import 'office_roles_screen.dart';

class ManageOfficesScreen extends StatelessWidget {
  const ManageOfficesScreen({super.key});

  Future<void> _edit(BuildContext context, Office? office) async {
    final provider = context.read<OfficeProvider>();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _OfficeNameDialog(office: office),
    );
    if (name == null) return;
    if (office == null) {
      await provider.createOffice(name);
    } else {
      await provider.updateOffice(office, name: name);
    }
  }

  Future<void> _logo(BuildContext context, Office office) async {
    final provider = context.read<OfficeProvider>();
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      // The provider/server still authorize the captured office after the picker returns.
      await provider.updateOffice(office, logo: bytes);
    } catch (_) {
      if (context.mounted) {
        AppToast.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not read that image. Choose a JPEG or PNG smaller than 2 MB.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTypography.themeOf(context),
    child: Builder(builder: _content),
  );

  Widget _content(BuildContext context) {
    final provider = context.watch<OfficeProvider>();
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Offices')),
      body: RefreshIndicator(
        onRefresh: provider.reload,
        child: ListView(
          padding: const EdgeInsets.all(AppLayout.gutter),
          children: [
            if (provider.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  provider.error!,
                  style: TextStyle(color: colors.error),
                ),
              ),
            if (provider.isLoading) const LinearProgressIndicator(),
            if (provider.canManage)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: provider.isSwitching
                      ? null
                      : () => _edit(context, null),
                  icon: const Icon(AppIcons.plus, size: 20),
                  label: const Text('Create Office'),
                ),
              ),
            if (provider.isPreview)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Preview offices use sample data only. Office changes are not saved.',
                ),
              ),
            const SizedBox(height: 20),
            for (final office in provider.offices)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: OfficeAvatar(office: office, size: 48),
                      title: Text(office.name),
                      subtitle: Text(
                        office.isAdmin ? 'Administrator' : 'Employee',
                      ),
                      trailing: office.id == provider.activeOfficeId
                          ? const Icon(AppIcons.circleCheck)
                          : null,
                      onTap: office.id == provider.activeOfficeId
                          ? null
                          : () => provider.switchOffice(office.id),
                    ),
                    if (office.isAdmin && !provider.isPreview)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          TextButton.icon(
                            onPressed: () => _edit(context, office),
                            icon: const Icon(AppIcons.edit, size: 20),
                            label: const Text('Rename'),
                          ),
                          TextButton.icon(
                            onPressed: () => _logo(context, office),
                            icon: const Icon(AppIcons.photoPlus, size: 20),
                            label: const Text('Logo'),
                          ),
                          if (office.logoPath != null)
                            TextButton(
                              onPressed: () => provider.updateOffice(
                                office,
                                removeLogo: true,
                              ),
                              child: const Text('Remove logo'),
                            ),
                          TextButton.icon(
                            onPressed: () async {
                              if (office.id != provider.activeOfficeId) {
                                await provider.switchOffice(office.id);
                                return;
                              }
                              if (context.mounted &&
                                  context
                                          .read<AuthProvider>()
                                          .currentUser
                                          ?.isAdmin ==
                                      true) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const EmployeeManagementScreen(),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(AppIcons.users, size: 20),
                            label: Text(
                              office.id == provider.activeOfficeId
                                  ? 'Employees'
                                  : 'Switch to manage',
                            ),
                          ),
                          if (office.id == provider.activeOfficeId)
                            TextButton.icon(
                              onPressed:
                                  !provider.canManageActiveRoles ||
                                      provider.isSwitching
                                  ? null
                                  : () => Navigator.of(context).push<void>(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const OfficeRolesScreen(),
                                      ),
                                    ),
                              icon: const Icon(AppIcons.shield, size: 20),
                              label: const Text('Roles'),
                            ),
                        ],
                      ),
                    if (office.id == provider.activeOfficeId &&
                        office.isAdmin &&
                        !provider.isPreview &&
                        !provider.isLoading &&
                        !provider.canManageActiveRoles)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          office.createdBy == null
                              ? 'No office owner is assigned.'
                              : 'Only the office owner can change roles.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ),
                    const Divider(),
                  ],
                ),
              ),
            if (provider.hiddenOffices.isNotEmpty) ...[
              Text('Hidden on this device', style: AppTypography.title),
              const SizedBox(height: 12),
              for (final office in provider.hiddenOffices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: OfficeAvatar(office: office, size: 48),
                  title: Text(office.name),
                  trailing: TextButton(
                    onPressed: provider.isSwitching
                        ? null
                        : () async {
                            HapticFeedback.selectionClick();
                            await provider.restoreOffice(office.id);
                          },
                    child: const Text('Restore'),
                  ),
                ),
              const SizedBox(height: 20),
            ],
            Text('Invitations', style: AppTypography.title),
            const SizedBox(height: 12),
            if (context
                    .read<AuthProvider>()
                    .officeBackend
                    ?.supportsOfficeInviteCodes ==
                true)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: provider.isSwitching
                      ? null
                      : () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => OfficeCodeScreen(
                              join: (code, _, _) async {
                                final joined = await provider.redeemInviteCode(
                                  code,
                                );
                                return joined
                                    ? null
                                    : provider.error ??
                                          'Could not join. Try again.';
                              },
                            ),
                          ),
                        ),
                  child: const Text('Join with an office code'),
                ),
              ),
            if (provider.invitations.isEmpty)
              const Text(
                'No pending invitations. Ask an office administrator to invite your sign-in email.',
              ),
            for (final invitation in provider.invitations)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(AppIcons.mail),
                title: Text(invitation.name),
                subtitle: Text(invitation.employeeCode),
                trailing: TextButton(
                  onPressed: provider.isSwitching
                      ? null
                      : () => provider.acceptInvitation(invitation.id),
                  child: const Text('Accept'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OfficeNameDialog extends StatefulWidget {
  const _OfficeNameDialog({this.office});
  final Office? office;
  @override
  State<_OfficeNameDialog> createState() => _OfficeNameDialogState();
}

class _OfficeNameDialogState extends State<_OfficeNameDialog> {
  late final _name = TextEditingController(text: widget.office?.name ?? '');
  final _form = GlobalKey<FormState>();
  int _errorRevision = 0;
  bool _invalid = false;
  void _save() {
    if (widget.office != null && _name.text.trim() == widget.office!.name) {
      return;
    }
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _name.text.trim());
    } else {
      setState(() {
        _invalid = true;
        _errorRevision++;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.office == null ? 'Create Office' : 'Rename Office'),
    content: Form(
      key: _form,
      child: ErrorShake(
        error: _invalid ? 'Enter an office name' : null,
        revision: _errorRevision,
        child: TextFormField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Office name'),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter an office name'
              : null,
          onChanged: (_) {
            if (_errorRevision > 0) _form.currentState?.validate();
            setState(() => _invalid = false);
          },
          onFieldSubmitted: (_) => _save(),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed:
            widget.office != null && _name.text.trim() == widget.office!.name
            ? null
            : _save,
        child: Text(widget.office == null ? 'Create Office' : 'Save changes'),
      ),
    ],
  );
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }
}
