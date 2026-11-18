import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../profile/account_edit_screen.dart';

class PasswordSetupScreen extends StatefulWidget {
  const PasswordSetupScreen({super.key});

  @override
  State<PasswordSetupScreen> createState() => _PasswordSetupScreenState();
}

class _PasswordSetupScreenState extends State<PasswordSetupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.read<AuthProvider>().needsPasswordSetup) return;
      // A warm email callback may arrive with the request form still on top.
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return AccountEditScreen(
      title: 'Set password',
      label: 'Password',
      password: true,
      onSave: auth.finishPasswordSetup,
      onSaved: () {},
      onCancel: auth.logout,
    );
  }
}
