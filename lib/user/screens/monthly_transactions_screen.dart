import 'package:flutter/material.dart';
import 'package:splitease_test/core/models/monthly_transaction_model.dart';
import 'package:splitease_test/core/services/user_service.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class MonthlyTransactionsScreen extends StatefulWidget {
  final String month; // e.g. "2026-03"
  final String monthName;

  const MonthlyTransactionsScreen({
    super.key,
    required this.month,
    required this.monthName,
  });

  @override
  State<MonthlyTransactionsScreen> createState() => _MonthlyTransactionsScreenState();
}

class _MonthlyTransactionsScreenState extends State<MonthlyTransactionsScreen> {
  late String _currentMonth;
  late String _currentMonthName;
  List<MonthlyTransaction> _transactions = [];
  bool _isLoading = true;

  double _totalSpent = 0;
  double _totalReceived = 0;
  double _netBalance = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.month;
    _currentMonthName = widget.monthName;
    _fetchData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted) _fetchData(isPolling: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData({bool isPolling = false}) async {
    if (!mounted) return;
    if (!isPolling) setState(() => _isLoading = true);
    
    final data = await UserService.fetchMonthlyTransactions(_currentMonth);
    
    if (mounted) {
      // Calculate totals
      double spent = 0;
      double received = 0;
      for (var tx in data) {
        if (tx.type == 'Sent') {
          spent += tx.amount;
        } else if (tx.type == 'Received') {
          received += tx.amount;
        }
      }

      setState(() {
        _transactions = data;
        _totalSpent = spent;
        _totalReceived = received;
        _netBalance = received - spent;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse("$_currentMonth-01"),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      final newMonth = DateFormat('yyyy-MM').format(picked);
      final newMonthName = DateFormat('MMMM').format(picked);
      if (newMonth != _currentMonth) {
        setState(() {
          _currentMonth = newMonth;
          _currentMonthName = newMonthName;
        });
        _fetchData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          'Transactions: $_currentMonthName',
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
            icon: Icon(Icons.calendar_month_rounded, color: AppColors.primary),
            onPressed: _selectMonth,
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildSummaryHeader(isDark),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final tx = _transactions[index];
                          return _buildTransactionTile(tx, isDark);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [AppColors.darkSurface, AppColors.darkSurface.withOpacity(0.8)]
            : [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Net Balance',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_netBalance.abs().toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Spent', _totalSpent, Icons.arrow_upward_rounded, AppColors.error),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
              _buildSummaryItem('Received', _totalReceived, Icons.arrow_downward_rounded, const Color(0xFF2ECC71)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.primary.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            'No transactions for this month',
            style: TextStyle(
              color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(MonthlyTransaction tx, bool isDark) {
    final isSent = tx.type == 'Sent';
    final isReceived = tx.type == 'Received';

    Color amountColor;
    if (isSent) {
      amountColor = AppColors.error;
    } else if (isReceived) {
      amountColor = const Color(0xFF2ECC71);
    } else {
      amountColor = isDark ? AppColors.darkText : AppColors.lightText;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkSurfaceVariant : Colors.transparent,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: amountColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSent ? Icons.arrow_outward_rounded : Icons.south_west_rounded,
              color: amountColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? AppColors.darkText : const Color(0xFF1D3A44),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tx.otherParty} • ${DateFormat('MMM dd, hh:mm a').format(tx.date)}',
                  style: TextStyle(
                    color: isDark ? AppColors.darkSubtext : const Color(0xFF5E7A81),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isSent ? "- " : isReceived ? "+ " : ""}₹${tx.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  color: amountColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tx.isPaid
                      ? const Color(0xFF2ECC71).withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tx.isPaid ? 'Paid' : 'Unpaid',
                  style: TextStyle(
                    color: tx.isPaid ? const Color(0xFF27AE60) : Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
