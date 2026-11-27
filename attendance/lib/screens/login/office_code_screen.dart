import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/error_shake.dart';
import '../profile/settings_layout.dart';

class OfficeCodeScreen extends StatefulWidget {
  const OfficeCodeScreen({super.key, this.signInEmail, required this.join});

  // A non-null value asks for account credentials before redeeming.
  final String? signInEmail;
  final Future<String?> Function(String code, String email, String password)
  join;

  @override
  State<OfficeCodeScreen> createState() => _OfficeCodeScreenState();
}

class _OfficeCodeScreenState extends State<OfficeCodeScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();
  late final _email = TextEditingController(text: widget.signInEmail?.trim());
  bool _busy = false;
  String? _error;
  int _revision = 0;

  Future<void> _join() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.join(
      _code.text.trim(),
      _email.text.trim(),
      _password.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      _revision++;
    });
    if (error == null && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SettingsLayout(
      title: 'Join with an office code',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.signInEmail != null) ...[
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  readOnly: _busy,
                  decoration: const InputDecoration(labelText: 'Work email'),
                  validator: (value) =>
                      value == null || !value.trim().contains('@')
                      ? 'Enter your work email.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.password],
                  readOnly: _busy,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Enter your password.'
                      : null,
                ),
                const SizedBox(height: 16),
              ],
              ErrorShake(
                error: _error,
                revision: _revision,
                child: TextFormField(
                  controller: _code,
                  autofocus: widget.signInEmail == null,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [LengthLimitingTextInputFormatter(40)],
                  readOnly: _busy,
                  decoration: InputDecoration(
                    labelText: 'Office code',
                    errorText: _error,
                    errorMaxLines: 5,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final code = value?.replaceAll(RegExp(r'[\s-]'), '') ?? '';
                    return RegExp(
                          r'^[A-HJ-NP-Z2-9]{16}$',
                          caseSensitive: false,
                        ).hasMatch(code)
                        ? null
                        : 'Enter the 16-character code from your administrator.';
                  },
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onFieldSubmitted: (_) => _join(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _join,
                child: Text(_busy ? 'Joining...' : 'Join office'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
