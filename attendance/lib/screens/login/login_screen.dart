import 'package:attendance/config/app_icons.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/widgets/demo_mode_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/ui_tokens.dart';
import '../../widgets/spring_scale.dart';
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
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;
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
      duration: AppMotion.entrance,
    );
    _fadeIn = CurvedAnimation(
      parent: _animationController,
      curve: AppMotion.enterCurve,
    );
    _riseIn = Tween<Offset>(begin: const Offset(0, 0.015), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: AppMotion.enterCurve,
          ),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animationStarted = true;
      _animationController.value = 1;
    } else if (!_animationStarted) {
      _animationStarted = true;
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _password.dispose();
    _idFocus.dispose();
    _passwordFocus.dispose();
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
  Widget build(BuildContext context) => AutofillGroup(
    child: Theme(
      data: AppTypography.themeOf(context),
      child: Builder(builder: _buildContent),
    ),
  );

  Widget _buildContent(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final company = auth.isPublicBuild;
    final isLoading = auth.status == AuthStatus.authenticating;

    return Scaffold(
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
                            const SizedBox(height: 40),
                            Semantics(
                              header: true,
                              namesRoute: true,
                              child: Text(
                                'Sign in',
                                style: AppTypography.heading.copyWith(
                                  color: context.colors.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              company
                                  ? 'Sign in with your company account.'
                                  : 'Enter your employee ID to continue.',
                              style: AppTypography.body.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 32),
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
                                onSubmitted: (_) =>
                                    _passwordFocus.requestFocus(),
                                onChanged: (_) {
                                  if (_idError != null) {
                                    setState(() => _idError = null);
                                  }
                                },
                                style: AppTypography.body,
                                decoration: InputDecoration(
                                  labelText: 'Work email',
                                  errorText: _idError,
                                  prefixIcon: const Icon(
                                    AppIcons.mail,
                                    size: AppLayout.compactIconSize,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _password,
                                focusNode: _passwordFocus,
                                readOnly: isLoading,
                                obscureText: _obscurePassword,
                                enableSuggestions: false,
                                autocorrect: false,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _signIn(),
                                style: AppTypography.body,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(
                                    AppIcons.lock,
                                    size: AppLayout.compactIconSize,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: isLoading
                                        ? null
                                        : () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? AppIcons.eye
                                          : AppIcons.eyeOff,
                                      size: AppLayout.compactIconSize,
                                    ),
                                  ),
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
                                style: AppTypography.caption.copyWith(
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
                              style: AppTypography.caption.copyWith(
                                color: context.colors.onSurfaceVariant,
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
            borderRadius: BorderRadius.circular(AppLayout.fieldRadius),
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
                style: AppTypography.title.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Office attendance',
                style: AppTypography.caption.copyWith(
                  color: context.colors.onSurfaceVariant,
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
      style: AppTypography.body.copyWith(color: context.colors.onSurface),
      decoration: InputDecoration(
        labelText: 'Employee ID',
        errorText: errorText,
        hintText: 'e.g. EMP001',
        prefixIcon: const Icon(
          AppIcons.idBadge2,
          size: AppLayout.compactIconSize,
        ),
      ),
    );
  }
}

class _SignInButton extends StatefulWidget {
  const _SignInButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  State<_SignInButton> createState() => _SignInButtonState();
}

class _SignInButtonState extends State<_SignInButton> {
  final _states = WidgetStatesController();
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _states.addListener(_updatePress);
  }

  void _updatePress() {
    final pressed = _states.value.contains(WidgetState.pressed);
    if (pressed != _pressed) setState(() => _pressed = pressed);
  }

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SpringScale(
      pressed: _pressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppLayout.controlHeight),
        child: FilledButton(
          statesController: _states,
          onPressed: widget.loading ? null : widget.onPressed,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            disabledBackgroundColor: context.colors.surfaceContainerHighest,
            disabledForegroundColor: context.colors.onSurfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppLayout.fieldRadius),
            ),
          ),
          child: AnimatedSwitcher(
            duration: AppMotion.duration(context, AppMotion.fast),
            switchInCurve: AppMotion.enterCurve,
            switchOutCurve: AppMotion.exitCurve,
            child: widget.loading
                ? Row(
                    key: const ValueKey('signing-in'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: context.colors.onSurfaceVariant,
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
                    key: ValueKey('sign-in'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text('Sign in')),
                      SizedBox(width: 10),
                      Icon(
                        AppIcons.arrowRight,
                        size: AppLayout.compactIconSize,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
