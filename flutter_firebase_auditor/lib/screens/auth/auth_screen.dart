import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/theme/app_theme.dart';
import '../../core/routing/auth_guard.dart';
import '../../widgets/animated_fade_slide.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/grid_background.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Tabs: 0 = Sign In, 1 = Sign Up
  int _tabIndex = 0;
  bool _forgotPasswordFlow = false;

  void _switchTab(int index) {
    setState(() {
      _tabIndex = index;
      _forgotPasswordFlow = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isAuthenticated()) {
      requireGuest(context);
    }

    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          if (isDesktop)
            Expanded(
              flex: 11,
              child: GridBackground(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppColors.accentPrimary, AppColors.accentSecondary],
                            ),
                          ),
                          child: const Icon(Icons.shield, color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 32),
                        Text('Fair AI starts here.', style: AppTypography.displayMedium),
                        const SizedBox(height: 48),
                        const AnimatedFadeSlide(delay: 100, child: _FeaturePill(icon: Icons.balance, text: 'Audit any ML model for bias')),
                        const SizedBox(height: 16),
                        const AnimatedFadeSlide(delay: 200, child: _FeaturePill(icon: Icons.lock, text: 'Your data never leaves your machine')),
                        const SizedBox(height: 16),
                        const AnimatedFadeSlide(delay: 300, child: _FeaturePill(icon: Icons.insert_chart, text: 'Compliance-ready PDF reports')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          Expanded(
            flex: 9,
            child: Container(
              color: AppColors.surface,
              height: double.infinity,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64.0 : 24.0, vertical: 48.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isDesktop) ...[
                      const Icon(Icons.shield, color: AppColors.accentPrimary, size: 40),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      _forgotPasswordFlow 
                        ? 'Reset Password' 
                        : 'Sign in to Themis', 
                      style: AppTypography.headlineMedium
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _forgotPasswordFlow 
                        ? 'Enter your email and we\'ll send a reset link.'
                        : 'Save your audit history and access reports across sessions.',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 32),
                    if (_forgotPasswordFlow)
                      _ForgotPasswordForm(onBack: () => setState(() => _forgotPasswordFlow = false))
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AuthTabBar(
                            selectedIndex: _tabIndex,
                            onTabSelected: _switchTab,
                          ),
                          const SizedBox(height: 32),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _tabIndex == 0 
                              ? _SignInForm(
                                  onForgotPassword: () => setState(() => _forgotPasswordFlow = true),
                                  onSwitchToSignUp: () => _switchTab(1),
                                )
                              : _SignUpForm(
                                  onSwitchToSignIn: () => _switchTab(0),
                                ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeaturePill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withOpacity(0.5),
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accentPrimary, size: 20),
          const SizedBox(width: 12),
          Text(text, style: AppTypography.titleMedium),
        ],
      ),
    );
  }
}

class _AuthTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const _AuthTabBar({required this.selectedIndex, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(child: _TabButton(text: 'Sign In', isSelected: selectedIndex == 0, onTap: () => onTabSelected(0))),
          Expanded(child: _TabButton(text: 'Sign Up', isSelected: selectedIndex == 1, onTap: () => onTabSelected(1))),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({required this.text, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isSelected 
            ? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))]
            : null,
        ),
        child: Center(
          child: Text(
            text,
            style: AppTypography.titleMedium.copyWith(
              color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// SIGN IN FORM
// -------------------------------------------------------------
class _SignInForm extends StatefulWidget {
  final VoidCallback onForgotPassword;
  final VoidCallback onSwitchToSignUp;
  const _SignInForm({required this.onForgotPassword, required this.onSwitchToSignUp});

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _error = null; _loading = true; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Invalid credentials');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InputBox(label: 'EMAIL', controller: _emailCtrl, hint: 'you@example.com'),
        const SizedBox(height: 16),
        _InputBox(
          label: 'PASSWORD', 
          controller: _passCtrl, 
          hint: '••••••••',
          obscureText: _obscure,
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted, size: 18),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: widget.onForgotPassword,
            child: Text('Forgot password?', style: AppTypography.labelMedium.copyWith(color: AppColors.accentPrimary)),
          ),
        ),
        if (_error != null) _ErrorShake(error: _error!),
        const SizedBox(height: 16),
        GradientButton(
          text: 'Sign In',
          onPressed: _loading ? null : _submit,
          isLoading: _loading,
        ),
        const SizedBox(height: 16),
        const _DividerOr(),
        const SizedBox(height: 16),
        const _GoogleSignInButton(),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Don\'t have an account?', style: AppTypography.labelMedium.copyWith(color: AppColors.textMuted)),
            TextButton(
              onPressed: widget.onSwitchToSignUp,
              child: Text('Sign up', style: AppTypography.labelMedium.copyWith(color: AppColors.accentPrimary)),
            )
          ],
        )
      ],
    );
  }
}

// -------------------------------------------------------------
// SIGN UP FORM
// -------------------------------------------------------------
class _SignUpForm extends StatefulWidget {
  final VoidCallback onSwitchToSignIn;
  const _SignUpForm({required this.onSwitchToSignIn});

  @override
  State<_SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<_SignUpForm> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = "Passwords do not match");
      return;
    }
    setState(() { _error = null; _loading = true; });
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (cred.user != null) {
        await cred.user!.updateDisplayName(_nameCtrl.text.trim());
      }
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Sign up failed');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InputBox(label: 'DISPLAY NAME', controller: _nameCtrl, hint: 'Ada Lovelace'),
        const SizedBox(height: 16),
        _InputBox(label: 'EMAIL', controller: _emailCtrl, hint: 'you@example.com'),
        const SizedBox(height: 16),
        _InputBox(
          label: 'PASSWORD', 
          controller: _passCtrl, 
          hint: '••••••••',
          obscureText: true,
          onChanged: (_) => setState((){}), // trigger rebuild for strength indicator
        ),
        _PasswordStrengthBar(password: _passCtrl.text),
        const SizedBox(height: 16),
        _InputBox(label: 'CONFIRM PASSWORD', controller: _confirmCtrl, hint: '••••••••', obscureText: true),
        if (_error != null) _ErrorShake(error: _error!),
        const SizedBox(height: 24),
        GradientButton(
          text: 'Create Account',
          onPressed: _loading ? null : _submit,
          isLoading: _loading,
        ),
        const SizedBox(height: 16),
        const _DividerOr(),
        const SizedBox(height: 16),
        const _GoogleSignInButton(),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Already have an account?', style: AppTypography.labelMedium.copyWith(color: AppColors.textMuted)),
            TextButton(
              onPressed: widget.onSwitchToSignIn,
              child: Text('Sign in', style: AppTypography.labelMedium.copyWith(color: AppColors.accentPrimary)),
            )
          ],
        )
      ],
    );
  }
}

// -------------------------------------------------------------
// FORGOT PASSWORD FORM
// -------------------------------------------------------------
class _ForgotPasswordForm extends StatefulWidget {
  final VoidCallback onBack;
  const _ForgotPasswordForm({required this.onBack});

  @override
  State<_ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends State<_ForgotPasswordForm> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _success = false;

  Future<void> _submit() async {
    setState(() { _error = null; _loading = true; });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailCtrl.text.trim());
      if (mounted) setState(() => _success = true);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Unknown error');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        builder: (context, val, child) => Transform.scale(
          scale: val,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: AppColors.severityLow, size: 64),
              const SizedBox(height: 16),
              Text('Check your inbox.', style: AppTypography.headlineSmall),
              const SizedBox(height: 32),
              TextButton(
                onPressed: widget.onBack,
                child: Text('Back to Sign In', style: AppTypography.labelMedium.copyWith(color: AppColors.accentPrimary)),
              )
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: widget.onBack,
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
        ),
        const SizedBox(height: 16),
        _InputBox(label: 'EMAIL', controller: _emailCtrl, hint: 'you@example.com'),
        if (_error != null) _ErrorShake(error: _error!),
        const SizedBox(height: 24),
        GradientButton(
          text: 'Send Reset Link',
          onPressed: _loading ? null : _submit,
          isLoading: _loading,
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// REUSABLE PIECES
// -------------------------------------------------------------

class _InputBox extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  const _InputBox({required this.label, required this.controller, required this.hint, this.obscureText = false, this.suffixIcon, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelMedium.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          onChanged: onChanged,
          style: AppTypography.bodyLarge.copyWith(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.textMuted),
            filled: true,
            fillColor: const Color(0xFF27272A),
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: const Color(0xFF3F3F46))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: const Color(0xFF3F3F46))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accentPrimary)),
          ),
        ),
      ],
    );
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  final String password;
  const _PasswordStrengthBar({required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[^A-Za-z0-9]'))) strength++;

    List<Color> colors = [const Color(0xFF3F3F46), const Color(0xFF3F3F46), const Color(0xFF3F3F46), const Color(0xFF3F3F46)];
    String label = "Weak";
    Color labelColor = AppColors.severityCritical;

    if (strength == 1) {
      colors[0] = AppColors.severityCritical;
    } else if (strength == 2) {
      colors[0] = colors[1] = AppColors.severityHigh;
      label = "Fair";
      labelColor = AppColors.severityHigh;
    } else if (strength == 3) {
      colors[0] = colors[1] = colors[2] = AppColors.severityMedium;
      label = "Good";
      labelColor = AppColors.severityMedium;
    } else if (strength == 4) {
      colors[0] = colors[1] = colors[2] = colors[3] = AppColors.severityLow;
      label = "Strong";
      labelColor = AppColors.severityLow;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(4, (i) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(color: colors[i], borderRadius: BorderRadius.circular(2)),
              ),
            )),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.bodySmall.copyWith(color: labelColor)),
        ],
      ),
    );
  }
}

class _DividerOr extends StatelessWidget {
  const _DividerOr();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.borderSubtle)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('or', style: AppTypography.labelMedium.copyWith(color: AppColors.textMuted))),
        Expanded(child: Container(height: 1, color: AppColors.borderSubtle)),
      ],
    );
  }
}

class _GoogleSignInButton extends StatefulWidget {
  const _GoogleSignInButton();
  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _hover = false;
  bool _loading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    try {
      final googleProvider = GoogleAuthProvider();
      await FirebaseAuth.instance.signInWithPopup(googleProvider);
      
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      debugPrint("Google Sign in error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _loading ? null : _handleGoogleSignIn,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFF8F8F8) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF3F3F46)),
          ),
          child: _loading 
            ? const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue)))
            : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Generic Google G 
                RichText(text: const TextSpan(children: [
                  TextSpan(text: 'G', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w900, fontSize: 20, fontFamily: 'Arial')),
                ])),
                const SizedBox(width: 12),
                const Text('Continue with Google', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 16)),
              ],
            ),
        ),
      ),
    );
  }
}

class _ErrorShake extends StatefulWidget {
  final String error;
  const _ErrorShake({required this.error});

  @override
  State<_ErrorShake> createState() => _ErrorShakeState();
}

class _ErrorShakeState extends State<_ErrorShake> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..forward();
  }

  @override
  void didUpdateWidget(_ErrorShake oldWidget) {
    if (oldWidget.error != widget.error) {
       _anim.forward(from: 0);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final sine = sin(_anim.value * 3 * pi);
        return Transform.translate(
          offset: Offset(sine * 4, 0),
          child: Padding(
             padding: const EdgeInsets.only(top: 8),
             child: Row(
               children: [
                 const Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171), size: 16),
                 const SizedBox(width: 8),
                 Expanded(child: Text(widget.error, style: AppTypography.bodySmall.copyWith(color: const Color(0xFFF87171)))),
               ],
             ),
          ),
        );
      },
    );
  }
}
