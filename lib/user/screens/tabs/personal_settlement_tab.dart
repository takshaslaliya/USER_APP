import 'package:flutter/material.dart';
import 'package:splitease_test/core/models/group_model.dart';
import 'package:splitease_test/core/models/expense_model.dart';
import 'package:splitease_test/core/services/group_service.dart';
import 'package:splitease_test/core/services/auth_service.dart';
import 'package:splitease_test/core/theme/app_theme.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Data model for a net balance with one specific person
// ──────────────────────────────────────────────────────────────────────────────
class PersonSettlement {
  final String name;
  final String? phoneNumber;

  /// positive → current user owes this person
  /// negative → this person owes current user
  double netAmount;

  /// Flat list of (subGroupId, memberSplitId) belonging to this person
  /// across ALL groups, so we can mark them paid in bulk.
  final List<_SplitRef> splitRefs;

  PersonSettlement({
    required this.name,
    this.phoneNumber,
    required this.netAmount,
    required this.splitRefs,
  });

  bool get userOwes => netAmount > 0;
  bool get theyOwe => netAmount < 0;
  double get absAmount => netAmount.abs();
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

  @override
  void initState() {
    super.initState();
    _loadData();
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

  /// Fetch all groups (own + shared) and aggregate net balances per person.
  Future<void> _buildSettlements() async {
    // Fetch both in parallel
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

    // phone → PersonSettlement accumulator
    // Key: phone number (preferred) or lowercase name
    final Map<String, PersonSettlement> accumulator = {};

    for (final group in allGroups) {
      for (final expense in group.expenses) {
        _processExpense(group, expense, accumulator);
      }
    }

    final settlements =
        accumulator.values
            .where((s) => s.absAmount > 0.01) // ignore tiny rounding noise
            .toList()
          ..sort((a, b) => b.absAmount.compareTo(a.absAmount));

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
      // Current user paid. Everyone else in the splits owes the current user.
      for (final split in expense.splits) {
        if (split.isPaid) continue;

        final key = split.name.trim().toLowerCase();
        if (key == (_currentUserName?.toLowerCase() ?? '')) {
          continue; // Skip self
        }

        acc.putIfAbsent(
          key,
          () => PersonSettlement(name: split.name, netAmount: 0, splitRefs: []),
        );

        // They owe you -> negative
        acc[key]!.netAmount -= split.amount;
        acc[key]!.splitRefs.add(
          _SplitRef(
            subGroupId: expense.id,
            memberId: split.id,
            isPaid: split.isPaid,
            amount: split.amount,
          ),
        );
      }
    } else {
      // Someone else paid. Do we owe them?
      final mySplit = expense.splits.where((s) {
        return s.name.trim().toLowerCase() ==
            (_currentUserName?.toLowerCase() ?? '');
      }).firstOrNull;

      if (mySplit != null && !mySplit.isPaid) {
        // We owe the payer. Let's find their name.
        String payerName = 'Unknown User';
        final payerMember = group.members
            .where(
              (m) => m.userId == expense.paidById || m.id == expense.paidById,
            )
            .firstOrNull;

        if (payerMember != null) {
          payerName = payerMember.name;
        } else if (expense.paidById == group.creatorId) {
          final creatorMember = group.members
              .where((m) => m.userId == group.creatorId)
              .firstOrNull;
          if (creatorMember != null) {
            payerName = creatorMember.name;
          }
        }

        if (payerName == 'Unknown User' && expense.paidById.length > 4) {
          // Fallback UI string
          payerName = 'User (${expense.paidById.substring(0, 4)})';
        }

        final key = payerName.trim().toLowerCase();
        acc.putIfAbsent(
          key,
          () => PersonSettlement(name: payerName, netAmount: 0, splitRefs: []),
        );

        // You owe them -> positive
        acc[key]!.netAmount += mySplit.amount;

        // When we hit Settle, we are paying off OUR split, so the memberId is OUR split ID!
        acc[key]!.splitRefs.add(
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

  Future<void> _settle(PersonSettlement settlement) async {
    final confirmed = await _showConfirmDialog(settlement);
    if (!confirmed) return;

    setState(() => _isLoading = true);

    // Mark every unpaid split for this person as paid
    final futures = settlement.splitRefs
        .where((r) => !r.isPaid)
        .map(
          (r) => GroupService.toggleMemberPaidStatus(
            r.subGroupId,
            r.memberId,
            true,
          ),
        )
        .toList();

    await Future.wait(futures);
    await _buildSettlements();
    if (mounted) {
      setState(() => _isLoading = false);
      _showSuccessSnack(settlement);
    }
  }

  Future<bool> _showConfirmDialog(PersonSettlement s) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: isDark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Settle with ${s.name}',
              style: TextStyle(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.userOwes
                      ? 'You owe ${s.name} a net of ₹${s.absAmount.toStringAsFixed(2)}.'
                      : '${s.name} owes you a net of ₹${s.absAmount.toStringAsFixed(2)}.',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkSubtext
                        : AppColors.lightSubtext,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All ${s.splitRefs.where((r) => !r.isPaid).length} unpaid expense(s) with ${s.name} will be marked as paid.',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkSubtext
                        : AppColors.lightSubtext,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkSubtext
                        : AppColors.lightSubtext,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Settle Now'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccessSnack(PersonSettlement s) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Settled all expenses with ${s.name}!'),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            fontSize: 18,
            fontWeight: FontWeight.w700,
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
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: _settlements.isEmpty
                  ? _buildEmptyState(isDark)
                  : _buildSettlementList(isDark),
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.handshake_rounded,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'All settled up! 🎉',
              style: TextStyle(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'No outstanding balances across any of your groups.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkSubtext
                      : AppColors.lightSubtext,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementList(bool isDark) {
    // Totals
    final totalOwe = _settlements
        .where((s) => s.userOwes)
        .fold(0.0, (sum, s) => sum + s.absAmount);
    final totalOwed = _settlements
        .where((s) => s.theyOwe)
        .fold(0.0, (sum, s) => sum + s.absAmount);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
      children: [
        // ── Summary banner ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.9),
                AppColors.primary.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCol(
                  'You Owe',
                  '₹${totalOwe.toStringAsFixed(0)}',
                  Icons.arrow_upward_rounded,
                  Colors.red.shade300,
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _buildSummaryCol(
                  'You\'re Owed',
                  '₹${totalOwed.toStringAsFixed(0)}',
                  Icons.arrow_downward_rounded,
                  Colors.green.shade300,
                ),
              ),
            ],
          ),
        ),

        // ── Section: You owe ─────────────────────────────────────────────
        if (_settlements.any((s) => s.userOwes)) ...[
          _buildSectionHeader('You Owe', isDark),
          const SizedBox(height: 10),
          ..._settlements
              .where((s) => s.userOwes)
              .map((s) => _buildSettlementCard(s, isDark)),
          const SizedBox(height: 20),
        ],

        // ── Section: They owe ────────────────────────────────────────────
        if (_settlements.any((s) => s.theyOwe)) ...[
          _buildSectionHeader('Owed to You', isDark),
          const SizedBox(height: 10),
          ..._settlements
              .where((s) => s.theyOwe)
              .map((s) => _buildSettlementCard(s, isDark)),
        ],
      ],
    );
  }

  Widget _buildSummaryCol(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSettlementCard(PersonSettlement s, bool isDark) {
    final isOwe = s.userOwes;
    final accentColor = isOwe ? Colors.red.shade400 : Colors.green.shade500;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.2),
                      accentColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    s.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Name + detail
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${s.splitRefs.where((r) => !r.isPaid).length} pending expense(s)',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkSubtext
                            : AppColors.lightSubtext,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Amount + settle button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isOwe ? '-' : '+'}₹${s.absAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _settle(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Settle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
