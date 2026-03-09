import 'package:flutter/material.dart';
import 'package:splitease_test/core/theme/app_theme.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              '1. Acceptance of Terms',
              'By accessing or using SplitEase, you agree to be bound by these Terms and Conditions and our Privacy Policy.',
              textColor,
            ),
            _buildSection(
              '2. User Accounts',
              'You are responsible for maintaining the confidentiality of your account and password. You agree to accept responsibility for all activities that occur under your account.',
              textColor,
            ),
            _buildSection(
              '3. Use of Service',
              'SplitEase is a platform for tracking expenses. We do not handle actual money transfers. Any payments made are between users directly.',
              textColor,
            ),
            _buildSection(
              '4. Privacy',
              'Your privacy is important to us. Please review our Privacy Policy to understand how we collect and use your data.',
              textColor,
            ),
            _buildSection(
              '5. Limitation of Liability',
              'SplitEase shall not be liable for any indirect, incidental, special, consequential or punitive damages resulting from your use of the service.',
              textColor,
            ),
            const SizedBox(height: 20),
            Text(
              'Last Updated: March 2026',
              style: TextStyle(
                color: textColor.withOpacity(0.5),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: textColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
