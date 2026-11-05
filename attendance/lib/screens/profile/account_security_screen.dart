import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'account_edit_screen.dart';
import 'settings_layout.dart';

class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return SettingsLayout(
      title: 'Account & security',
      children: [
        SettingsSection(
          title: 'Sign-in',
          rows: [
            SettingsRow(
              'Email',
              detail: auth.currentUser?.email,
              onTap: auth.isPreview
                  ? null
                  : () async {
                      final saved = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => AccountEditScreen(
                            title: 'Change email',
                            label: 'Email',
                            email: true,
                            initialValue: auth.currentUser!.email,
                            onSave: auth.backend!.changeEmail,
                          ),
                        ),
                      );
                      if (saved == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Check your email to confirm the change.',
                            ),
                          ),
                        );
                      }
                    },
            ),
            SettingsRow(
              'Change password',
              onTap: auth.isPreview
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AccountEditScreen(
                          title: 'Change password',
                          label: 'New password',
                          password: true,
                          onSave: auth.backend!.setPassword,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}
