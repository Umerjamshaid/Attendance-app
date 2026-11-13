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
import '../admin/employee_management_screen.dart';
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
      await provider.updateOffice(office, name: office.name, logo: bytes);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
    final userId = context.watch<AuthProvider>().currentUser?.authUserId;
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
                                name: office.name,
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
                        ],
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
            if (provider.activeOffice?.isAdmin == true &&
                provider.activeOffice?.createdBy == userId &&
                userId != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const OfficeRolesScreen(),
                    ),
                  ),
                  icon: const Icon(AppIcons.shield, size: 20),
                  label: const Text('Manage active office roles'),
                ),
              ),
            Text('Invitations', style: AppTypography.title),
            const SizedBox(height: 12),
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
  void _save() {
    if (widget.office != null && _name.text.trim() == widget.office!.name) {
      return;
    }
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _name.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.office == null ? 'Create Office' : 'Rename Office'),
    content: Form(
      key: _form,
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
        onChanged: (_) => setState(() {}),
        onFieldSubmitted: (_) => _save(),
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
