import 'dart:async';
import 'package:flutter/material.dart';
import 'package:splitease_test/core/models/group_model.dart';
import 'package:splitease_test/core/models/expense_model.dart';
import 'package:splitease_test/core/services/group_service.dart';
import 'package:splitease_test/core/services/auth_service.dart';
import 'package:splitease_test/core/theme/app_theme.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Data models
// ──────────────────────────────────────────────────────────────────────────────

class PersonSettlement {
  final String name;
  final String? phoneNumber;
  final String? userId;

  double youOweThem; // Current user owes this person
  double theyOweYou; // This person owes current user

  final List<SettlementGroupDetail> groups;
  final List<_SplitRef> allSplitRefs;

  PersonSettlement({
    required this.name,
    this.phoneNumber,
    this.userId,
    this.youOweThem = 0,
    this.theyOweYou = 0,
    required this.groups,
    required this.allSplitRefs,
  });

  double get netAmount => theyOweYou - youOweThem;
}

class SettlementGroupDetail {
  final String groupName;
  final double amount;
  final bool youOwe; // true if you owe the group, false if they owe you

  SettlementGroupDetail({
    required this.groupName,
    required this.amount,
    required this.youOwe,
  });
}

class _SplitRef {
  final String subGroupId;
  final String memberId;
  final bool isPaid;
  final double amount;
  const _SplitRef({
    required this.subGroupId,
    required this.memberId,
    required this.isPaid,
    required this.amount,
  });
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
  String? _currentUserId;
  String? _currentUserName;
  final Map<String, Timer?> _settleTimers = {};
  final Map<String, int> _countdownValues = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (var timer in _settleTimers.values) {
      timer?.cancel();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = await AuthService.getUser();
    if (!mounted) return;
    _currentUserId = user?['id']?.toString();
    _currentUserName = user?['name']?.toString() ?? 'You';
    await _buildSettlements();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _buildSettlements() async {
    // In a real app, we'd fetch from API.
    // For now, let's use the actual data from groups but also add SAMPLE DATA as requested.

    final results = await Future.wait([
      GroupService.fetchGroups(),
      GroupService.fetchSharedGroups(),
    ]);

    final allGroups = <GroupModel>[];
    for (final result in results) {
      if (result.success && result.data != null) {
        final List<dynamic> data = result.data;
        allGroups.addAll(data.map((g) => GroupModel.fromJson(g)));
      }
    }

    final Map<String, PersonSettlement> accumulator = {};

    // 1. Process real data
    for (final group in allGroups) {
      for (final expense in group.expenses) {
        _processExpense(group, expense, accumulator);
      }
    }

    // 2. Add Sample Data if empty (as requested)
    if (accumulator.isEmpty) {
      accumulator['sample_1'] = PersonSettlement(
        name: 'Harshil Suthar',
        theyOweYou: 1200,
        youOweThem: 450,
        groups: [
          SettlementGroupDetail(
            groupName: 'Dinner Party',
            amount: 800,
            youOwe: false,
          ),
          SettlementGroupDetail(groupName: 'Rent', amount: 400, youOwe: false),
          SettlementGroupDetail(
            groupName: 'Movie Night',
            amount: 450,
            youOwe: true,
          ),
        ],
        allSplitRefs: [],
      );
      accumulator['sample_2'] = PersonSettlement(
        name: 'Taksh Asalaliya',
        theyOweYou: 0,
        youOweThem: 600,
        groups: [
          SettlementGroupDetail(
            groupName: 'Travel Budget',
            amount: 600,
            youOwe: true,
          ),
        ],
        allSplitRefs: [],
      );
      accumulator['sample_3'] = PersonSettlement(
        name: 'Rudrabhai AVD',
        theyOweYou: 2500,
        youOweThem: 0,
        groups: [
          SettlementGroupDetail(groupName: 'Food', amount: 2500, youOwe: false),
        ],
        allSplitRefs: [],
      );
    }

    final settlements = accumulator.values.toList()
      ..sort(
        (a, b) => (b.theyOweYou + b.youOweThem).compareTo(
          a.theyOweYou + a.youOweThem,
        ),
      );

    if (mounted) setState(() => _settlements = settlements);
  }

  void _processExpense(
    GroupModel group,
    ExpenseModel expense,
    Map<String, PersonSettlement> acc,
  ) {
    if (expense.splits.isEmpty) return;

    final isCurUserPayer = expense.paidById == _currentUserId;

    if (isCurUserPayer) {
      for (final split in expense.splits) {
        if (split.isPaid) continue;
        final key = split.name.trim().toLowerCase();
        if (key == (_currentUserName?.toLowerCase() ?? '')) continue;

        acc.putIfAbsent(
          key,
          () =>
              PersonSettlement(name: split.name, groups: [], allSplitRefs: []),
        );

        acc[key]!.theyOweYou += split.amount;
        acc[key]!.groups.add(
          SettlementGroupDetail(
            groupName: group.name,
            amount: split.amount,
            youOwe: false,
          ),
        );
        acc[key]!.allSplitRefs.add(
          _SplitRef(
            subGroupId: expense.id,
            memberId: split.id,
            isPaid: split.isPaid,
            amount: split.amount,
          ),
        );
      }
    } else {
      final mySplit = expense.splits
          .where(
            (s) =>
                s.name.trim().toLowerCase() ==
                (_currentUserName?.toLowerCase() ?? ''),
          )
          .firstOrNull;
      if (mySplit != null && !mySplit.isPaid) {
        String payerName = 'Other';
        final payerMember = group.members
            .where(
              (m) => m.userId == expense.paidById || m.id == expense.paidById,
            )
            .firstOrNull;
        if (payerMember != null) payerName = payerMember.name;

        final key = payerName.trim().toLowerCase();
        acc.putIfAbsent(
          key,
          () => PersonSettlement(name: payerName, groups: [], allSplitRefs: []),
        );

        acc[key]!.youOweThem += mySplit.amount;
        acc[key]!.groups.add(
          SettlementGroupDetail(
            groupName: group.name,
            amount: mySplit.amount,
            youOwe: true,
          ),
        );
        acc[key]!.allSplitRefs.add(
          _SplitRef(
            subGroupId: expense.id,
            memberId: mySplit.id,
            isPaid: mySplit.isPaid,
            amount: mySplit.amount,
          ),
        );
      }
    }
  }

  void _sendNotification(PersonSettlement s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Notification Sent'),
        content: Text('A settlement reminder has been sent to ${s.name}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _startSettlementTimer(PersonSettlement s) {
    if (_settleTimers[s.name] != null) return;

    setState(() {
      _countdownValues[s.name] = 10;
    });

    _settleTimers[s.name] = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdownValues[s.name] = (_countdownValues[s.name] ?? 10) - 1;
      });

      if (_countdownValues[s.name] == 0) {
        timer.cancel();
        _settleTimers[s.name] = null;
        await _performActualSettle(s);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Settling with ${s.name} in 10 seconds...'),
        backgroundColor: AppColors.primary,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _settleTimers[s.name]?.cancel();
              _settleTimers[s.name] = null;
              _countdownValues.remove(s.name);
            });
          },
        ),
      ),
    );
  }

  Future<void> _performActualSettle(PersonSettlement s) async {
    setState(() => _isLoading = true);

    // In a real app, call API. For mocks, just reload or remove.
    if (s.allSplitRefs.isNotEmpty) {
      final futures = s.allSplitRefs.map(
        (r) =>
            GroupService.toggleMemberPaidStatus(r.subGroupId, r.memberId, true),
      );
      await Future.wait(futures);
    }

    await _loadData();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _countdownValues.remove(s.name);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Settled with ${s.name}')));
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
                itemCount: s.groups.length,
                itemBuilder: (ctx, i) {
                  final g = s.groups[i];
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
                          g.groupName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        Text(
                          '${g.youOwe ? '-' : '+'}₹${g.amount}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: g.youOwe ? Colors.red : Colors.green,
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
    final bool isTimerRunning = _settleTimers[s.name] != null;
    final int countdown = _countdownValues[s.name] ?? 0;

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
                          if (s.theyOweYou > 0)
                            Text(
                              'Takes ₹${s.theyOweYou}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (s.theyOweYou > 0 && s.youOweThem > 0)
                            Text(
                              ' • ',
                              style: TextStyle(
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                            ),
                          if (s.youOweThem > 0)
                            Text(
                              'Gives ₹${s.youOweThem}',
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
                      s.theyOweYou,
                      Colors.green,
                      isDark,
                    ),
                    _buildAmountInfo(
                      'To Send',
                      s.youOweThem,
                      Colors.red,
                      isDark,
                    ),
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
                      if (s.theyOweYou > 0) ...[
                        const SizedBox(width: 8),
                        _buildActionButton(
                          label: 'Paid',
                          color: Colors.green,
                          onTap: () => _startSettlementTimer(s),
                          isActive: true,
                        ),
                      ],
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Settling in $countdown seconds...',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
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
