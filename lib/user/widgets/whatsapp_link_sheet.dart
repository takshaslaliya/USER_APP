import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/core/services/whatsapp_service.dart';
import 'package:splitease_test/shared/widgets/app_button.dart';
import 'package:splitease_test/shared/utils/notification_helper.dart';
import 'package:provider/provider.dart';
import 'package:splitease_test/core/providers/data_refresh_provider.dart';

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
  bool _isLoading = false;
  String? _pairingCode;
  String? _qrBase64;
  String? _statusMessage;
  bool _isNumberEntered = false;
  Timer? _timer;
  final ValueNotifier<int> _timeLeftNotifier = ValueNotifier<int>(0);
  bool _isExpired = false;
  Uint8List? _qrBytes;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timeLeftNotifier.dispose();
    _tabController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    _timeLeftNotifier.value = seconds;
    setState(() {
      _isExpired = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeftNotifier.value > 0) {
        _timeLeftNotifier.value--;
      } else {
        _timer?.cancel();
        setState(() {
          _isExpired = true;
          _pairingCode = null;
          _qrBase64 = null;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _sendOtp() async {
    if (_phoneController.text.length < 10) {
      NotificationHelper.showError(
        context,
        'Please enter a valid mobile number first',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Requesting pairing code...';
    });

    final res = await WhatsAppService.connect(
      phoneNumber: _phoneController.text,
      type: 'otp',
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res.success && res.data != null) {
        setState(() {
          _otpSent = true;
          _pairingCode = res.data!['pairing_code'];
          _statusMessage = res.message;
        });
        _startTimer(90); // 1.5 minutes
      } else {
        NotificationHelper.showError(context, res.message);
      }
    }
  }

  Future<void> _getQrCode() async {
    if (_phoneController.text.length < 10) {
      NotificationHelper.showError(
        context,
        'Please enter a valid mobile number first',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Generating QR code...';
    });

    final res = await WhatsAppService.connect(
      phoneNumber: _phoneController.text,
      type: 'qr',
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res.success && res.data != null) {
        setState(() {
          _qrBase64 = res.data!['qr_code'];
          if (_qrBase64 != null) {
            _qrBytes = base64Decode(_qrBase64!.split(',').last);
          }
          _statusMessage = res.message;
        });
        _startTimer(60); // 1 minute
      } else {
        NotificationHelper.showError(context, res.message);
      }
    }
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    final res = await WhatsAppService.getStatus();
    if (mounted) {
      setState(() => _isLoading = false);
      if (res.success && res.data?['status'] == 'connected') {
        context.read<DataRefreshProvider>().signalRefresh();
        Navigator.pop(context, true);
      } else {
        NotificationHelper.showInfo(
          context,
          res.data?['message'] ?? 'Not yet connected',
        );
      }
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
            const SizedBox(height: 24),
            Text(
              'Link WhatsApp',
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isNumberEntered
                  ? 'Connect using your preferred method'
                  : 'Enter your mobile number to get started',
              style: TextStyle(color: subColor, fontSize: 14),
            ),
            const SizedBox(height: 20),

            if (!_isNumberEntered) ...[
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Enter Mobile Number',
                  hintStyle: TextStyle(color: subColor),
                  prefixIcon: Icon(
                    Icons.phone_rounded,
                    color: AppColors.whatsapp,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Continue',
                onPressed: () {
                  if (_phoneController.text.length >= 10) {
                    setState(() => _isNumberEntered = true);
                  } else {
                    NotificationHelper.showError(
                      context,
                      'Please enter a valid mobile number',
                    );
                  }
                },
              ),
            ] else ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.whatsapp.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.phone_rounded,
                          size: 16,
                          color: AppColors.whatsapp,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _phoneController.text,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() {
                      _isNumberEntered = false;
                      _otpSent = false;
                      _qrBase64 = null;
                      _pairingCode = null;
                      _timer?.cancel();
                      _timeLeftNotifier.value = 0;
                      _isExpired = false;
                    }),
                    icon: Icon(Icons.edit_rounded, size: 20, color: subColor),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildLinkOptions(isDark, subColor),
            ],
            // Extra space for system nav bar
            const SizedBox(height: 40),
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
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'OTP Code'),
            Tab(text: 'QR Scan'),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 420,
          child: TabBarView(
            controller: _tabController,
            children: [
              // OTP Flow
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_otpSent) ...[
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'Enter this code on your WhatsApp:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          if (_isExpired) ...[
                            Icon(
                              Icons.history_rounded,
                              size: 48,
                              color: AppColors.error,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Code Expired',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Please request a new pairing code',
                              style: TextStyle(color: subColor, fontSize: 12),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkBg
                                    : AppColors.lightBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.whatsapp),
                              ),
                              child: Text(
                                _pairingCode ?? '----',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                  color: AppColors.whatsapp,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ValueListenableBuilder<int>(
                              valueListenable: _timeLeftNotifier,
                              builder: (context, timeLeft, _) {
                                return Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.timer_outlined,
                                          size: 14,
                                          color: AppColors.whatsapp,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Expires in ${_formatTime(timeLeft)}',
                                          style: TextStyle(
                                            color: AppColors.whatsapp,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    TextButton(
                                      onPressed: (90 - timeLeft >= 10)
                                          ? _sendOtp
                                          : null,
                                      child: Text(
                                        (90 - timeLeft >= 10)
                                            ? 'Regenerate Code'
                                            : 'Regenerate in ${10 - (90 - timeLeft)}s',
                                        style: TextStyle(
                                          color: (90 - timeLeft >= 10)
                                              ? AppColors.primary
                                              : subColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _statusMessage ?? '',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: subColor, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else
                    Center(
                      child: Text(
                        'Request a pairing code to link via phone number directly in WhatsApp.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: subColor, fontSize: 13),
                      ),
                    ),
                  const Spacer(),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    AppButton(
                      label: _isExpired
                          ? 'Regenerate Code'
                          : (_otpSent
                                ? 'Check Connection'
                                : 'Get Pairing Code'),
                      icon: _isExpired
                          ? Icons.refresh_rounded
                          : (_otpSent
                                ? Icons.check_circle_outline_rounded
                                : Icons.phonelink_setup_rounded),
                      gradientColors: [AppColors.whatsapp, AppColors.whatsapp],
                      onPressed: (_otpSent && !_isExpired)
                          ? _checkStatus
                          : _sendOtp,
                    ),
                  const SizedBox(height: 24),
                ],
              ),
              // QR Flow
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Scan this QR code from your WhatsApp Linked Devices to connect.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subColor, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Center(
                      child: _isExpired
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_scanner_rounded,
                                  size: 64,
                                  color: isDark
                                      ? AppColors.darkSurfaceVariant
                                      : AppColors.lightSurfaceVariant,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'QR Expired',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Please regenerate to scan',
                                  style: TextStyle(
                                    color: subColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          : _qrBase64 != null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: _qrBytes != null
                                      ? Image.memory(
                                          _qrBytes!,
                                          width: 180,
                                          height: 180,
                                        )
                                      : const SizedBox(width: 180, height: 180),
                                ),
                                const SizedBox(height: 12),
                                ValueListenableBuilder<int>(
                                  valueListenable: _timeLeftNotifier,
                                  builder: (context, timeLeft, _) {
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.timer_outlined,
                                          size: 14,
                                          color: AppColors.whatsapp,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Expires in ${_formatTime(timeLeft)}',
                                          style: TextStyle(
                                            color: AppColors.whatsapp,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            )
                          : _isLoading
                          ? const CircularProgressIndicator()
                          : IconButton(
                              icon: const Icon(Icons.refresh_rounded, size: 48),
                              onPressed: _getQrCode,
                              color: AppColors.whatsapp,
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: _isExpired
                        ? 'Regenerate QR'
                        : (_qrBase64 != null ? 'Check Status' : 'Generate QR'),
                    icon: _isExpired ? Icons.refresh_rounded : null,
                    gradientColors: [AppColors.whatsapp, AppColors.whatsapp],
                    onPressed: (_qrBase64 != null && !_isExpired)
                        ? _checkStatus
                        : _getQrCode,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
