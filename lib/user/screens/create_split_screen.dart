import 'package:flutter/material.dart';
import '../models/dummy_data.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';

class CreateSplitScreen extends StatefulWidget {
  const CreateSplitScreen({super.key});

  @override
  State<CreateSplitScreen> createState() => _CreateSplitScreenState();
}

class _CreateSplitScreenState extends State<CreateSplitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final List<String> _selectedParticipants = [];
  final Map<String, TextEditingController> _customAmountControllers = {};
  final Map<String, double> _percentages = {};
  String _splitType = 'Equal';

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
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.arrow_back_rounded, color: textColor, size: 20),
          ),
        ),
        title: Text(
          'New Split',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.padding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expense detail section
              _sectionHeader('Expense Details', textColor),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
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
                        hintText: 'Expense name (e.g. Goa Trip)',
                        prefixIcon: Icon(Icons.receipt_long_outlined, size: 20),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'Enter expense name' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Total amount (₹)',
                        prefixIcon: Icon(
                          Icons.currency_rupee_rounded,
                          size: 20,
                        ),
                      ),
                      validator: (v) {
                        if (v!.isEmpty) return 'Enter amount';
                        if (double.tryParse(v) == null) {
                          return 'Enter valid amount';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Split type
              _sectionHeader('Split Type', textColor),
              const SizedBox(height: 12),
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
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              // Participants
              Row(
                children: [
                  _sectionHeader('Participants', textColor),
                  const Spacer(),
                  Text(
                    '${_selectedParticipants.length} selected',
                    style: TextStyle(color: subColor, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DummyData.participantSuggestions.map((name) {
                  final selected = _selectedParticipants.contains(name);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedParticipants.remove(name);
                        _customAmountControllers[name]?.dispose();
                        _customAmountControllers.remove(name);
                        _percentages.remove(name);
                        _rebalancePercentages();
                      } else {
                        _selectedParticipants.add(name);
                        _customAmountControllers[name] =
                            TextEditingController();
                        _percentages[name] = 0;
                        _rebalancePercentages();
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : (isDark
                                    ? AppColors.darkSurfaceVariant
                                    : AppColors.lightSurfaceVariant),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected)
                            const Padding(
                              padding: EdgeInsets.only(right: 5),
                              child: Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          Text(
                            name,
                            style: TextStyle(
                              color: selected ? Colors.white : textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_splitType == 'Percentage' &&
                  _selectedParticipants.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    _sectionHeader('Percentages', textColor),
                    const Spacer(),
                    Builder(
                      builder: (context) {
                        final total = _percentages.values.fold(
                          0.0,
                          (a, b) => a + b,
                        );
                        final is100 = (total - 100).abs() < 1;
                        return Text(
                          '${total.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: is100 ? AppColors.primary : AppColors.error,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
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
                    children: _selectedParticipants.asMap().entries.map((
                      entry,
                    ) {
                      final index = entry.key;
                      final name = entry.value;
                      final isLast = index == _selectedParticipants.length - 1;
                      return Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: AppColors.primary,
                                  inactiveTrackColor: isDark
                                      ? AppColors.darkSurfaceVariant
                                      : AppColors.lightSurfaceVariant,
                                  thumbColor: AppColors.primary,
                                  overlayColor: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  trackHeight: 4,
                                ),
                                child: Slider(
                                  value: _percentages[name] ?? 0,
                                  min: 0,
                                  max: 100,
                                  divisions: 100,
                                  onChanged: (val) =>
                                      setState(() => _percentages[name] = val),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 36,
                              child: Text(
                                '${(_percentages[name] ?? 0).toStringAsFixed(0)}%',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              if (_splitType == 'Custom' &&
                  _selectedParticipants.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    _sectionHeader('Custom Amounts', textColor),
                    const Spacer(),
                    Text(
                      '₹${_calculateCustomTotal()}',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
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
                    children: _selectedParticipants.asMap().entries.map((
                      entry,
                    ) {
                      final index = entry.key;
                      final name = entry.value;
                      final isLast = index == _selectedParticipants.length - 1;
                      return Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: TextFormField(
                                  controller: _customAmountControllers[name],
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: '₹0.00',
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    isDense: true,
                                  ),
                                  validator: (v) {
                                    if (_splitType == 'Custom') {
                                      if (v == null || v.isEmpty) return 'Req';
                                      if (double.tryParse(v) == null) {
                                        return 'Inv';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 36),
              AppButton(
                label: 'Generate Payment Link',
                icon: Icons.link_rounded,
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    if (_splitType == 'Percentage' &&
                        _selectedParticipants.isNotEmpty) {
                      final total = _percentages.values.fold(
                        0.0,
                        (a, b) => a + b,
                      );
                      if ((total - 100).abs() >= 1) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Percentages must sum exactly to 100%',
                            ),
                            backgroundColor: AppColors.error,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                    }
                    Navigator.pushNamed(context, '/share');
                  }
                },
              ),
              const SizedBox(height: 20),
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
      ),
    );
  }

  void _rebalancePercentages() {
    if (_selectedParticipants.isEmpty) return;
    final equalShare = 100.0 / _selectedParticipants.length;
    for (var name in _selectedParticipants) {
      _percentages[name] = equalShare;
    }
  }
}
