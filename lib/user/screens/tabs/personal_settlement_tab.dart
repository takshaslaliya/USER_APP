import 'dart:async';
import 'package:flutter/material.dart';
import 'package:splitease_test/core/services/auth_service.dart';
import 'package:splitease_test/core/services/group_service.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/core/services/whatsapp_service.dart';
import 'package:splitease_test/shared/utils/notification_helper.dart';
import 'package:provider/provider.dart';
import 'package:splitease_test/core/providers/data_refresh_provider.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Data models
// ──────────────────────────────────────────────────────────────────────────────

class PersonSettlement {
  final List<String> ids;
  final String name;
  final String? phone;
  final double toReceive;
  final double toSend;
  final double netAmount;
  final String status; // "Takes" or "Gives"
  final List<SettlementGroupDetail> details;

  PersonSettlement({
    required this.ids,
    required this.name,
    this.phone,
    required this.toReceive,
    required this.toSend,
    required this.netAmount,
    required this.status,
    required this.details,
  });

  factory PersonSettlement.fromJson(Map<String, dynamic> json) {
    final idStr = json['id']?.toString() ?? '';
    return PersonSettlement(
      ids: idStr.isNotEmpty ? [idStr] : [],
      name: json['name']?.toString() ?? 'Unknown User',
      phone: json['phone']?.toString(),
      toReceive: (json['to_receive'] ?? 0).toDouble(),
      toSend: (json['to_send'] ?? 0).toDouble(),
      netAmount: (json['net_total'] ?? 0).toDouble(),
      status:
          json['status']?.toString() ??
          (json['net_total'] >= 0 ? 'Takes' : 'Gives'),
      details: (json['details'] as List? ?? [])
          .map((d) => SettlementGroupDetail.fromJson(d))
          .toList(),
    );
  }
}

class SettlementGroupDetail {
  final String name;
  final double amount;
  final String? transactionId;
  final String? subGroupId; // Optional mapping
  final String? memberId; // Optional mapping

  SettlementGroupDetail({
    required this.name,
    required this.amount,
    this.transactionId,
    this.subGroupId,
    this.memberId,
  });

  factory SettlementGroupDetail.fromJson(Map<String, dynamic> json) {
    // If transaction_id contains an underscore, it might be subGroupId_memberId
    String? sgId, mId;
    final txId = json['transaction_id']?.toString();
    if (txId != null && txId.contains('_')) {
      final parts = txId.split('_');
      sgId = parts[0];
      mId = parts[1];
    }

    return SettlementGroupDetail(
      name: json['name']?.toString() ?? 'Expense',
      amount: (json['amount'] ?? 0).toDouble(),
      transactionId: txId,
      subGroupId: sgId,
      memberId: mId,
    );
  }

  bool get youOwe => amount < 0;
  double get absAmount => amount.abs();
}

// ──────────────────────────────────────────────────────────────────────────────
// Widget
// ──────────────────────────────────────────────────────────────────────────────

class PersonalSettlementTab extends StatefulWidget {
  const PersonalSettlementTab({super.key});

  @override
  State<PersonalSettlementTab> createState() => _PersonalSettlementTabState();
}

class _PersonalSettlementTabState extends State<PersonalSettlementTab> {
  List<PersonSettlement> _settlements = [];
  bool _isLoading = false;
  final Map<String, Timer?> _settleTimers = {};
  final Map<String, int> _countdownValues = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Handle global refresh signal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DataRefreshProvider>().addListener(_loadData);
      }
    });

    // Start polling every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _loadData(isPolling: true);
      }
    });
  }

  @override
  void dispose() {
    for (var timer in _settleTimers.values) {
      timer?.cancel();
    }
    _refreshTimer?.cancel();
    try {
      context.read<DataRefreshProvider>().removeListener(_loadData);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadData({bool isPolling = false}) async {
    if (isPolling && _isLoading) return;
    if (!isPolling) setState(() => _isLoading = true);
    await _buildSettlements();
    if (mounted && !isPolling) setState(() => _isLoading = false);
  }

  Future<void> _buildSettlements() async {
    final result = await GroupService.fetchSettlements();

    if (result.success && result.data != null) {
      final List<dynamic> data = result.data;
      final rawSettlements = data
          .map((json) => PersonSettlement.fromJson(json))
          .toList();

      // Consolidate duplicates by name + phone
      final Map<String, PersonSettlement> grouped = {};
      for (var s in rawSettlements) {
        final key = s.name.toLowerCase().trim();
        if (grouped.containsKey(key)) {
          final existing = grouped[key]!;
          final mergedToReceive = existing.toReceive + s.toReceive;
          final mergedToSend = existing.toSend + s.toSend;
          final mergedNet = mergedToReceive - mergedToSend;

          grouped[key] = PersonSettlement(
            ids: {...existing.ids, ...s.ids}.toList(),
            name: existing.name,
            phone: existing.phone ?? s.phone,
            toReceive: mergedToReceive,
            toSend: mergedToSend,
            netAmount: mergedNet,
            status: mergedNet >= 0 ? 'Takes' : 'Gives',
            details: [...existing.details, ...s.details],
          );
        } else {
          grouped[key] = s;
        }
      }

      if (mounted) setState(() => _settlements = grouped.values.toList());
    } else {
      if (mounted) setState(() => _settlements = []);
    }
  }

  Future<void> _sendNotification(PersonSettlement s) async {
    if (s.ids.isEmpty) return;

    setState(() => _isLoading = true);

    // Notify for the first transaction ID found (representative of the debt)
    // with the absolute net amount we owe.
    final res = await AuthService.notifyPaid(
      id: s.ids.first,
      amount: s.netAmount.abs(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res.success) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Notification Sent'),
            content: Text(res.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        NotificationHelper.showError(context, res.message);
      }
    }
  }

  void _startSettlementTimer(PersonSettlement s) {
    final String timerKey = s.ids.join(',');
    if (_settleTimers[timerKey] != null) return;

    setState(() {
      _countdownValues[timerKey] = 10;
    });

    _settleTimers[timerKey] = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdownValues[timerKey] = (_countdownValues[timerKey] ?? 10) - 1;
      });

      if (_countdownValues[timerKey] == 0) {
        timer.cancel();
        _settleTimers[timerKey] = null;
        await _performActualSettle(s);
      }
    });

    // Removed notification for starting timer as per user request
    /*
    NotificationHelper.showInfo(
      context,
      'Settling with ${s.name} in 10 seconds...',
    );
    */
  }

  Future<void> _sendWhatsAppReminder(
    PersonSettlement s, {
    String? customMessage,
  }) async {
    if (s.phone == null || s.phone!.isEmpty) {
      NotificationHelper.showError(
        context,
        'No phone number found for ${s.name}',
      );
      return;
    }

    setState(() => _isLoading = true);

    final currentUser = await AuthService.getUser();
    final myPhone = currentUser?['mobile_number']?.toString();

    if (myPhone == null) {
      setState(() => _isLoading = false);
      NotificationHelper.showError(
        context,
        'Could not determine your phone number to send as creditor',
      );
      return;
    }

    final res = await WhatsAppService.sendPayment(
      requests: [
        {
          'phone_number': s.phone,
          'name': s.name,
          'amount': s.toReceive,
          'creditor_phone': myPhone,
        },
      ],
      message:
          customMessage ??
          'Hi %name%, this is a reminder from SplitEase. Please pay ₹%amount% for our recent shared expenses. Thank you!',
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res.success) {
        NotificationHelper.showSuccess(
          context,
          'WhatsApp reminder sent to ${s.name}',
        );
      } else {
        NotificationHelper.showError(context, res.message);
      }
    }
  }

  Future<void> _showReminderMessageDialog(PersonSettlement s) async {
    final messageController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? AppColors.darkText : AppColors.lightText;
        final surfaceColor = isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface;

        return AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Custom Reminder',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Build your message using the buttons below:',
                style: TextStyle(
                  color: textColor.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _tokenButton(
                    label: 'Name',
                    token: '%name%',
                    controller: messageController,
                    context: context,
                  ),
                  const SizedBox(width: 8),
                  _tokenButton(
                    label: 'Amount',
                    token: '%amount%',
                    controller: messageController,
                    context: context,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 4,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'e.g. Hi %name%, please pay ₹%amount%...',
                  hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
                  filled: true,
                  fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: textColor)),
            ),
            ElevatedButton(
              onPressed: () {
                final customMsg = messageController.text.trim();
                Navigator.pop(context);
                _sendWhatsAppReminder(
                  s,
                  customMessage: customMsg.isNotEmpty ? customMsg : null,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.whatsapp,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Send',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tokenButton({
    required String label,
    required String token,
    required TextEditingController controller,
    required BuildContext context,
  }) {
    return InkWell(
      onTap: () {
        final text = controller.text;
        final selection = controller.selection;
        final start = selection.start == -1 ? text.length : selection.start;
        final end = selection.end == -1 ? text.length : selection.end;
        final newText = text.replaceRange(start, end, token);
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: start + token.length),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _cancelSettlementTimer(PersonSettlement s) {
    final String timerKey = s.ids.join(',');
    if (_settleTimers[timerKey] != null) {
      _settleTimers[timerKey]!.cancel();
      setState(() {
        _settleTimers[timerKey] = null;
        _countdownValues.remove(timerKey);
      });
      NotificationHelper.showInfo(
        context,
        'Settlement with ${s.name} cancelled',
      );
    }
  }

  Future<void> _performActualSettle(PersonSettlement s) async {
    setState(() => _isLoading = true);

    // Call settlement for ALL associated IDs
    bool anySuccess = false;
    for (var id in s.ids) {
      final res = await AuthService.settleTransactions(id);
      if (res.success) anySuccess = true;
    }

    await _loadData();
    if (mounted) {
      context.read<DataRefreshProvider>().signalRefresh();
      setState(() {
        _isLoading = false;
        _countdownValues.remove(s.ids.join(','));
      });
      if (anySuccess) {
        NotificationHelper.showSuccess(context, 'Settled with ${s.name}');
      }
    }
  }

  void _showGroupDetails(PersonSettlement s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Settlement Details: ${s.name}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: s.details.length,
                itemBuilder: (ctx, i) {
                  final g = s.details[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          g.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        Text(
                          '${g.amount < 0 ? '-' : '+'}₹${g.absAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: g.amount < 0 ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          'Personal Settlement',
          style: TextStyle(
            color: isDark ? AppColors.darkText : AppColors.lightText,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
              itemCount: _settlements.length,
              itemBuilder: (context, index) {
                final s = _settlements[index];
                return _buildSettlementCard(s, isDark);
              },
            ),
    );
  }

  Widget _buildSettlementCard(PersonSettlement s, bool isDark) {
    final String timerKey = s.ids.join(',');
    final bool isTimerRunning = _settleTimers[timerKey] != null;
    final int countdown = _countdownValues[timerKey] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Text(
                    s.name[0].toUpperCase(),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (s.toReceive > 0.01)
                            Text(
                              'Takes ₹${s.toReceive.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (s.toReceive > 0.01 && s.toSend > 0.01)
                            Text(
                              ' • ',
                              style: TextStyle(
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                            ),
                          if (s.toSend > 0.01)
                            Text(
                              'Gives ₹${s.toSend.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAmountInfo(
                      'To Receive',
                      s.toReceive,
                      Colors.green,
                      isDark,
                    ),
                    _buildAmountInfo('To Send', s.toSend, Colors.red, isDark),
                    _buildAmountInfo(
                      'Net Total',
                      s.netAmount,
                      s.netAmount < -0.01
                          ? Colors.red
                          : (s.netAmount > 0.01
                                ? Colors.green
                                : AppColors.primary),
                      isDark,
                      isBold: true,
                      showSign: true,
                    ),
                  ],
                ),
                if (!isTimerRunning) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // View Settle button - Always visible
                      Expanded(
                        child: _buildSecondaryButton(
                          label: 'View Settle',
                          onTap: () => _showGroupDetails(s),
                          isDark: isDark,
                        ),
                      ),

                      // Settle Instantly - Only show if current user is a net debtor
                      if (s.netAmount < -0.01) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _sendNotification(s),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 0,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Settle Instantly',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Paid button - Only show if they owe us money
                      if (s.toReceive > 0.01) ...[
                        const SizedBox(width: 8),
                        _buildActionButton(
                          label: 'Paid',
                          color: Colors.green,
                          onTap: () => _startSettlementTimer(s),
                          isActive: true,
                        ),
                        const SizedBox(width: 8),
                        // WhatsApp Reminder button
                        InkWell(
                          onTap: (s.phone != null && s.phone!.isNotEmpty)
                              ? () => _showReminderMessageDialog(s)
                              : () => NotificationHelper.showInfo(
                                  context,
                                  'No phone number available',
                                ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (s.phone != null && s.phone!.isNotEmpty)
                                  ? AppColors.whatsapp.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (s.phone != null && s.phone!.isNotEmpty)
                                    ? AppColors.whatsapp.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 20,
                              color: (s.phone != null && s.phone!.isNotEmpty)
                                  ? AppColors.whatsapp
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // View Settle button
                      Expanded(
                        child: _buildSecondaryButton(
                          label: 'View Settle ($countdown s)',
                          onTap: () => _showGroupDetails(s),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Undo button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _cancelSettlementTimer(s),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error.withOpacity(0.1),
                            elevation: 0,
                            foregroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: AppColors.error.withOpacity(0.3),
                              ),
                            ),
                          ),
                          child: const Text(
                            'Undo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        elevation: 0,
        foregroundColor: isDark ? Colors.white70 : Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 1,
          ),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAmountInfo(
    String label,
    double amount,
    Color color,
    bool isDark, {
    bool isBold = false,
    bool showSign = false,
  }) {
    final String displayAmount = amount.abs().toStringAsFixed(0);
    final String sign = showSign && amount < 0 ? '-' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : Colors.black38,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$sign₹$displayAmount',
          style: TextStyle(
            fontSize: 15,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: amount == 0
                ? (isDark ? Colors.white24 : Colors.black26)
                : color,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isActive = true,
  }) {
    return InkWell(
      onTap: isActive ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? color.withOpacity(0.3)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? color : Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
