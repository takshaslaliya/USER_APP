import 'package:flutter/material.dart';
import 'package:splitease_test/core/services/auth_service.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/shared/widgets/app_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  // Sign-in controllers
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  // Sign-up extra controllers
  final _signupUsernameController = TextEditingController();
  final _signupFullNameController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPhoneController = TextEditingController();
  final _signupPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _initDone = false;

  // Login method: 'email' or 'mobile'
  String _loginMethod = 'email';
  // OTP step for email login
  bool _otpSent = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initDone) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['isSignUp'] == true) {
        _isSignUp = true;
      }
      _initDone = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _signupUsernameController.dispose();
    _signupFullNameController.dispose();
    _signupEmailController.dispose();
    _signupPhoneController.dispose();
    _signupPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // ── SIGN UP ──────────────────────────────────────────────────────────
    if (_isSignUp) {
      final result = await AuthService.signup(
        mobileNumber: _signupPhoneController.text.trim(),
        email: _signupEmailController.text.trim(),
        username: _signupUsernameController.text.trim(),
        fullName: _signupFullNameController.text.trim(),
        password: _signupPasswordController.text,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.success) {
        // Navigate to OTP verification screen
        Navigator.pushNamed(
          context,
          '/verify-otp',
          arguments: _signupEmailController.text.trim(),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // ── EMAIL OTP LOGIN — Step 1: send OTP ───────────────────────────────
    if (_loginMethod == 'email' && !_otpSent) {
      final result = await AuthService.requestLoginOtp(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (result.success) _otpSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? AppColors.primary : AppColors.error,
        ),
      );
      return;
    }

    // ── EMAIL OTP LOGIN — Step 2: verify OTP ────────────────────────────
    if (_loginMethod == 'email' && _otpSent) {
      final result = await AuthService.verifyLoginOtp(
        email: _emailController.text.trim(),
        otp: _otpController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.success) {
        final type = result.data?['type'] as String? ?? 'user';
        Navigator.pushNamedAndRemoveUntil(
          context,
          type == 'admin' ? '/admin' : '/home',
          (r) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // ── MOBILE + PASSWORD LOGIN ──────────────────────────────────────────
    final result = await AuthService.loginWithPassword(
      emailOrMobile: _phoneController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      final type = result.data?['type'] as String? ?? 'user';
      Navigator.pushNamedAndRemoveUntil(
        context,
        type == 'admin' ? '/admin' : '/home',
        (r) => false,
      );
    } else if (result.statusCode == 403) {
      // Email not verified — take them to the OTP screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.error,
        ),
      );
      Navigator.pushNamed(
        context,
        '/verify-otp',
        arguments: _phoneController.text.trim(),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showForgotPasswordDialog() {
    String step = 'email'; // 'email' or 'otp'
    final emailCtrl = TextEditingController();
    final otpCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                step == 'email' ? 'Reset Password' : 'Verify OTP',
                style: TextStyle(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    step == 'email'
                        ? 'Enter your email address to receive a one-time password.'
                        : 'Enter the 6-digit code sent to ${emailCtrl.text}',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkSubtext
                          : AppColors.lightSubtext,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 16),
                  if (step == 'email')
                    TextFormField(
                      controller: emailCtrl,
                      decoration: InputDecoration(
                        hintText: 'Email address',
                        prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkBg
                            : AppColors.lightBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    )
                  else
                    TextFormField(
                      controller: otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        hintText: 'Enter 6-digit OTP',
                        prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkBg
                            : AppColors.lightBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                ],
              ),
              contentPadding: EdgeInsets.fromLTRB(24, 16, 24, 0),
              actionsPadding: EdgeInsets.all(16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkSubtext
                          : AppColors.lightSubtext,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AppButton(
                  label: step == 'email' ? 'Send OTP' : 'Verify',
                  width: 120,
                  onPressed: () {
                    if (step == 'email') {
                      if (emailCtrl.text.isEmpty ||
                          !emailCtrl.text.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Enter a valid email'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }
                      setStateDialog(() => step = 'otp');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('OTP sent to email! Check your inbox.'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    } else {
                      if (otpCtrl.text.length == 6) {
                        Navigator.pop(context); // Close dialog
                        Navigator.pushNamed(context, '/reset-password');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Invalid OTP. Please try 1234.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.bgGradientDarkTop, AppColors.bgGradientDarkBottom]
                : [
                    AppColors.bgGradientLightTop,
                    AppColors.bgGradientLightBottom,
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppTheme.padding),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                    // Back
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                          size: 20,
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: AppColors.primaryGradient,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.currency_rupee_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'SplitEase',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 32),
                    Text(
                      _isSignUp ? 'Create Account' : 'Welcome Back',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      _isSignUp
                          ? 'Sign up to start splitting expenses'
                          : 'Sign in to your account',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkSubtext
                            : AppColors.lightSubtext,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 24),
                    // Form
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadius,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black26
                                : AppColors.softShadowColor,
                            offset: const Offset(0, 8),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // ── Sign Up fields ──────────────────────────────
                            if (_isSignUp) ...[
                              TextFormField(
                                controller: _signupUsernameController,
                                decoration: InputDecoration(
                                  hintText: 'Username',
                                  prefixIcon: Icon(
                                    Icons.alternate_email_rounded,
                                    size: 20,
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Enter a username';
                                  }
                                  if (v.contains(' ')) {
                                    return 'No spaces allowed';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 14),
                              TextFormField(
                                controller: _signupFullNameController,
                                decoration: InputDecoration(
                                  hintText: 'Full Name',
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                    size: 20,
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Enter your full name'
                                    : null,
                              ),
                              SizedBox(height: 14),
                              TextFormField(
                                controller: _signupEmailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  hintText: 'Email address',
                                  prefixIcon: Icon(
                                    Icons.mail_outline_rounded,
                                    size: 20,
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Enter your email';
                                  }
                                  if (!v.contains('@')) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 14),
                              TextFormField(
                                controller: _signupPhoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  hintText: 'Mobile Number',
                                  prefixIcon: Icon(
                                    Icons.phone_outlined,
                                    size: 20,
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Enter mobile number';
                                  }
                                  if (v.length < 10) {
                                    return 'Enter valid 10-digit number';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 14),
                              TextFormField(
                                controller: _signupPasswordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  prefixIcon: Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (v) => (v == null || v.length < 6)
                                    ? 'Password must be at least 6 characters'
                                    : null,
                              ),
                            ],

                            // ── Sign In fields ──────────────────────────────
                            if (!_isSignUp) ...[
                              // Toggle: Email vs Mobile
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkBg
                                      : AppColors.lightBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    _loginToggle('Email', 'email', isDark),
                                    _loginToggle('Mobile', 'mobile', isDark),
                                  ],
                                ),
                              ),
                              SizedBox(height: 18),

                              // ── Email OTP flow ──
                              if (_loginMethod == 'email') ...[
                                _buildEmailField(isDark),
                                if (_otpSent) ...[
                                  SizedBox(height: 14),
                                  TextFormField(
                                    controller: _otpController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    decoration: InputDecoration(
                                      hintText: 'Enter 6-digit OTP',
                                      prefixIcon: Icon(
                                        Icons.pin_outlined,
                                        size: 20,
                                      ),
                                      counterText: '',
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Enter the OTP';
                                      }
                                      if (v.length < 6) {
                                        return 'OTP must be 6 digits';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ],

                              // ── Mobile Password flow ──
                              if (_loginMethod == 'mobile') ...[
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    hintText: 'Mobile Number',
                                    prefixIcon: Icon(
                                      Icons.phone_outlined,
                                      size: 20,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Enter mobile number';
                                    }
                                    if (v.length < 10) {
                                      return 'Enter valid 10-digit number';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 14),
                                _buildPasswordField(isDark),
                              ],

                              // ── Forgot Password (email only) ──
                              if (_loginMethod == 'email' && !_otpSent)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _showForgotPasswordDialog,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.only(
                                        top: 12,
                                        bottom: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],

                            SizedBox(height: 24),
                            AppButton(
                              label: _isSignUp
                                  ? 'Create Account'
                                  : (_loginMethod == 'email' && !_otpSent)
                                  ? 'Send OTP'
                                  : 'Sign In',
                              onPressed: _handleLogin,
                              isLoading: _isLoading,
                            ),
                            if (!_isSignUp &&
                                _loginMethod == 'email' &&
                                _otpSent)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _otpSent = false;
                                    _otpController.clear();
                                  });
                                },
                                child: Text(
                                  'Resend OTP',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _isSignUp = !_isSignUp),
                        child: RichText(
                          text: TextSpan(
                            text: _isSignUp
                                ? 'Already have an account? '
                                : "Don't have an account? ",
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkSubtext
                                  : AppColors.lightSubtext,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: _isSignUp ? 'Sign In' : 'Create Account',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginToggle(String label, String mode, bool isDark) {
    final selected = _loginMethod == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_loginMethod != mode) {
            setState(() {
              _loginMethod = mode;
              _otpSent = false;
              _otpController.clear();
              _formKey.currentState?.reset();
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.all(4),
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : isDark
                    ? AppColors.darkSubtext
                    : AppColors.lightSubtext,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField(bool isDark) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        hintText: 'Email address',
        prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Enter your email';
        if (!v.contains('@')) return 'Enter a valid email';
        return null;
      },
    );
  }

  Widget _buildPasswordField(bool isDark) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        hintText: 'Password',
        prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (v) =>
          v!.length < 4 ? 'Password must be at least 4 characters' : null,
    );
  }
}
