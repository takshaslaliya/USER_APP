import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitease_test/core/models/expense_model.dart';
import 'package:splitease_test/core/models/group_model.dart';
import 'package:splitease_test/core/services/group_service.dart';
import 'package:splitease_test/core/services/auth_service.dart';
import 'package:splitease_test/core/services/whatsapp_service.dart';
import 'package:splitease_test/core/theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _expense = widget.expense;
    _initUser();
  }

  Future<void> _initUser() async {
    final user = await AuthService.getUser();
    if (mounted) {
      setState(() => _currentUserId = user?['id']?.toString());
    }
  }

  Future<void> _refreshExpense() async {
    setState(() => _isLoading = true);
    final res = await GroupService.fetchSplitDetails(_expense.id);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          final sg = res.data;
          // Handle both old and new split formats
          final String sgName =
              sg['expense_name'] ?? sg['name'] ?? 'Split Details';
          final double sgAmount =
              (sg['total_amount'] ?? sg['total_expense'] ?? 0.0).toDouble();

          List<MemberSplit> splits = [];
          if (sg['transactions'] != null && sg['transactions'] is List) {
            splits = (sg['transactions'] as List).map((tx) {
              return MemberSplit(
                id: tx['id']?.toString() ?? tx['from']?.toString() ?? '',
                name:
                    tx['from_name']?.toString() ??
                    tx['from']?.toString() ??
                    'Unknown',
                amount: (tx['amount'] ?? 0.0).toDouble(),
                isPaid: tx['is_paid'] ?? false,
              );
            }).toList();
          } else if (sg['members'] != null &&
              sg['members'] is List &&
              sg['members'].first is Map) {
            splits = (sg['members'] as List).map((m) {
              return MemberSplit(
                id: m['id']?.toString() ?? '',
                name: m['name']?.toString() ?? 'Unknown',
                amount: (m['expense_amount'] ?? 0.0).toDouble(),
                isPaid: m['is_paid'] ?? false,
              );
            }).toList();
          }

          _expense = ExpenseModel(
            id: sg['id']?.toString() ?? _expense.id,
            title: sgName,
            amount: sgAmount,
            paidById: sg['created_by']?.toString() ?? 'unknown',
            date: sg['created_at'] != null
                ? DateTime.tryParse(sg['created_at']) ?? DateTime.now()
                : DateTime.now(),
            splits: splits,
          );
        }
      });
    }
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
        _refreshExpense();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _sendGroupReminder() async {
    setState(() => _isLoading = true);
    final res = await WhatsAppService.remindGroup(_expense.id);

    if (mounted) {
      setState(() => _isLoading = false);
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppColors.whatsapp,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showReminderMessageDialog() async {
    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final List<Map<String, String>> requests = [];
    for (var memberId in _selectedMemberIds) {
      final split = _expense.splits.firstWhere((s) => s.id == memberId);
      // We need the phone number. We get it from the group members
      try {
        final groupMember = widget.group.members.firstWhere(
          (m) => m.name == split.name,
        );
        if (groupMember.phoneNumber != null &&
            groupMember.phoneNumber!.isNotEmpty) {
          requests.add({
            'phone_number': groupMember.phoneNumber!,
            'name': split.name,
            'amount': split.amount.toStringAsFixed(0),
          });
        }
      } catch (e) {
        // Skip if not found
      }
    }

    if (requests.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid phone numbers found for selected members'),
        ),
      );
      return;
    }

    String finalMessage;
    if (customMessage != null) {
      finalMessage =
          customMessage.replaceAll('\n\nThank you!', '') + '\n\nThank you!';
    } else {
      finalMessage =
          'Hi %name%, this is a reminder to pay your share of ₹%amount% for "${_expense.title}". Thank you!';
    }

    final res = await WhatsAppService.sendPayment(
      requests: requests,
      message: finalMessage,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res.success) {
        setState(() => _selectedMemberIds.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Reminders sent successfully!'),
            backgroundColor: AppColors.whatsapp,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppColors.error,
          ),
        );
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
          IconButton(
            icon: Icon(Icons.forum_rounded, color: AppColors.whatsapp),
            tooltip: 'Remind Entire Group',
            onPressed: _sendGroupReminder,
          ),
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
                  // Merge duplicate members by name for this expense
                  final Map<String, MemberSplit> mergedSplits = {};
                  for (var split in _expense.splits) {
                    if (mergedSplits.containsKey(split.name)) {
                      final existing = mergedSplits[split.name]!;
                      mergedSplits[split.name] = MemberSplit(
                        id: split.id, // Keep latest ID
                        name: split.name,
                        amount: existing.amount + split.amount,
                        isPaid: split.isPaid,
                      );
                    } else {
                      mergedSplits[split.name] = split;
                    }
                  }

                  final uniqueSplits = mergedSplits.values.toList();

                  return uniqueSplits.map((split) {
                    final memberName = split.name;
                    final amount = split.amount;
                    final isSelected = _selectedMemberIds.contains(split.id);

                    final initials = memberName.trim().isNotEmpty
                        ? memberName.trim().substring(0, 1).toUpperCase()
                        : '?';

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
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
                          GestureDetector(
                            onTap: () {
                              if (!split.isPaid) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedMemberIds.remove(split.id);
                                  } else {
                                    _selectedMemberIds.add(split.id);
                                  }
                                });
                              }
                            },
                            child: CircleAvatar(
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
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  memberName,
                                  style: TextStyle(
                                    color: split.isPaid ? subColor : textColor,
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
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₹${amount.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: split.isPaid ? subColor : textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
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
