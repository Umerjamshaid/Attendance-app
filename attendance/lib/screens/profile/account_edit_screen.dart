import 'package:flutter/material.dart';
import '../../widgets/error_shake.dart';
import 'settings_layout.dart';

class AccountEditScreen extends StatefulWidget {
  const AccountEditScreen({
    super.key,
    required this.title,
    required this.label,
    required this.onSave,
    this.initialValue = '',
    this.password = false,
    this.email = false,
    this.actionLabel = 'Save changes',
    this.onSaved,
    this.onCancel,
    this.requireChange = true,
  });
  final String title, label, initialValue, actionLabel;
  final bool password, email, requireChange;
  final Future<void> Function(String) onSave;
  final VoidCallback? onSaved;
  final Future<void> Function()? onCancel;
  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  late final _controller = TextEditingController(text: widget.initialValue)
    ..addListener(_changed);
  bool _saving = false, _leaving = false;
  String? _error;
  int _errorRevision = 0;
  bool get _dirty => _controller.text.trim() != widget.initialValue.trim();
  void _changed() => setState(() => _error = null);
  Future<void> _save() async {
    if (_saving || (widget.requireChange && !_dirty)) return;
    final value = widget.password ? _controller.text : _controller.text.trim();
    if (value.isEmpty ||
        (widget.email &&
            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) ||
        (widget.password && value.length < 12)) {
      setState(() {
        _errorRevision++;
        _error = widget.password
            ? 'Use at least 12 characters.'
            : 'Enter a valid ${widget.label.toLowerCase()}.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(value);
      if (!mounted) return;
      if (widget.onSaved != null) {
        setState(() => _saving = false);
        widget.onSaved!();
        return;
      }
      setState(() => _leaving = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
          _errorRevision++;
        });
      }
    }
  }

  Future<void> _back(bool didPop) async {
    if (didPop || _saving || _leaving || widget.onCancel != null) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    setState(() => _leaving = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _cancelSetup() async {
    setState(() => _saving = true);
    try {
      await widget.onCancel!();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _errorRevision++;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.onCancel == null && !_saving && (!_dirty || _leaving),
    onPopInvokedWithResult: (didPop, _) => _back(didPop),
    child: SettingsLayout(
      title: widget.title,
      showBackButton: widget.onCancel == null,
      children: [
        ErrorShake(
          error: _error,
          revision: _errorRevision,
          child: TextField(
            controller: _controller,
            autofocus: true,
            readOnly: _saving,
            obscureText: widget.password,
            autocorrect: !widget.password,
            enableSuggestions: !widget.password,
            keyboardType: widget.email
                ? TextInputType.emailAddress
                : TextInputType.text,
            textInputAction: TextInputAction.done,
            maxLength: widget.password ? 128 : 100,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: widget.label,
              errorText: _error,
              errorMaxLines: 8,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving || (widget.requireChange && !_dirty)
              ? null
              : _save,
          style: FilledButton.styleFrom(
            disabledBackgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            disabledForegroundColor: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant,
            minimumSize: const Size(0, 52),
          ),
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.actionLabel),
        ),
        if (widget.onCancel != null)
          TextButton(
            onPressed: _saving ? null : _cancelSetup,
            child: const Text('Back to sign in'),
          ),
      ],
    ),
  );
}
