import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/shared/widgets/app_button.dart';

class WhatsAppLinkSheet extends StatefulWidget {
  const WhatsAppLinkSheet({super.key});

  @override
  State<WhatsAppLinkSheet> createState() => _WhatsAppLinkSheetState();
}

class _WhatsAppLinkSheetState extends State<WhatsAppLinkSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _otpSent = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _sendOtp() {
    if (_phoneController.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid mobile number first'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _otpSent = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('OTP Sent to WhatsApp! Use 1234 for testing.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _verifyOtp() {
    if (_otpController.text == '1234') {
      Navigator.pop(context, true); // Returning true marks it as successful
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid OTP'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Link WhatsApp',
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 20),
            _buildLinkOptions(isDark, subColor),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkOptions(bool isDark, Color subColor) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: AppColors.whatsapp,
          labelColor: AppColors.whatsapp,
          unselectedLabelColor: subColor,
          labelStyle: TextStyle(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Mobile OTP'),
            Tab(text: 'QR Scan'),
          ],
        ),
        SizedBox(height: 20),
        SizedBox(
          height: 300,
          child: TabBarView(
            controller: _tabController,
            children: [
              // OTP Flow
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'Enter Mobile Number',
                      prefixIcon: Icon(Icons.phone_rounded),
                      filled: true,
                      fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  if (_otpSent)
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: InputDecoration(
                        hintText: 'Enter 4-digit OTP',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
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
                  const Spacer(),
                  AppButton(
                    label: _otpSent ? 'Verify OTP' : 'Send OTP',
                    icon: _otpSent
                        ? Icons.check_circle_outline_rounded
                        : Icons.send_rounded,
                    gradientColors: [
                      AppColors.whatsapp,
                      AppColors.whatsapp,
                    ],
                    onPressed: _otpSent ? _verifyOtp : _sendOtp,
                  ),
                ],
              ),
              // QR Flow
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Scan this QR code from your WhatsApp device to link accounts instantly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subColor, fontSize: 13),
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: 'whatsapp://send?phone=dummy&text=link',
                        version: QrVersions.auto,
                        size: 150.0,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  AppButton(
                    label: 'Simulate Link via QR',
                    gradientColors: [
                      AppColors.whatsapp,
                      AppColors.whatsapp,
                    ],
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
