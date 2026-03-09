import 'package:flutter/material.dart';
import 'package:splitease_test/core/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              '1. Information We Collect',
              'We collect information you provide directly to us, such as your name, email, phone number, and UPI ID when you create an account.',
              textColor,
            ),
            _buildSection(
              '2. How We Use Information',
              'We use the information to manage your account, provide expense tracking features, send WhatsApp reminders, and improve our services.',
              textColor,
            ),
            _buildSection(
              '3. Information Sharing',
              'We share your name and amount with group members to facilitate expense tracking. We do not sell your personal information to third parties.',
              textColor,
            ),
            _buildSection(
              '4. Data Security',
              'We use industry-standard measures to protect your data. However, no method of transmission over the internet is 100% secure.',
              textColor,
            ),
            _buildSection(
              '5. Your Choices',
              'You can update your profile information or delete your account at any time through the app settings.',
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
