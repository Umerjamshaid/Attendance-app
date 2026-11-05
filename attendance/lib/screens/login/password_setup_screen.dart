import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../profile/account_edit_screen.dart';

class PasswordSetupScreen extends StatelessWidget {
  const PasswordSetupScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return AccountEditScreen(
      title: 'Set password',
      label: 'Password',
      password: true,
      onSave: (value) async {
        await auth.backend!.setPassword(value);
        await auth.refreshSession();
      },
      onSaved: () {},
    );
  }
}
