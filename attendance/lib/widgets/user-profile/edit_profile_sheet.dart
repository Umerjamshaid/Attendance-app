import 'package:attendance/config/app_theme.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bottom-sheet editor for the signed-in employee's name and email.
///
/// Pops with `true` once [onSave] completes, so the caller can confirm. The
/// sheet cannot be dismissed while a save is in flight.
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({
    super.key,
    required this.initialName,
    required this.initialEmail,
    required this.onSave,
  });

  final String initialName;
  final String initialEmail;
  final Future<void> Function(String name, String email) onSave;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  late final TextEditingController _name;
  late final TextEditingController _email;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName)
      ..addListener(_onChanged);
    _email = TextEditingController(text: widget.initialEmail)
      ..addListener(_onChanged);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() => _error = null);

  bool get _nameValid => _name.text.trim().isNotEmpty;
  bool get _emailValid => _emailPattern.hasMatch(_email.text.trim());
  bool get _changed =>
      _name.text.trim() != widget.initialName.trim() ||
      _email.text.trim() != widget.initialEmail.trim();
  bool get _canSave => !_saving && _nameValid && _emailValid && _changed;

  Future<void> _save() async {
    if (!_canSave) return;
    HapticFeedback.lightImpact();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_name.text.trim(), _email.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Couldn’t save changes. Try again.';
      });
    }
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? errorText,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: color == Colors.transparent
              ? BorderSide.none
              : BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      errorText: errorText,
      prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
      filled: true,
      fillColor: ProfileUi.cardFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(AppTheme.primaryNavy, 1.5),
      errorBorder: border(AppTheme.errorRed),
      focusedErrorBorder: border(AppTheme.errorRed, 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nameError = _nameValid ? null : 'Name can’t be empty';
    final emailError = _email.text.trim().isEmpty || _emailValid
        ? null
        : 'Enter a valid email address';
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // useSafeArea does not cover the bottom edge, so keep clear of the gesture
    // bar unless the keyboard is already covering it.
    final safeBottom = keyboard > 0
        ? 0.0
        : MediaQuery.viewPaddingOf(context).bottom;

    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            ProfileUi.gutter,
            0,
            ProfileUi.gutter,
            ProfileUi.gutter + safeBottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Edit profile',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Update your personal information.',
                          style: ProfileUi.small(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox.square(
                    dimension: 44,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: ProfileUi.cardFill,
                        foregroundColor: AppTheme.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ProfileUi.sheetRadius,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                style: ProfileUi.body(),
                decoration: _decoration(
                  label: 'Full name',
                  icon: Icons.badge_outlined,
                  errorText: nameError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                enabled: !_saving,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                onSubmitted: (_) => _save(),
                style: ProfileUi.body(),
                decoration: _decoration(
                  label: 'Email address',
                  icon: Icons.email_outlined,
                  errorText: emailError,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: ProfileUi.small(color: AppTheme.errorRed),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFF1F5F9),
                  disabledForegroundColor: const Color(0xFF64748B),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(_saving ? 'Saving…' : 'Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
