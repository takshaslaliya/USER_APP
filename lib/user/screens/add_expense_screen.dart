import 'package:flutter/material.dart';
import 'package:splitease_test/core/models/dummy_data.dart';
import 'package:splitease_test/core/models/group_model.dart';
import 'package:splitease_test/core/models/expense_model.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/shared/widgets/app_button.dart';

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
  final Map<String, double> _percentages = {};
  String _splitType = 'Equal';

  @override
  void initState() {
    super.initState();
    // Default: split among all members
    for (var m in widget.group.members) {
      _selectedParticipants.add(m.name);
      _customAmountControllers[m.name] = TextEditingController();
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
    super.dispose();
  }

  void _addExpense() {
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

    // Map participant name into user UUID for the split map
    final Map<String, double> splitAmong = {};
    for (var p in _selectedParticipants) {
      final user = widget.group.members.firstWhere((m) => m.name == p);
      if (_splitType == 'Equal') {
        splitAmong[user.id] = totalAmount / _selectedParticipants.length;
      } else if (_splitType == 'Custom') {
        splitAmong[user.id] =
            double.tryParse(_customAmountControllers[p]?.text ?? '0') ?? 0;
      } else {
        splitAmong[user.id] = totalAmount * ((_percentages[p] ?? 0) / 100);
      }
    }

    final newExpense = ExpenseModel(
      id: 'e${DateTime.now().millisecondsSinceEpoch}',
      title: _nameController.text,
      amount: totalAmount,
      paidById: DummyData.currentUser.id,
      date: DateTime.now(),
      splitAmong: splitAmong,
    );

    setState(() {
      widget.group.expenses.add(newExpense);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Expense added successfully!'),
        backgroundColor: AppColors.primary,
      ),
    );
    Navigator.pop(context); // go back to group details
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
                children: widget.group.members.map((m) {
                  final name = m.name;
                  final selected = _selectedParticipants.contains(name);
                  return FilterChip(
                    label: Text(name),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedParticipants.add(name);
                          if (_splitType == 'Percentage') {
                            // Distribute remaining equally conceptually, but for UI just give 0 initially
                            if (!_percentages.containsKey(name)) {
                              _percentages[name] = 0.0;
                            }
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
                }).toList(),
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
                // Basic percentage slider implementation
                ..._selectedParticipants.map((name) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_percentages[name]?.toStringAsFixed(1)}%',
                              style: TextStyle(color: subColor),
                            ),
                          ],
                        ),
                        Slider(
                          value: _percentages[name] ?? 0.0,
                          min: 0,
                          max: 100,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() {
                              _percentages[name] = val;
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],

              SizedBox(height: 40),
              AppButton(label: 'Save Expense', onPressed: _addExpense),
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
}
