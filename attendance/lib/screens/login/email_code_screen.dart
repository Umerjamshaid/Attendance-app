import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/company_backend.dart';
import '../profile/settings_layout.dart';

class EmailCodeScreen extends StatefulWidget {
  const EmailCodeScreen({super.key, required this.backend, this.email = ''});

  final CompanyBackend backend;
  final String email;

  @override
  State<EmailCodeScreen> createState() => _EmailCodeScreenState();
}

class _EmailCodeScreenState extends State<EmailCodeScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email.trim());
  final _code = TextEditingController();
  CompanyEmailCode _type = CompanyEmailCode.invitation;
  bool _verifying = false;
  String? _error;

  void _clearError(String _) {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _verify() async {
    if (_verifying || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _verifying = true;
    });
    try {
      await widget.backend.verifyEmailCode(
        _email.text.trim(),
        _code.text,
        _type,
      );
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    } on CompanyException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsLayout(
    title: 'Email code',
    children: [
      Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<CompanyEmailCode>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Email type'),
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: CompanyEmailCode.invitation,
                  child: Text('Employee invitation'),
                ),
                DropdownMenuItem(
                  value: CompanyEmailCode.recovery,
                  child: Text('Password reset'),
                ),
              ],
              onChanged: _verifying
                  ? null
                  : (type) => setState(() {
                      _type = type!;
                      _error = null;
                    }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              readOnly: _verifying,
              decoration: const InputDecoration(
                labelText: 'Work email',
                errorMaxLines: 3,
              ),
              onChanged: _clearError,
              validator: (value) =>
                  RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter your work email.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _code,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              readOnly: _verifying,
              decoration: InputDecoration(
                labelText: 'Code from email',
                errorText: _error,
                errorMaxLines: 5,
              ),
              onChanged: _clearError,
              onFieldSubmitted: (_) => _verify(),
              validator: (value) => (value?.length ?? 0) < 6
                  ? 'Enter the code from your email.'
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _verifying ? null : _verify,
              child: Text(_verifying ? 'Verifying...' : 'Verify code'),
            ),
          ],
        ),
      ),
    ],
  );
}
