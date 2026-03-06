import re

with open("lib/user/screens/add_expense_screen.dart", "r") as f:
    content = f.read()

# We need to completely rewrite the AddExpenseScreenState.
# The user wants:
# 1. No Split Options (no Custom/Percentage/Equal). Split is always equal among `_selectedParticipants`.
# 2. A "Who Paid?" section where users select who paid (adds to `_payerIds`).
#    If they select a payer, that payer is automatically removed from `_selectedParticipants`.
#    If >1 payer is selected, show TextFields for them to enter how much they paid.
# 3. Use `calculateOptimalSplit` if >1 payer (Group Payment).
#    Use `createSubGroup` if exactly 1 payer (Solo Payment).

new_code = """import 'package:flutter/material.dart';
import 'package:splitease_test/core/models/group_model.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/shared/widgets/app_button.dart';
import 'package:splitease_test/core/services/group_service.dart';

class AddExpenseScreen extends StatefulWidget {
  final GroupModel group;

  const AddExpenseScreen({super.key, required this.group});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  
  // Who Paid?
  final Set<String> _payerIds = {};
  final Map<String, TextEditingController> _payerAmountControllers = {};

  // Split Among
  final List<String> _selectedParticipants = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final Set<String> seenNames = {};
    for (var m in widget.group.members) {
      if (seenNames.contains(m.name)) continue;
      seenNames.add(m.name);

      _selectedParticipants.add(m.name);
      _payerAmountControllers[m.name] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    for (var c in _payerAmountControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addExpense() async {
    if (!_formKey.currentState!.validate()) return;

    if (_payerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select who paid for the expense.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Select at least one participant to split among.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final totalAmount = double.parse(_amountController.text);

    if (_payerIds.length > 1) {
      // Group Payment (Multiple Payers)
      double payerSum = 0;
      final Map<String, double> payments = {};
      for (var name in _payerIds) {
        final amt = double.tryParse(_payerAmountControllers[name]?.text ?? '0') ?? 0;
        payerSum += amt;
        if (amt > 0) payments[name] = amt;
      }

      if ((payerSum - totalAmount).abs() > 0.1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Total payments (₹${payerSum.toStringAsFixed(0)}) must match the expense amount (₹${totalAmount.toStringAsFixed(0)}).',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);
      
      // Calculate split equally for selected participants, then let optimal split handle the differences
      final res = await GroupService.calculateOptimalSplit(
        totalAmount: totalAmount,
        members: _selectedParticipants,
        payments: payments,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.success) {
        _showSettlementPlan(res.data);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // Solo Payment (1 Payer)
    setState(() => _isLoading = true);

    final List<Map<String, dynamic>> participantData = [];
    double amountPerPerson = totalAmount / _selectedParticipants.length;

    for (var p in _selectedParticipants) {
      final member = widget.group.members.firstWhere((m) => m.name == p);
      participantData.add({
        'name': p,
        'phone_number': member.phoneNumber ?? '',
        'expense_amount': amountPerPerson,
      });
    }

    final result = await GroupService.createSubGroup(
      widget.group.id,
      _nameController.text.trim(),
      'Split: Equal (Paid by: ${_payerIds.first})',
      totalAmount,
      participantData,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Expense "${_nameController.text}" added successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.arrow_back_rounded, color: textColor, size: 20),
          ),
        ),
        title: Text(
          'Add Expense',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.padding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('Expense Details', textColor),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                  ),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'Expense name (e.g. Dinner, Cab)',
                        border: InputBorder.none,
                      ),
                      validator: (v) => v!.isEmpty ? 'Enter expense name' : null,
                    ),
                    Divider(
                      color: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.lightSurfaceVariant,
                    ),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Amount (₹)',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.currency_rupee_rounded, size: 20),
                      ),
                      onChanged: (val) {
                        setState(() {
                           if (_payerIds.length == 1) {
                              _payerAmountControllers[_payerIds.first]?.text = val;
                           }
                        });
                      },
                      validator: (v) {
                        if (v!.isEmpty) return 'Enter amount';
                        if (double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              // Who Paid Section
              _sectionHeader('Who Paid?', textColor),
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: () {
                  final Set<String> seen = {};
                  final uniqueMembers = widget.group.members.where((m) {
                    if (seen.contains(m.name)) return false;
                    seen.add(m.name);
                    return true;
                  }).toList();

                  return uniqueMembers.map((m) {
                    final name = m.name;
                    final selected = _payerIds.contains(name);
                    return FilterChip(
                      label: Text(name),
                      selected: selected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _payerIds.add(name);
                            _selectedParticipants.remove(name);
                            if (_payerIds.length == 1) {
                              _payerAmountControllers[name]?.text = _amountController.text;
                            } else {
                              for(var payer in _payerIds) {
                                _payerAmountControllers[payer]?.text = '';
                              }
                            }
                          } else {
                            _payerIds.remove(name);
                            _payerAmountControllers[name]?.text = '';
                            if (_payerIds.length == 1) {
                                _payerAmountControllers[_payerIds.first]?.text = _amountController.text;
                            }
                          }
                        });
                      },
                      backgroundColor: surfaceColor,
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected ? AppColors.primary : textColor,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: selected
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkSurfaceVariant
                                  : AppColors.lightSurfaceVariant),
                        ),
                      ),
                    );
                  }).toList();
                }(),
              ),
              
              if (_payerIds.length > 1) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.lightSurfaceVariant,
                    ),
                  ),
                  child: Column(
                    children: _payerIds.map((payerName) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(payerName,
                                style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w600)),
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _payerAmountControllers[payerName],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(
                                  hintText: '₹0',
                                  border: UnderlineInputBorder(),
                                ),
                                onChanged: (val) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              SizedBox(height: 24),

              Row(
                children: [
                  _sectionHeader('Split Among (Equal)', textColor),
                  const Spacer(),
                  Text(
                    '${_selectedParticipants.length} people',
                    style: TextStyle(color: subColor, fontSize: 12),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: () {
                  final Set<String> seen = {};
                  final uniqueMembers = widget.group.members.where((m) {
                    if (seen.contains(m.name)) return false;
                    seen.add(m.name);
                    return true;
                  }).toList();

                  return uniqueMembers.map((m) {
                    final name = m.name;
                    final selected = _selectedParticipants.contains(name);
                    return FilterChip(
                      label: Text(name),
                      selected: selected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedParticipants.add(name);
                          } else {
                            _selectedParticipants.remove(name);
                          }
                        });
                      },
                      backgroundColor: surfaceColor,
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected ? AppColors.primary : textColor,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: selected
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkSurfaceVariant
                                  : AppColors.lightSurfaceVariant),
                        ),
                      ),
                    );
                  }).toList();
                }(),
              ),

              SizedBox(height: 40),
              _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : AppButton(
                      label: _payerIds.length > 1 ? 'Calculate Group Split' : 'Save Expense',
                      onPressed: _addExpense
                    ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }

  void _showSettlementPlan(dynamic data) {
    final transactions = data['transactions'] as List<dynamic>? ?? [];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
        final textColor = isDark ? AppColors.darkText : AppColors.lightText;
        
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Optimal Settlement Plan',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Minimum transactions needed to settle all debts:',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              
              if (transactions.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'Everyone is settled up!',
                      style: TextStyle(color: textColor, fontSize: 16),
                    ),
                  ),
                )
              else
                ...transactions.map((tx) {
                  final from = tx['from'];
                  final to = tx['to'];
                  final amount = (tx['amount'] as num).toDouble();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            from,
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 20),
                        Expanded(
                          child: Text(
                            to,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: AppColors.paid,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '₹${amount.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
"""

with open("lib/user/screens/add_expense_screen.dart", "w") as f:
    f.write(new_code)

print("Rewrote AddExpenseScreen successfully.")
