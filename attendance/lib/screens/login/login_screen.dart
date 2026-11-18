import 'package:attendance/widgets/app_toast.dart';
import 'package:attendance/config/app_icons.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/widgets/demo_mode_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:motor/motor.dart';
import 'package:portal_labs/portal_labs.dart'
    show LoadingShapes, LoadingShapesStyle;
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/app_info.dart';
import '../../config/ui_tokens.dart';
import '../../config/utility_surface_theme.dart';
import '../../widgets/app_identity_footer.dart';
import '../../widgets/error_shake.dart';
import '../profile/account_edit_screen.dart';
import 'email_code_screen.dart';
import 'office_code_screen.dart';

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
  String? _passwordError;
  String? _formError;
  int _errorRevision = 0;
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
    final idError = id.isEmpty
        ? (company ? 'Enter your work email.' : 'Enter your employee ID.')
        : company && !id.contains('@')
        ? 'Enter a valid work email.'
        : null;
    final passwordError = company && _password.text.isEmpty
        ? 'Enter your password.'
        : null;
    setState(() {
      _idError = idError;
      _passwordError = passwordError;
      _formError = null;
      _errorRevision++;
    });
    if (idError != null || passwordError != null) {
      (idError != null ? _idFocus : _passwordFocus).requestFocus();
      return;
    }
    final success = await authProvider.login(id, password: _password.text);
    if (!mounted) return;

    if (success) {
      widget.onLoginSuccess?.call();
    } else {
      setState(() {
        final message = authProvider.error ?? 'Login failed';
        if (company) {
          _formError = message;
        } else {
          _idError = message;
        }
        _errorRevision++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = utilitySurfaceThemeData(AppTypography.themeOf(context));
    final colors = theme.colorScheme;
    return AutofillGroup(
      child: Theme(
        data: theme.copyWith(
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            fillColor: colors.surfaceContainerLow,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppLayout.groupRadius),
              borderSide: BorderSide(color: colors.outlineVariant),
            ),
          ),
        ),
        child: Builder(builder: _buildContent),
      ),
    );
  }

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
            child: LayoutBuilder(
              builder: (context, viewport) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: viewport.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _riseIn,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const _BrandHeader(),
                            const SizedBox(height: 28),
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
                            if (!company) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Enter your employee ID to continue.',
                                style: AppTypography.body.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            if (company) ...[
                              ErrorShake(
                                error: _idError,
                                revision: _errorRevision,
                                child: TextField(
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
                                    if (_idError != null ||
                                        _formError != null) {
                                      setState(() {
                                        _idError = null;
                                        _formError = null;
                                      });
                                    }
                                  },
                                  style: AppTypography.body,
                                  decoration: InputDecoration(
                                    labelText: 'Work email',
                                    errorText: _idError,
                                    errorMaxLines: 8,
                                    prefixIcon: const Icon(
                                      AppIcons.mail,
                                      size: AppLayout.compactIconSize,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ErrorShake(
                                error: _passwordError,
                                revision: _errorRevision,
                                child: TextField(
                                  controller: _password,
                                  focusNode: _passwordFocus,
                                  readOnly: isLoading,
                                  obscureText: _obscurePassword,
                                  enableSuggestions: false,
                                  autocorrect: false,
                                  autofillHints: const [AutofillHints.password],
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _signIn(),
                                  onChanged: (_) {
                                    if (_passwordError != null ||
                                        _formError != null) {
                                      setState(() {
                                        _passwordError = null;
                                        _formError = null;
                                      });
                                    }
                                  },
                                  style: AppTypography.body,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    errorText: _passwordError,
                                    errorMaxLines: 8,
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
                              ),
                              if (_formError != null) ...[
                                const SizedBox(height: 8),
                                ErrorShake(
                                  error: _formError,
                                  revision: _errorRevision,
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _formError!,
                                      style: AppTypography.caption.copyWith(
                                        color: context.colors.error,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (auth.authLinkError case final error?)
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    error,
                                    style: AppTypography.caption.copyWith(
                                      color: context.colors.error,
                                    ),
                                  ),
                                ),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton(
                                  onPressed: isLoading || !auth.isConfigured
                                      ? null
                                      : () => _openPasswordRecovery(
                                          context,
                                          auth,
                                        ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: context.colors.primary,
                                    minimumSize: const Size(0, 48),
                                  ),
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                              if (!auth.isConfigured)
                                const Text(
                                  'Company sign-in is unavailable in this build.',
                                ),
                            ] else
                              ErrorShake(
                                error: _idError,
                                revision: _errorRevision,
                                child: _EmployeeIdField(
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
                            SizedBox(height: company ? 8 : 20),
                            _SignInButton(
                              loading: isLoading,
                              onPressed: _signIn,
                            ),
                            if (company) ...[
                              const SizedBox(height: 24),
                              _companyOptions(context, auth, isLoading),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: isLoading ? null : auth.enterPreview,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                ),
                                icon: const Icon(AppIcons.play, size: 20),
                                label: const Text('Explore demo'),
                              ),
                            ],
                            const SizedBox(height: 8),
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _companyOptions(BuildContext context, AuthProvider auth, bool busy) {
    final colors = context.colors;
    final enabled = !busy && auth.isConfigured;
    final hasOfficeCode = auth.backend?.supportsOfficeInviteCodes == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, bottom: 8),
          child: Semantics(
            header: true,
            child: Text(
              'Other ways to sign in',
              style: AppTypography.label.copyWith(color: colors.primary),
            ),
          ),
        ),
        Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppLayout.groupRadius),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (hasOfficeCode) ...[
                _LoginMethod(
                  label: 'Use office code',
                  icon: AppIcons.idBadge2,
                  onTap: enabled ? () => _openOfficeCode(context, auth) : null,
                ),
                const Divider(height: 1, indent: 52, endIndent: 16),
              ],
              _LoginMethod(
                label: 'Use email code',
                icon: AppIcons.mail,
                onTap: enabled
                    ? () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => EmailCodeScreen(
                            backend: auth.backend!,
                            email: _controller.text,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openOfficeCode(BuildContext context, AuthProvider auth) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OfficeCodeScreen(
          signInEmail: _controller.text,
          join: (code, email, password) async {
            final joined = await auth.loginWithOfficeCode(
              email,
              password,
              code,
            );
            return joined ? null : auth.error ?? 'Could not join. Try again.';
          },
        ),
      ),
    );
  }

  void _openPasswordRecovery(BuildContext context, AuthProvider auth) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => AccountEditScreen(
          title: 'Reset password',
          label: 'Work email',
          email: true,
          requireChange: false,
          initialValue: _controller.text,
          actionLabel: 'Send recovery email',
          onSave: (value) => auth.backend!.resetPassword(value),
          onSaved: () {
            if (!context.mounted ||
                ModalRoute.of(routeContext)?.isCurrent != true) {
              return;
            }
            Navigator.pop(routeContext);
            AppToast.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'If the account exists, a recovery email will arrive shortly.',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginMethod extends StatelessWidget {
  const _LoginMethod({required this.label, required this.icon, this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    enabled: onTap != null,
    leading: Icon(icon, size: AppLayout.compactIconSize),
    trailing: const Icon(
      AppIcons.chevronRight,
      size: AppLayout.compactIconSize,
    ),
    title: Text(label),
    titleTextStyle: AppTypography.label.copyWith(
      color: onTap == null
          ? context.colors.onSurfaceVariant
          : context.colors.onSurface,
    ),
    minTileHeight: AppLayout.controlHeight,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    onTap: onTap,
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AttendanceMark(size: 52),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppInfo.name,
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
        errorMaxLines: 8,
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
    if (pressed == _pressed) return;
    // FilledButton can clear the pressed state during its build when disabled.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updatePress();
      });
    } else {
      setState(() => _pressed = pressed);
    }
  }

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final animate =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    final style = FilledButton.styleFrom(
      minimumSize: const Size(0, 58),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      textStyle: AppTypography.body.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      disabledBackgroundColor: colors.primaryContainer,
      disabledForegroundColor: colors.onPrimaryContainer,
      animationDuration: Duration.zero,
    );

    return Semantics(
      liveRegion: widget.loading,
      child: SingleMotionBuilder(
        motion: const MaterialSpringMotion.expressiveSpatialFast(),
        active: animate,
        value: _pressed && animate && !widget.loading ? 16.0 : 29.0,
        builder: (_, radius, child) => FilledButton(
          statesController: _states,
          onPressed: widget.loading ? null : widget.onPressed,
          style: style.copyWith(
            shape: WidgetStatePropertyAll(
              RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(radius.clamp(16.0, 29.0)),
              ),
            ),
          ),
          child: child!,
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
                    if (animate)
                      LoadingShapes(
                        style: LoadingShapesStyle(
                          size: 20,
                          color: colors.onPrimaryContainer,
                          enableHaptics: false,
                        ),
                      )
                    else
                      const Icon(
                        AppIcons.clock,
                        size: AppLayout.compactIconSize,
                      ),
                    const SizedBox(width: 10),
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
                    Icon(AppIcons.arrowRight, size: AppLayout.compactIconSize),
                  ],
                ),
        ),
      ),
    );
  }
}
