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

  // Payment type toggle
  String _paymentType = 'Solo Payment'; // 'Solo Payment' | 'Group Payment'

  // ── Solo Payment ──────────────────────────────────────────────────────────
  // Only one member can be the payer; all others split the cost equally
  String? _soloPayer; // name of the single payer

  // ── Group Payment ─────────────────────────────────────────────────────────
  // Multiple payers; each enters how much they paid
  final Set<String> _groupPayerIds = {};
  final Map<String, TextEditingController> _payerAmountControllers = {};

  // Split Among (shared by both modes)
  final List<String> _selectedParticipants = [];

  bool _isLoading = false;

  List<String> get _uniqueNames {
    final Set<String> seen = {};
    return widget.group.members
        .where((m) => seen.add(m.name))
        .map((m) => m.name)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    for (final name in _uniqueNames) {
      _selectedParticipants.add(name);
      _payerAmountControllers[name] = TextEditingController();
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

  // ── Validation helpers ───────────────────────────────────────────────────

  bool _validate() {
    if (!_formKey.currentState!.validate()) return false;

    if (_paymentType == 'Solo Payment') {
      if (_soloPayer == null) {
        _snack('Please select who paid for the expense.');
        return false;
      }
      if (_selectedParticipants.isEmpty) {
        _snack('Select at least one participant to split among.');
        return false;
      }
    } else {
      if (_groupPayerIds.isEmpty) {
        _snack('Please select at least one payer.');
        return false;
      }
      if (_selectedParticipants.isEmpty) {
        _snack('Select at least one participant to split among.');
        return false;
      }
      final totalAmount = double.parse(_amountController.text);
      double payerSum = 0;
      for (var name in _groupPayerIds) {
        payerSum +=
            double.tryParse(_payerAmountControllers[name]?.text ?? '0') ?? 0;
      }
      if ((payerSum - totalAmount).abs() > 0.1) {
        _snack(
          'Total payments (₹${payerSum.toStringAsFixed(0)}) must match the expense amount (₹${totalAmount.toStringAsFixed(0)}).',
        );
        return false;
      }
    }
    return true;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  // ── Submit ───────────────────────────────────────────────────────────────

  Future<void> _addExpense() async {
    if (!_validate()) return;

    final totalAmount = double.parse(_amountController.text);

    if (_paymentType == 'Group Payment') {
      setState(() => _isLoading = true);

      final Map<String, double> payments = {};
      for (var name in _groupPayerIds) {
        final amt =
            double.tryParse(_payerAmountControllers[name]?.text ?? '0') ?? 0;
        if (amt > 0) payments[name] = amt;
      }

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
        _snack(res.message);
      }
      return;
    }

    // ── Solo Payment ──────────────────────────────────────────────────────
    setState(() => _isLoading = true);

    final double amountPerPerson = totalAmount / _selectedParticipants.length;
    final List<Map<String, dynamic>> participantData = [];

    for (final p in _selectedParticipants) {
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
      'Paid by: $_soloPayer',
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
      Navigator.pop(context, true);
    } else {
      _snack(result.message);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
              // ── Expense Details ──────────────────────────────────────────
              _sectionHeader('Expense Details', textColor),
              SizedBox(height: 12),
              _card(
                isDark: isDark,
                surfaceColor: surfaceColor,
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
                    _divider(isDark),
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
                      onChanged: (val) {
                        // Keep single payer amount in sync
                        if (_paymentType == 'Solo Payment' &&
                            _soloPayer != null) {
                          setState(() {});
                        }
                        if (_paymentType == 'Group Payment' &&
                            _groupPayerIds.length == 1) {
                          setState(
                            () =>
                                _payerAmountControllers[_groupPayerIds.first]
                                        ?.text =
                                    val,
                          );
                        }
                      },
                      validator: (v) {
                        if (v!.isEmpty) return 'Enter amount';
                        if (double.tryParse(v) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // ── Payment Type Toggle ──────────────────────────────────────
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
                        onTap: () => setState(() {
                          _paymentType = type;
                          // Reset payer state when switching
                          _soloPayer = null;
                          _groupPayerIds.clear();
                          // Restore removed participants
                          for (final name in _uniqueNames) {
                            if (!_selectedParticipants.contains(name)) {
                              _selectedParticipants.add(name);
                            }
                          }
                          for (var c in _payerAmountControllers.values) {
                            c.text = '';
                          }
                        }),
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

              // ── SOLO: Paid By (single member dropdown) ───────────────────
              if (_paymentType == 'Solo Payment') ...[
                _sectionHeader('Paid By', textColor),
                SizedBox(height: 12),
                _card(
                  isDark: isDark,
                  surfaceColor: surfaceColor,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _soloPayer,
                      isExpanded: true,
                      hint: Text(
                        'Select who paid',
                        style: TextStyle(color: subColor),
                      ),
                      dropdownColor: surfaceColor,
                      style: TextStyle(color: textColor, fontSize: 15),
                      icon: Icon(
                        Icons.arrow_drop_down_rounded,
                        color: AppColors.primary,
                      ),
                      items: _uniqueNames.map((name) {
                        return DropdownMenuItem<String>(
                          value: name,
                          child: Text(name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _soloPayer = val;
                          // Payer is NOT in the split list (they receive money)
                          if (val != null) {
                            _selectedParticipants.remove(val);
                            // Re-add all others who might have been removed by a prior payer selection
                            for (final name in _uniqueNames) {
                              if (name != val &&
                                  !_selectedParticipants.contains(name)) {
                                _selectedParticipants.add(name);
                              }
                            }
                          }
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(height: 24),
              ],

              // ── GROUP: Who Paid (multi-chip + amount fields) ──────────────
              if (_paymentType == 'Group Payment') ...[
                _sectionHeader('Who Paid?', textColor),
                SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _uniqueNames.map((name) {
                    final selected = _groupPayerIds.contains(name);
                    return FilterChip(
                      label: Text(name),
                      selected: selected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _groupPayerIds.add(name);
                            _selectedParticipants.remove(name);
                            if (_groupPayerIds.length == 1) {
                              _payerAmountControllers[name]?.text =
                                  _amountController.text;
                            } else {
                              for (var payer in _groupPayerIds) {
                                _payerAmountControllers[payer]?.text = '';
                              }
                            }
                          } else {
                            _groupPayerIds.remove(name);
                            _payerAmountControllers[name]?.text = '';
                            if (!_selectedParticipants.contains(name)) {
                              _selectedParticipants.add(name);
                            }
                            if (_groupPayerIds.length == 1) {
                              _payerAmountControllers[_groupPayerIds.first]
                                      ?.text =
                                  _amountController.text;
                            }
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

                if (_groupPayerIds.length > 1) ...[
                  SizedBox(height: 16),
                  _card(
                    isDark: isDark,
                    surfaceColor: surfaceColor,
                    child: Column(
                      children: _groupPayerIds.map((payerName) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                payerName,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: TextField(
                                  controller:
                                      _payerAmountControllers[payerName],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    hintText: '₹0',
                                    hintStyle: TextStyle(color: subColor),
                                    border: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: AppColors.primary,
                                      ),
                                    ),
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
              ],

              // ── Split Among (both modes) ──────────────────────────────────
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
                children: _uniqueNames.map((name) {
                  // Payers cannot be in the split list
                  final isPayer = _paymentType == 'Solo Payment'
                      ? _soloPayer == name
                      : _groupPayerIds.contains(name);
                  if (isPayer) return const SizedBox.shrink();

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

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, Color textColor) => Text(
    title,
    style: TextStyle(
      color: textColor,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    ),
  );

  Widget _card({
    required bool isDark,
    required Color surfaceColor,
    required Widget child,
  }) => Container(
    width: double.infinity,
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
    child: child,
  );

  Divider _divider(bool isDark) => Divider(
    color: isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant,
  );

  // ── Settlement plan modal (Group Payment) ─────────────────────────────────

  void _showSettlementPlan(dynamic data) {
    final transactions = data['transactions'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
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
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Everyone is settled up!',
                      style: TextStyle(color: textColor, fontSize: 16),
                    ),
                  ),
                )
              else
                ...transactions.map((tx) {
                  final from = tx['from'] as String;
                  final to = tx['to'] as String;
                  final amount = (tx['amount'] as num).toDouble();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
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
                        const SizedBox(width: 12),
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
                }),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
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
