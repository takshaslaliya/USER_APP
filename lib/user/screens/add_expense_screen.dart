import 'package:flutter/material.dart';
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
  final List<String> _selectedParticipants = [];
  final Map<String, TextEditingController> _customAmountControllers = {};
  final Map<String, TextEditingController> _percentageControllers = {};
  final Map<String, TextEditingController> _payerAmountControllers = {};
  final Map<String, double> _percentages = {};
  String _splitType = 'Equal';
  String _paymentType = 'Solo Payment';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default: split among all unique members
    final Set<String> seenNames = {};
    for (var m in widget.group.members) {
      if (seenNames.contains(m.name)) continue;
      seenNames.add(m.name);

      _selectedParticipants.add(m.name);
      _customAmountControllers[m.name] = TextEditingController();
      _payerAmountControllers[m.name] = TextEditingController();
      _percentageControllers[m.name] = TextEditingController(
        text: (100.0 / widget.group.members.length).toStringAsFixed(1),
      );
      _percentages[m.name] = 100.0 / widget.group.members.length;
    }
  }

  String _calculateCustomTotal() {
    double total = 0;
    for (var c in _customAmountControllers.values) {
      if (c.text.isNotEmpty) {
        total += double.tryParse(c.text) ?? 0;
      }
    }
    return total.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    for (var c in _customAmountControllers.values) {
      c.dispose();
    }
    for (var c in _payerAmountControllers.values) {
      c.dispose();
    }
    for (var c in _percentageControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addExpense() async {
    if (!_formKey.currentState!.validate()) return;

    // Amount validation
    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Select at least one participant'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final totalAmount = double.parse(_amountController.text);

    if (_paymentType == 'Group Payment') {
      double payerSum = 0;
      final Map<String, double> payments = {};
      final uniqueNames = widget.group.members.map((m) => m.name).toSet();
      for (var name in uniqueNames) {
        final amt =
            double.tryParse(_payerAmountControllers[name]?.text ?? '0') ?? 0;
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

    if (_splitType == 'Custom') {
      double customSum = 0;
      for (var p in _selectedParticipants) {
        customSum +=
            double.tryParse(_customAmountControllers[p]?.text ?? '0') ?? 0;
      }
      if (customSum != totalAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Custom amounts must exactly match the total expense.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    } else if (_splitType == 'Percentage') {
      double pctSum = 0;
      for (var p in _selectedParticipants) {
        pctSum += _percentages[p] ?? 0;
      }
      if ((pctSum - 100).abs() > 0.1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Percentages must total 100%.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    // Prepare members list for API
    final List<Map<String, dynamic>> participantData = [];
    for (var p in _selectedParticipants) {
      double amount;
      if (_splitType == 'Equal') {
        amount = totalAmount / _selectedParticipants.length;
      } else if (_splitType == 'Percentage') {
        amount = totalAmount * (_percentages[p] ?? 0) / 100.0;
      } else {
        amount = double.tryParse(_customAmountControllers[p]?.text ?? '0') ?? 0;
      }

      // Find the member to get their phone number
      final member = widget.group.members.firstWhere((m) => m.name == p);

      participantData.add({
        'name': p,
        'phone_number': member.phoneNumber ?? '',
        'expense_amount': amount,
      });
    }

    final result = await GroupService.createSubGroup(
      widget.group.id,
      _nameController.text.trim(),
      'Split: $_splitType',
      totalAmount,
      participantData,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Expense "${_nameController.text}" added successfully!',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context, true); // go back with success signal
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
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;

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
                      validator: (v) =>
                          v!.isEmpty ? 'Enter expense name' : null,
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
                        prefixIcon: Icon(
                          Icons.currency_rupee_rounded,
                          size: 20,
                        ),
                      ),
                      onChanged: (val) => setState(() {}),
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
              // Payment type (Solo vs Group)
              _sectionHeader('Payment Type', textColor),
              SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                  ),
                ),
                child: Row(
                  children: ['Solo Payment', 'Group Payment'].map((type) {
                    final selected = _paymentType == type;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _paymentType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.all(4),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              type,
                              style: TextStyle(
                                color: selected ? Colors.white : subColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 24),

              if (_paymentType == 'Group Payment') ...[
                _sectionHeader('Who Paid?', textColor),
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
                    children: () {
                      final Set<String> seen = {};
                      final uniqueMembers = widget.group.members.where((m) {
                        if (seen.contains(m.name)) return false;
                        seen.add(m.name);
                        return true;
                      }).toList();

                      return uniqueMembers.map((m) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                m.name,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: _payerAmountControllers[m.name],
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
                      }).toList();
                    }(),
                  ),
                ),
                SizedBox(height: 24),
              ],

              // Split type
              _sectionHeader('Split Options', textColor),
              SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                  ),
                ),
                child: Row(
                  children: ['Equal', 'Percentage', 'Custom'].map((type) {
                    final selected = _splitType == type;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _splitType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.all(4),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              type,
                              style: TextStyle(
                                color: selected ? Colors.white : subColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 24),

              Row(
                children: [
                  _sectionHeader('Split Among', textColor),
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
                            if (!_percentages.containsKey(name)) {
                              _percentages[name] = 0.0;
                              _percentageControllers[name] =
                                  TextEditingController(text: '0.0');
                            }
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
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
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

              if (_splitType == 'Custom' &&
                  _selectedParticipants.isNotEmpty) ...[
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Assigned custom amount',
                      style: TextStyle(color: subColor),
                    ),
                    Text(
                      '₹${_calculateCustomTotal()} / ₹${_amountController.text.isEmpty ? "0" : _amountController.text}',
                      style: TextStyle(
                        color:
                            (double.tryParse(_amountController.text) ?? 0) !=
                                (double.tryParse(_calculateCustomTotal()) ?? 0)
                            ? AppColors.error
                            : AppColors.paid,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                ..._selectedParticipants.map(
                  (name) => Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _customAmountControllers[name],
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
                  ),
                ),
              ],

              if (_splitType == 'Percentage' &&
                  _selectedParticipants.isNotEmpty) ...[
                SizedBox(height: 24),
                // Percentage manual entry implementation
                ..._selectedParticipants.map((name) {
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.lightSurfaceVariant,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              suffixText: '%',
                              suffixStyle: TextStyle(color: subColor),
                              isDense: true,
                              border: InputBorder.none,
                              hintText: '0.0',
                            ),
                            onChanged: (val) {
                              final num = double.tryParse(val);
                              if (num != null && num >= 0 && num <= 100) {
                                setState(() {
                                  _percentages[name] = num;
                                });
                              }
                            },
                            controller: _percentageControllers[name],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Total: ',
                      style: TextStyle(color: subColor, fontSize: 13),
                    ),
                    Text(
                      '${_percentages.values.fold(0.0, (sum, v) => sum + v).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color:
                            (_percentages.values.fold(
                                          0.0,
                                          (sum, v) => sum + v,
                                        ) -
                                        100)
                                    .abs() <
                                0.1
                            ? AppColors.paid
                            : AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ],

              SizedBox(height: 40),
              _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : AppButton(
                      label: _paymentType == 'Group Payment'
                          ? 'Calculate Group Split'
                          : 'Save Expense',
                      onPressed: _addExpense,
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
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
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
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
