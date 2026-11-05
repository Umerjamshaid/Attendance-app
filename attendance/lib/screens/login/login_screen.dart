import 'package:attendance/config/app_icons.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/widgets/demo_mode_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../profile/account_edit_screen.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onLoginSuccess});

  final VoidCallback? onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _password = TextEditingController();
  final _idFocus = FocusNode();
  String? _idError;
  late final AnimationController _animationController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _riseIn;
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeIn = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _riseIn = Tween<Offset>(begin: const Offset(0, 0.025), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animationStarted) return;
    _animationStarted = true;

    if (MediaQuery.of(context).disableAnimations) {
      _animationController.value = 1;
    } else {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _password.dispose();
    _idFocus.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.status == AuthStatus.authenticating) return;
    final id = _controller.text.trim();
    final company = authProvider.isPublicBuild;
    if (id.isEmpty) {
      setState(
        () => _idError = company
            ? 'Enter your work email.'
            : 'Enter your employee ID.',
      );
      _idFocus.requestFocus();
      return;
    }
    if (company && (_password.text.isEmpty || !id.contains('@'))) {
      setState(() => _idError = 'Enter your email and password.');
      return;
    }
    setState(() => _idError = null);
    final success = await authProvider.login(id, password: _password.text);
    if (!mounted) return;

    if (success) {
      widget.onLoginSuccess?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error ?? 'Login failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final company = auth.isPublicBuild;
    final isLoading =
        context.watch<AuthProvider>().status == AuthStatus.authenticating;

    return Scaffold(
      backgroundColor: context.colors.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 488),
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _riseIn,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _BrandHeader(),
                            const SizedBox(height: 32),
                            Semantics(
                              header: true,
                              namesRoute: true,
                              child: Text(
                                'Sign in',
                                style: TextStyle(
                                  color: context.colors.onSurface,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w400,
                                  height: 1.2,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              company
                                  ? 'Sign in with your company account.'
                                  : 'Enter your employee ID to continue.',
                              style: TextStyle(
                                color: context.colors.onSurfaceVariant,
                                fontSize: 16,
                                height: 1.5,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (company) ...[
                              TextField(
                                controller: _controller,
                                focusNode: _idFocus,
                                readOnly: isLoading,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Work email',
                                  errorText: _idError,
                                  prefixIcon: const Icon(AppIcons.mail),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _password,
                                readOnly: isLoading,
                                obscureText: true,
                                enableSuggestions: false,
                                autocorrect: false,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _signIn(),
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(AppIcons.lock),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: isLoading || !auth.isConfigured
                                      ? null
                                      : () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => AccountEditScreen(
                                              title: 'Reset password',
                                              label: 'Work email',
                                              email: true,
                                              requireChange: false,
                                              initialValue: _controller.text,
                                              actionLabel:
                                                  'Send recovery email',
                                              onSave: (value) => auth.backend!
                                                  .resetPassword(value),
                                              onSaved: () {
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'If the account exists, a recovery email will arrive shortly.',
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                              if (!auth.isConfigured)
                                const Text(
                                  'Company sign-in is unavailable in this build.',
                                ),
                            ] else
                              _EmployeeIdField(
                                controller: _controller,
                                focusNode: _idFocus,
                                readOnly: isLoading,
                                errorText: _idError,
                                onChanged: (_) {
                                  if (_idError != null) {
                                    setState(() => _idError = null);
                                  }
                                },
                                onSubmitted: (_) => _signIn(),
                              ),
                            if (!company && auth.isDemoMode) ...[
                              const SizedBox(height: 16),
                              const DemoModeNotice(),
                              const SizedBox(height: 12),
                              Text(
                                'Demo IDs: EMP001 – EMP003 · Admin: EMP001',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: context.colors.onSurfaceVariant,
                                    ),
                              ),
                            ],
                            const Spacer(),
                            const SizedBox(height: 24),
                            _SignInButton(
                              loading: isLoading,
                              onPressed: _signIn,
                            ),
                            if (company)
                              TextButton(
                                onPressed: isLoading ? null : auth.enterPreview,
                                child: const Text('Explore demo'),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              company
                                  ? 'Company access is by invitation.'
                                  : 'Your Employee ID was provided when your account was created.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.colors.onSurfaceVariant,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.colors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            AppIcons.fingerprint,
            color: context.colors.onPrimary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WorkCheck',
                style: TextStyle(
                  color: context.colors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'OFFICE ATTENDANCE',
                style: TextStyle(
                  color: context.colors.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmployeeIdField extends StatelessWidget {
  const _EmployeeIdField({
    required this.controller,
    required this.onSubmitted,
    required this.focusNode,
    required this.readOnly,
    required this.onChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onChanged;
  final FocusNode focusNode;
  final bool readOnly;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      onChanged: onChanged,
      autofocus: true,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      inputFormatters: [UpperCaseTextFormatter()],
      style: TextStyle(
        color: context.colors.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: 'Employee ID',
        errorText: errorText,
        hintText: 'e.g. EMP001',
        prefixIcon: Icon(AppIcons.idBadge2),
        filled: true,
        fillColor: context.colors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.colors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.colors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: const StadiumBorder(),
        ),
        child: loading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.onPrimary,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Flexible(
                    child: Text('Signing in', textAlign: TextAlign.center),
                  ),
                ],
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Sign in',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(AppIcons.arrowRight, size: 24),
                ],
              ),
      ),
    );
  }
}
