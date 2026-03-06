import 'package:flutter/material.dart';
import 'package:splitease_test/core/services/auth_service.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/shared/widgets/app_button.dart';
import 'package:splitease_test/shared/utils/notification_helper.dart';

/// Shown after successful signup — user must enter the OTP sent to their email.
class VerifyOtpScreen extends StatefulWidget {
  final String email;
  const VerifyOtpScreen({super.key, required this.email});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await AuthService.verifySignupOtp(
      email: widget.email,
      otp: _otpController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      NotificationHelper.showSuccess(context, result.message);
      // Navigate to login after verification
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    } else {
      NotificationHelper.showError(context, result.message);
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    final result = await AuthService.resendSignupOtp(email: widget.email);
    if (!mounted) return;
    setState(() => _isResending = false);
    if (result.success) {
      NotificationHelper.showSuccess(context, result.message);
    } else {
      NotificationHelper.showError(context, result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
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
                    color: textColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Icon(
                Icons.mark_email_read_outlined,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Verify your email',
                style: TextStyle(
                  color: textColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit OTP to\n${widget.email}',
                style: TextStyle(color: subColor, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black26
                          : AppColors.softShadowColor,
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 8,
                        ),
                        decoration: InputDecoration(
                          hintText: '------',
                          hintStyle: TextStyle(
                            color: subColor,
                            fontSize: 28,
                            letterSpacing: 8,
                          ),
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter the OTP';
                          if (v.length < 6) return 'OTP must be 6 digits';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'Verify & Continue',
                        onPressed: _verify,
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: _isResending ? null : _resend,
                  child: _isResending
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Text(
                          'Didn\'t receive it? Resend OTP',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
