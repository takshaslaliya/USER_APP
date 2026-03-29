import 'package:flutter/material.dart';
import 'package:splitease_test/core/models/personal_expense_model.dart';
import 'package:splitease_test/core/services/user_service.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class PersonalExpensesScreen extends StatefulWidget {
  const PersonalExpensesScreen({super.key});

  @override
  State<PersonalExpensesScreen> createState() => _PersonalExpensesScreenState();
}

class _PersonalExpensesScreenState extends State<PersonalExpensesScreen> {
  List<PersonalExpense> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final data = await UserService.fetchPersonalExpenses();
    if (mounted) {
      setState(() {
        _expenses = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePaidStatus(PersonalExpense expense) async {
    final newStatus = !expense.isPaid;
    final res = await UserService.updatePersonalExpenseStatus(expense.id, newStatus);
    
    if (res.success && mounted) {
      _loadExpenses();
    }
  }

  Future<void> _deleteExpense(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await UserService.deletePersonalExpense(id);
      if (res.success && mounted) {
        _loadExpenses();
      }
    }
  }

  void _showEditDialog(PersonalExpense expense) {
    final nameCtrl = TextEditingController(text: expense.name);
    final amountCtrl = TextEditingController(text: expense.amount.toString());
    final categoryCtrl = TextEditingController(text: expense.category);
    final descCtrl = TextEditingController(text: expense.description ?? '');
    bool isIncome = !expense.isSpent;

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
              title: Text('Edit Expense',
                  style: TextStyle(color: isDark ? AppColors.darkText : const Color(0xFF1D3A44))),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Expense Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount (₹)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryCtrl,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description (Optional)'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: isIncome,
                          onChanged: (val) => setDialogState(() => isIncome = val ?? false),
                          activeColor: AppColors.primary,
                        ),
                        const Text('This is Income'),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                    final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                    
                    final result = await UserService.updatePersonalExpense(
                      id: expense.id,
                      name: nameCtrl.text,
                      amount: amount,
                      type: isIncome ? 'Income' : 'Spent',
                      category: categoryCtrl.text.isEmpty ? 'Other' : categoryCtrl.text,
                      description: descCtrl.text,
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      _loadExpenses();
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text('Personal Expenses',
            style: TextStyle(color: isDark ? AppColors.darkText : AppColors.lightText, 
            fontSize: 20, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: _expenses.length,
              itemBuilder: (context, index) => _buildExpenseTile(_expenses[index], isDark),
            ),
    );
  }

  Widget _buildExpenseTile(PersonalExpense ex, bool isDark) {
    final amountColor = ex.isSpent ? AppColors.error : const Color(0xFF2ECC71);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: amountColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(ex.isSpent ? Icons.arrow_outward_rounded : Icons.south_west_rounded, 
                  color: amountColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ex.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${ex.category} • ${DateFormat('MMM dd').format(ex.date)}', 
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Text('${ex.isSpent ? "- " : "+ "}₹${ex.amount.toStringAsFixed(0)}',
                style: TextStyle(color: amountColor, fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _togglePaidStatus(ex),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: ex.isPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(ex.isPaid ? Icons.check_circle : Icons.pending, size: 14, 
                        color: ex.isPaid ? Colors.green : Colors.orange),
                      const SizedBox(width: 4),
                      Text(ex.isPaid ? 'PAID' : 'PENDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, 
                        color: ex.isPaid ? Colors.green : Colors.orange)),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                    onPressed: () => _showEditDialog(ex),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                    onPressed: () => _deleteExpense(ex.id),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
