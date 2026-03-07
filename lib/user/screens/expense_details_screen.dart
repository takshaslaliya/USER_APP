import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitease_test/core/models/expense_model.dart';
import 'package:splitease_test/core/models/group_model.dart';
import 'package:splitease_test/core/services/group_service.dart';
import 'package:splitease_test/core/services/auth_service.dart';
import 'package:splitease_test/core/services/whatsapp_service.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:splitease_test/core/providers/data_refresh_provider.dart';
import 'package:splitease_test/shared/utils/notification_helper.dart';

class ExpenseDetailsScreen extends StatefulWidget {
  final GroupModel group;
  final ExpenseModel expense;

  const ExpenseDetailsScreen({
    super.key,
    required this.group,
    required this.expense,
  });

  @override
  State<ExpenseDetailsScreen> createState() => _ExpenseDetailsScreenState();
}

class _ExpenseDetailsScreenState extends State<ExpenseDetailsScreen> {
  late ExpenseModel _expense;
  bool _isLoading = false;
  String? _currentUserId;
  final Set<String> _selectedMemberIds = {};
  final Map<String, String> _phoneToNameCache = {};

  @override
  void initState() {
    super.initState();
    _expense = widget.expense;
    _initUser();
    _refreshExpense();
  }

  Future<void> _initUser() async {
    final user = await AuthService.getUser();
    if (mounted) {
      setState(() => _currentUserId = user?['id']?.toString());
    }
  }

  Future<void> _refreshExpense() async {
    setState(() => _isLoading = true);

    GroupResult res;
    if (_expense.splitType == 'multiple' || _expense.splitType == 'solo') {
      res = await GroupService.fetchSplitDetails(_expense.id);
    } else {
      res = await GroupService.fetchGroupDetails(widget.group.id);
    }

    if (mounted) {
      if (res.success && res.data != null) {
        // If we got data back, check if we need to resolve names
        final data = res.data;
        final txs = data['transactions'] as List<dynamic>? ?? [];
        if (txs.isNotEmpty) {
          for (var tx in txs) {
            if (tx['from'] != null)
              await _getNameFromPhone(tx['from'].toString());
            if (tx['to'] != null) await _getNameFromPhone(tx['to'].toString());
          }
        }

        // Also resolve members if available
        final members = data['members'] as List<dynamic>? ?? [];
        for (var m in members) {
          await _getNameFromPhone(m.toString());
        }

        // Also resolve payers
        final payments = data['payments'] as Map<String, dynamic>? ?? {};
        for (var p in payments.keys) {
          await _getNameFromPhone(p);
        }

        setState(() {
          _isLoading = false;
          // Use fetchSplitDetails logic if the response has the split-style structure
          if (data['transactions'] != null || data['type'] != null) {
            _expense = _parseExpenseFromData(data);
          } else {
            // Find the specific sub-group in the group details
            final group = GroupModel.fromJson(data);
            try {
              _expense = group.expenses.firstWhere((e) => e.id == _expense.id);

              // Fallback for minimal solo sub-groups: split equally among group members
              if (_expense.splits.isEmpty && _expense.splitType == 'solo') {
                // Find payer (default to group creator)
                final payer = group.members.firstWhere(
                  (m) => m.userId == group.creatorId,
                  orElse: () => group.members.first,
                );
                final double perPerson = group.members.isNotEmpty
                    ? _expense.amount / group.members.length
                    : 0;

                _expense = ExpenseModel(
                  id: _expense.id,
                  title: _expense.title,
                  amount: _expense.amount,
                  paidById: payer.userId ?? payer.id,
                  date: _expense.date,
                  splitType: 'solo',
                  memberCount: group.members.length,
                  mainGroupName: group.name,
                  splits: group.members.map((m) {
                    final isPayer = m.id == payer.id;
                    return MemberSplit(
                      id: m.id,
                      name: m.phoneNumber ?? m.name,
                      amount: perPerson,
                      isPaid: isPayer,
                      phoneNumber: m.phoneNumber,
                    );
                  }).toList(),
                );
              }
            } catch (e) {
              // Not found in this group?
            }
          }
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String> _getNameFromPhone(String phone) async {
    if (_phoneToNameCache.containsKey(phone)) return _phoneToNameCache[phone]!;

    // Normalize
    String normalized = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (normalized.startsWith('+')) normalized = normalized.substring(1);
    if (!normalized.startsWith('91') && normalized.length == 10) {
      normalized = '91$normalized';
    }

    // Check group members
    for (var m in widget.group.members) {
      final p = m.phoneNumber ?? '';
      String pn = p.replaceAll(RegExp(r'[\s\-()]'), '');
      if (pn.startsWith('+')) pn = pn.substring(1);
      if (!pn.startsWith('91') && pn.length == 10) pn = '91$pn';

      if (pn == normalized) {
        _phoneToNameCache[phone] = m.name;
        return m.name;
      }
    }

    // Call API fallback
    final res = await AuthService.getMemberName(normalized);
    if (res.success && res.data != null) {
      final name = res.data!['name'] as String? ?? phone;
      _phoneToNameCache[phone] = name;
      return name;
    }

    return phone;
  }

  ExpenseModel _parseExpenseFromData(Map<String, dynamic> sg) {
    final String sgName = sg['expense_name'] ?? sg['name'] ?? 'Split Details';
    final double sgAmount = (sg['total_amount'] ?? sg['total_expense'] ?? 0.0)
        .toDouble();

    final String sgSplitType = sg['type'] ?? sg['split_type'] ?? 'solo';

    // Resolve the actual phone number/ID of the payer for solo splits
    String? payerPhone;
    if (sgSplitType == 'solo') {
      final Map<String, dynamic> payments = Map<String, dynamic>.from(
        sg['payments'] as Map? ?? {},
      );
      payerPhone = payments.keys.isNotEmpty
          ? payments.keys.first.toString()
          : (sg['paid_by']?.toString());
    }

    List<MemberSplit> splits = [];
    if (sg['transactions'] != null && sg['transactions'] is List) {
      splits = (sg['transactions'] as List).map((tx) {
        final fromPhone = tx['from']?.toString() ?? '';
        final toPhone = tx['to']?.toString() ?? '';
        return MemberSplit(
          id: tx['member_id']?.toString() ?? tx['id']?.toString() ?? fromPhone,
          name: tx['from_name']?.toString() ?? fromPhone,
          amount: (tx['amount'] ?? 0.0).toDouble(),
          isPaid: tx['is_paid'] ?? false,
          toId: sgSplitType == 'multiple' ? toPhone : null,
          toName: sgSplitType == 'multiple'
              ? (tx['to_name']?.toString() ?? toPhone)
              : null,
          phoneNumber: fromPhone,
        );
      }).toList();

      if (sgSplitType == 'solo') {
        final Map<String, dynamic> payments = Map<String, dynamic>.from(
          sg['payments'] as Map? ?? {},
        );
        final String rawPayer = payments.keys.isNotEmpty
            ? payments.keys.first.toString()
            : (sg['paid_by']?.toString() ?? 'Payer');
        final String firstPayer = rawPayer.replaceAll(RegExp(r'[^0-9]'), '');

        // Check if payer is in splits, if not add them with remaining amount
        // Check if payer is in splits, if not add them with remaining amount
        final normFirstPayer = firstPayer.replaceAll(RegExp(r'[^0-9]'), '');

        int payerIdx = splits.indexWhere((s) {
          final sPhone = s.phoneNumber?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
          return s.id == firstPayer ||
              s.name == firstPayer ||
              (sPhone.isNotEmpty && sPhone == normFirstPayer);
        });

        if (payerIdx == -1) {
          double totalOwedByOthers = 0;
          for (var s in splits) {
            totalOwedByOthers += s.amount;
          }
          final payerShare = sgAmount - totalOwedByOthers;
          splits.add(
            MemberSplit(
              id: firstPayer,
              name: _phoneToNameCache[firstPayer] ?? firstPayer,
              amount: payerShare > 0 ? payerShare : 0,
              isPaid: true,
              phoneNumber: firstPayer,
            ),
          );
        } else {
          // If payer IS in splits, ensure marked as paid
          double totalOwedByOthers = 0;
          for (int i = 0; i < splits.length; i++) {
            if (i != payerIdx) totalOwedByOthers += splits[i].amount;
          }
          final payerShare = sgAmount - totalOwedByOthers;

          splits[payerIdx] = MemberSplit(
            id: splits[payerIdx].id,
            name: splits[payerIdx].name,
            amount: (splits[payerIdx].amount == 0 && payerShare > 0)
                ? payerShare
                : splits[payerIdx].amount,
            isPaid: true,
            toId: splits[payerIdx].toId,
            toName: splits[payerIdx].toName,
            phoneNumber: splits[payerIdx].phoneNumber ?? firstPayer,
          );
        }
      }
    } else if (sg['members'] != null && sg['members'] is List) {
      if (sg['members'].isNotEmpty && sg['members'].first is Map) {
        splits = (sg['members'] as List).map((m) {
          final amt = (m['expense_amount'] ?? 0.0).toDouble();
          final isPayer =
              m['is_paid'] == true ||
              amt == 0; // Heuristic for payer if not explicitly marked

          return MemberSplit(
            id:
                m['member_id']?.toString() ??
                m['id']?.toString() ??
                m['phone_number']?.toString() ??
                '',
            name: m['name']?.toString() ?? 'Unknown',
            amount: (sgSplitType == 'solo' && amt == 0)
                ? (sgAmount / (sg['members'] as List).length)
                : amt,
            isPaid: isPayer,
            phoneNumber: m['phone_number']?.toString(),
          );
        }).toList();
      } else {
        // List of strings (phone numbers)
        final Map<String, dynamic> payments = Map<String, dynamic>.from(
          sg['payments'] as Map? ?? {},
        );
        final String rawPayer = payments.keys.isNotEmpty
            ? payments.keys.first.toString()
            : (sg['paid_by']?.toString() ?? 'Payer');
        final String firstPayer = rawPayer.replaceAll(RegExp(r'[^0-9]'), '');

        final double total = (sg['total_amount'] ?? 0.0).toDouble();

        // Ensure payer is counted in division
        List<String> allPhones = List<String>.from(sg['members']);
        bool payerWasInMembers = false;
        for (int i = 0; i < allPhones.length; i++) {
          if (allPhones[i].replaceAll(RegExp(r'[^0-9]'), '') == firstPayer) {
            payerWasInMembers = true;
            break;
          }
        }
        if (!payerWasInMembers) {
          allPhones.add(rawPayer);
        }

        final double perPerson = allPhones.isNotEmpty
            ? total / allPhones.length
            : 0.0;

        splits = allPhones.map((phone) {
          final isPayer = phone.replaceAll(RegExp(r'[^0-9]'), '') == firstPayer;
          return MemberSplit(
            id: phone,
            name: _phoneToNameCache[phone] ?? phone,
            amount: perPerson,
            isPaid: isPayer,
            phoneNumber: phone,
          );
        }).toList();
      }
    }

    return ExpenseModel(
      id: sg['id']?.toString() ?? sg['sub_group_id']?.toString() ?? _expense.id,
      title: sgName,
      amount: sgAmount,
      paidById: payerPhone ?? (sg['created_by']?.toString() ?? 'unknown'),
      date: sg['created_at'] != null
          ? DateTime.tryParse(sg['created_at']) ?? DateTime.now()
          : DateTime.now(),
      splits: splits,
      splitType:
          sg['type'] ??
          sg['split_type'] ??
          'multiple', // We only call this for multiple or new format
      memberCount:
          (sg['total_member'] ?? sg['member_count'] ?? splits.length) as int,
      mainGroupName: sg['main_group_name']?.toString(),
    );
  }

  Future<void> _togglePaid(MemberSplit split) async {
    setState(() => _isLoading = true);
    final res = await GroupService.updateSplitTransaction(
      split.id,
      isPaid: !split.isPaid,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res.success) {
        context.read<DataRefreshProvider>().signalRefresh();
        _refreshExpense();
      } else {
        NotificationHelper.showError(context, res.message);
      }
    }
  }

  Future<void> _showReminderMessageDialog() async {
    if (_selectedMemberIds.isEmpty) {
      NotificationHelper.showInfo(context, 'Please select at least one member');
      return;
    }

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
                  color: textColor.withValues(alpha: 0.7),
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
                  hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
                _sendReminders(
                  customMessage: customMsg.isNotEmpty ? customMsg : null,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.whatsapp,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Send', style: TextStyle(color: Colors.white)),
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
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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

  Future<void> _sendReminders({String? customMessage}) async {
    if (_selectedMemberIds.isEmpty) {
      NotificationHelper.showInfo(context, 'Please select at least one member');
      return;
    }

    setState(() => _isLoading = true);

    final List<Map<String, dynamic>> requests = [];
    for (var memberId in _selectedMemberIds) {
      final split = _expense.splits.firstWhere((s) => s.id == memberId);
      String? phoneNumber = split.phoneNumber;

      // 1. Fallback: Check if the ID itself looks like a phone number
      if (phoneNumber == null &&
          memberId.length >= 10 &&
          RegExp(r'^[0-9]+$').hasMatch(memberId)) {
        phoneNumber = memberId;
      }

      // 2. Fallback: Try finding in group members
      if (phoneNumber == null) {
        try {
          final groupMember = widget.group.members.firstWhere(
            (m) =>
                m.name == split.name ||
                (m.phoneNumber != null && m.phoneNumber == memberId) ||
                (m.phoneNumber != null && m.phoneNumber == split.name),
          );
          phoneNumber = groupMember.phoneNumber;
        } catch (e) {
          // Skip if not found
        }
      }

      // 3. Fallback: check if split.name itself is a phone number
      if (phoneNumber == null &&
          split.name.length >= 10 &&
          RegExp(r'^[0-9]+$').hasMatch(split.name)) {
        phoneNumber = split.name;
      }

      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        // Resolve the best possible name (avoid sending phone number in name field)
        String displayName = split.name;

        // If split.name is a phone number, try to find a real name
        if (RegExp(r'^[0-9]+$').hasMatch(displayName)) {
          try {
            final m = widget.group.members.firstWhere(
              (m) => m.phoneNumber == phoneNumber || m.phoneNumber == memberId,
            );
            displayName = m.name;
          } catch (_) {
            displayName = _phoneToNameCache[phoneNumber] ?? displayName;
          }
        }

        // Determine creditor phone
        String? creditorPhone = (_expense.splitType == 'solo')
            ? _expense.paidById
            : split.toId;

        // If creditorPhone is not a pure phone number, try to resolve it from group members
        if (creditorPhone != null &&
            !RegExp(r'^[0-9]+$').hasMatch(creditorPhone)) {
          try {
            final m = widget.group.members.firstWhere(
              (m) => m.userId == creditorPhone || m.id == creditorPhone,
            );
            if (m.phoneNumber != null && m.phoneNumber!.isNotEmpty) {
              creditorPhone = m.phoneNumber;
            }
          } catch (_) {
            // If not found in members, just use digits from the original string
          }
        }

        // Ensure creditor phone is just digits
        if (creditorPhone != null) {
          creditorPhone = creditorPhone.replaceAll(RegExp(r'[^0-9]'), '');
        }

        if (creditorPhone != null && creditorPhone.isNotEmpty) {
          requests.add({
            'phone_number': phoneNumber,
            'name': displayName,
            'amount': split.amount,
            'creditor_phone': creditorPhone,
          });
        }
      }
    }

    if (requests.isEmpty) {
      setState(() => _isLoading = false);
      NotificationHelper.showError(
        context,
        'No valid phone numbers found for selected members',
      );
      return;
    }

    String finalMessage;
    if (customMessage != null) {
      finalMessage =
          '${customMessage.replaceAll('\n\nThank you!', '')}\n\nThank you!';
    } else {
      finalMessage =
          'Hi %name%, here is a reminder for %creditor%. Please pay ₹%amount% using the QR code below. Thank you!';
    }

    final res = await WhatsAppService.sendPayment(
      requests: requests,
      message: finalMessage,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res.success) {
        setState(() => _selectedMemberIds.clear());
        NotificationHelper.showSuccess(context, 'Reminders sent successfully!');
      } else {
        NotificationHelper.showError(context, res.message);
      }
    }
  }

  Future<void> _showEditMemberExpenseDialog(MemberSplit split) async {
    final nameController = TextEditingController(text: split.name);
    final amountController = TextEditingController(
      text: split.amount.toStringAsFixed(0),
    );

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
          title: Text(
            'Edit Member Expense',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                inputFormatters: [LengthLimitingTextInputFormatter(25)],
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: AppColors.primary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
                style: TextStyle(color: textColor),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [LengthLimitingTextInputFormatter(7)],
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  labelStyle: TextStyle(color: AppColors.primary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
                style: TextStyle(color: textColor),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: textColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                final newAmount = double.tryParse(amountController.text) ?? 0;
                Navigator.pop(context);

                setState(() => _isLoading = true);
                final messenger = ScaffoldMessenger.of(context);
                final res = await GroupService.updateMemberExpense(
                  _expense.id, // This is the subGroupId
                  split.id,
                  newName,
                  newAmount,
                );

                if (mounted) {
                  setState(() => _isLoading = false);
                  if (res.success) {
                    _refreshExpense();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(res.message),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(res.message),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    final isCreator = widget.group.creatorId == _currentUserId;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          _expense.title,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : null,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          if (widget.group.creatorId == _currentUserId ||
              _expense.paidById == _currentUserId ||
              _expense.paidById == 'me')
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: AppColors.error),
              tooltip: 'Delete Split',
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                final screenContext = context;
                showDialog(
                  context: screenContext,
                  builder: (dialogContext) => AlertDialog(
                    backgroundColor: surfaceColor,
                    title: Text(
                      'Delete Expense Group?',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Text(
                      'Are you sure you want to delete "${_expense.title}"? This will remove all associated splits and cannot be undone.',
                      style: TextStyle(color: subColor),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: textColor),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext); // Close dialog
                          setState(() => _isLoading = true);
                          final res = await GroupService.deleteSplit(
                            _expense.id,
                          );

                          if (mounted) {
                            setState(() => _isLoading = false);
                            if (res.success) {
                              if (!screenContext.mounted) return;
                              Navigator.pop(
                                screenContext,
                                true,
                              ); // Go back with success
                              messenger.showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Expense group deleted successfully',
                                  ),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(res.message),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppColors.primaryGradient),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Total Expense',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '₹${_expense.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${_expense.date.day}/${_expense.date.month}/${_expense.date.year}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),

            // Split Details Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Split Breakdown ${_selectedMemberIds.isNotEmpty ? "(${_selectedMemberIds.length} selected)" : ""}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      final unpaidIds = _expense.splits
                          .where((s) => !s.isPaid)
                          .map((s) => s.id)
                          .toList();
                      if (_selectedMemberIds.length == unpaidIds.length) {
                        _selectedMemberIds.clear();
                      } else {
                        _selectedMemberIds.clear();
                        _selectedMemberIds.addAll(unpaidIds);
                      }
                    });
                  },
                  child: Text(
                    _selectedMemberIds.length ==
                            _expense.splits.where((s) => !s.isPaid).length
                        ? 'Deselect All'
                        : 'Select All',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant,
                ),
              ),
              child: Column(
                children: () {
                  return _expense.splits.map((split) {
                    final memberName =
                        _phoneToNameCache[split.name] ?? split.name;
                    final amount = split.amount;
                    final isSelected = _selectedMemberIds.contains(split.id);

                    final initials = memberName.trim().isNotEmpty
                        ? memberName.trim().substring(0, 1).toUpperCase()
                        : '?';

                    final recipientName = split.toName != null
                        ? (_phoneToNameCache[split.toName!] ?? split.toName!)
                        : null;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          if (!split.isPaid)
                            Checkbox(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedMemberIds.add(split.id);
                                  } else {
                                    _selectedMemberIds.remove(split.id);
                                  }
                                });
                              },
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          if (recipientName == null) ...[
                            CircleAvatar(
                              backgroundColor: split.isPaid
                                  ? AppColors.paid.withValues(alpha: 0.1)
                                  : (isSelected
                                        ? AppColors.primary
                                        : AppColors.primary.withValues(
                                            alpha: 0.1,
                                          )),
                              child: split.isPaid
                                  ? Icon(
                                      Icons.check_rounded,
                                      color: AppColors.paid,
                                    )
                                  : (isSelected
                                        ? Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                          )
                                        : Text(
                                            initials,
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          )),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: recipientName == null
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        memberName,
                                        style: TextStyle(
                                          color: split.isPaid
                                              ? subColor
                                              : textColor,
                                          fontWeight: FontWeight.w600,
                                          decoration: split.isPaid
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                        overflow: TextOverflow.visible,
                                      ),
                                      if (split.isPaid)
                                        Text(
                                          'Money Received',
                                          style: TextStyle(
                                            color: AppColors.paid,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              memberName,
                                              style: TextStyle(
                                                color: split.isPaid
                                                    ? subColor
                                                    : AppColors.error,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                decoration: split.isPaid
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                            ),
                                            if (split.name != memberName)
                                              Text(
                                                split.name,
                                                style: TextStyle(
                                                  color: subColor,
                                                  fontSize: 9,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward_rounded,
                                          color: AppColors.primary,
                                          size: 14,
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              recipientName,
                                              textAlign: TextAlign.end,
                                              style: TextStyle(
                                                color: split.isPaid
                                                    ? subColor
                                                    : AppColors.paid,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                decoration: split.isPaid
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                            ),
                                            if (split.toName != recipientName &&
                                                split.toName != null)
                                              Text(
                                                split.toName!,
                                                textAlign: TextAlign.end,
                                                style: TextStyle(
                                                  color: subColor,
                                                  fontSize: 9,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '₹${amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: split.isPaid
                                    ? subColor
                                    : AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () => _togglePaid(split),
                            style: TextButton.styleFrom(
                              backgroundColor: split.isPaid
                                  ? AppColors.paid.withValues(alpha: 0.15)
                                  : AppColors.error.withValues(alpha: 0.15),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              minimumSize: const Size(40, 24),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: Text(
                              split.isPaid ? 'Paid' : 'Unpaid',
                              style: TextStyle(
                                color: split.isPaid
                                    ? AppColors.paid
                                    : AppColors.error,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isCreator) ...[
                            IconButton(
                              icon: Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              onPressed: () =>
                                  _showEditMemberExpenseDialog(split),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList();
                }(),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: _selectedMemberIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showReminderMessageDialog,
              backgroundColor: AppColors.whatsapp,
              icon: Icon(Icons.message_rounded, color: Colors.white),
              label: Text(
                'Send WhatsApp Reminder',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }
}
