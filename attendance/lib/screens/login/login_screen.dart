import 'package:attendance/providers/auth_provider.dart';
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
  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _signIn() async {
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
    final authStatus = context.watch<AuthProvider>().status;
    final isLoading = authStatus == AuthStatus.authenticating;

    return Scaffold(
      backgroundColor: WC.bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _LoginHeader(animation: _fadeIn),
          Expanded(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(color: WC.white),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EMPLOYEE ID',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: WC.muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _IdInputField(controller: _controller),
                          const SizedBox(height: 28),
                          _SignInButton(loading: isLoading, onTap: _signIn),
                          const SizedBox(height: 24),
                          const Center(
                            child: Text(
                              'Your Employee ID was provided when your\naccount was created.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: WC.muted,
                                height: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          _HintChip(
                            text:
                                'Available IDs: EMP001 – EMP008  ·  Admin: EMP001',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  final Animation<double> animation;
  const _LoginHeader({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: WC.black,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 44),
          child: FadeTransition(
            opacity: animation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: WC.white.withOpacity(0.10),
                    borderRadius: WC.r12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: WC.white,
                          borderRadius: WC.r8,
                        ),
                        child: const Icon(
                          Icons.location_city_rounded,
                          size: 18,
                          color: WC.black,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WorkCheck',
                            style: TextStyle(
                              color: WC.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Office Attendance',
                            style: TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                const Text(
                  'Welcome\nback 👋',
                  style: TextStyle(
                    color: WC.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    letterSpacing: -1.0,
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

class _IdInputField extends StatelessWidget {
  final TextEditingController controller;
  const _IdInputField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WC.bg,
        borderRadius: WC.r12,
        border: Border.all(color: WC.border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 56,
            decoration: BoxDecoration(
              color: WC.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            child: const Icon(Icons.badge_outlined, color: WC.muted, size: 22),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: WC.black,
                letterSpacing: 0.5,
              ),
              decoration: const InputDecoration(
                hintText: 'e.g. EMP001',
                hintStyle: TextStyle(
                  color: WC.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _SignInButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          color: loading ? const Color(0xFF333333) : WC.black,
          borderRadius: WC.rFull,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: WC.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sign In',
                      style: TextStyle(
                        color: WC.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: WC.white, size: 18),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final String text;
  const _HintChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: WC.surface,
        borderRadius: WC.r12,
        border: Border.all(color: WC.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: WC.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: WC.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
