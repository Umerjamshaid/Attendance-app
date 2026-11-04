import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/widgets/demo_mode_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/wc_tokens.dart';

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
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final id = _controller.text.trim();
    if (id.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(id);

    if (success) {
      widget.onLoginSuccess?.call();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Login failed'),
          backgroundColor: WC.absent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        context.watch<AuthProvider>().status == AuthStatus.authenticating;

    return Scaffold(
      backgroundColor: WC.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minHeight = (constraints.maxHeight - 48).clamp(
              0.0,
              double.infinity,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 440,
                    minHeight: minHeight,
                  ),
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _riseIn,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _BrandHeader(),
                          const SizedBox(height: 44),
                          const Text(
                            'Welcome back',
                            style: TextStyle(
                              color: WC.black,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Sign in with your employee ID to continue.',
                            style: TextStyle(
                              color: WC.muted,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                          if (context.watch<AuthProvider>().isDemoMode) ...[
                            const SizedBox(height: 16),
                            const DemoModeNotice(),
                          ],
                          const SizedBox(height: 30),
                          _EmployeeIdField(
                            controller: _controller,
                            onSubmitted: (_) => _signIn(),
                          ),
                          const SizedBox(height: 20),
                          _SignInButton(loading: isLoading, onPressed: _signIn),
                          const SizedBox(height: 20),
                          const Text(
                            'Your Employee ID was provided when your account was created.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: WC.muted,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const _HintChip(
                            text: 'Demo IDs: EMP001 – EMP003 · Admin: EMP001',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
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
          decoration: BoxDecoration(color: WC.black, borderRadius: WC.r12),
          child: const Icon(
            Icons.fingerprint_rounded,
            color: WC.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WorkCheck',
              style: TextStyle(
                color: WC.black,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'OFFICE ATTENDANCE',
              style: TextStyle(
                color: WC.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmployeeIdField extends StatelessWidget {
  const _EmployeeIdField({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      inputFormatters: [UpperCaseTextFormatter()],
      style: const TextStyle(
        color: WC.black,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: 'Employee ID',
        hintText: 'e.g. EMP001',
        prefixIcon: const Icon(Icons.badge_outlined, color: WC.muted),
        filled: true,
        fillColor: WC.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: WC.r12,
          borderSide: const BorderSide(color: WC.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: WC.r12,
          borderSide: const BorderSide(color: WC.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: WC.r12,
          borderSide: const BorderSide(color: WC.accentBlue, width: 1.5),
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
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: WC.black,
          disabledBackgroundColor: const Color(0xFF333333),
          foregroundColor: WC.white,
          shape: const StadiumBorder(),
        ),
        child: loading
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: WC.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Signing in'),
                ],
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sign in',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: WC.surface, borderRadius: WC.r8),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: WC.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: WC.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
