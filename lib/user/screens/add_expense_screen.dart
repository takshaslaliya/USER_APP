import 'package:flutter/material.dart';
import 'package:splitease_test/core/models/group_model.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/shared/widgets/app_button.dart';
import 'package:splitease_test/core/services/group_service.dart';
import 'package:splitease_test/core/services/auth_service.dart';

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

  // ── Payment type ──────────────────────────────────────────────────────────
  String _paymentType = 'Solo Payment'; // 'Solo Payment' | 'Group Payment'

  // ── Solo Payment ──────────────────────────────────────────────────────────
  String? _soloPayer;
  bool _soloPayerIsRegistered = true;
  String? _soloPayerUpiFromApi; // UPI from API (if registered & linked)
  final _soloPayerUpiController =
      TextEditingController(); // manual UPI override
  bool _checkingStatus = false;

  // ── Group Payment ─────────────────────────────────────────────────────────
  final Set<String> _groupPayerIds = {};
  final Map<String, TextEditingController> _payerAmountControllers = {};
  // Per-payer status for Group Payment
  final Map<String, bool> _groupPayerRegistered = {}; // true = registered
  final Map<String, String?> _groupPayerUpiFromApi = {}; // UPI from API
  final Map<String, TextEditingController> _groupPayerUpiControllers = {};
  final Map<String, bool> _groupPayerChecking = {}; // loading per payer

  // ── Split Options (shared) ────────────────────────────────────────────────
  String _splitType = 'Equal'; // 'Equal' | 'Percentage' | 'Custom'
  final Map<String, TextEditingController> _percentControllers = {};
  final Map<String, TextEditingController> _customControllers = {};

  // ── Split Among ───────────────────────────────────────────────────────────
  final List<String> _selectedParticipants = [];

  bool _isLoading = false;
  Map<String, dynamic>? _settlementData;

  final Map<String, String> _phoneToNameCache = {};

  String _normalize(String phone) {
    String normalized = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (normalized.startsWith('+')) normalized = normalized.substring(1);
    if (!normalized.startsWith('91') && normalized.length == 10) {
      normalized = '91$normalized';
    }
    return normalized;
  }

  Future<String> _getNameFromPhone(String phone) async {
    if (_phoneToNameCache.containsKey(phone)) return _phoneToNameCache[phone]!;

    // Check local group members first
    for (var m in widget.group.members) {
      if (_normalize(m.phoneNumber ?? '') == phone) {
        _phoneToNameCache[phone] = m.name;
        return m.name;
      }
    }

    // Call API fallback
    final res = await AuthService.getMemberName(phone);
    if (res.success && res.data != null) {
      final name = res.data!['name'] as String? ?? phone;
      _phoneToNameCache[phone] = name;
      return name;
    }

    return phone;
  }

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
      _groupPayerUpiControllers[name] = TextEditingController();
      _percentControllers[name] = TextEditingController(text: '0');
      _customControllers[name] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _soloPayerUpiController.dispose();
    for (var c in _payerAmountControllers.values) c.dispose();
    for (var c in _groupPayerUpiControllers.values) c.dispose();
    for (var c in _percentControllers.values) c.dispose();
    for (var c in _customControllers.values) c.dispose();
    super.dispose();
  }

  // ── Payer status check (Solo) ─────────────────────────────────────────────

  Future<void> _checkSoloPayer(String name) async {
    final member = widget.group.members.firstWhere((m) => m.name == name);
    final phone = member.phoneNumber ?? '';
    if (phone.isEmpty) {
      setState(() {
        _soloPayerIsRegistered = false;
        _soloPayerUpiFromApi = null;
      });
      return;
    }

    String normalized = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (normalized.startsWith('+')) normalized = normalized.substring(1);
    if (!normalized.startsWith('91') && normalized.length == 10) {
      normalized = '91$normalized';
    }

    setState(() => _checkingStatus = true);
    final res = await AuthService.checkUserStatus(normalized);
    if (!mounted) return;

    bool isReg = false;
    String? upiId;
    if (res.data != null) {
      final raw = res.data!['is_register'];
      isReg = (raw == true) || (raw?.toString().toLowerCase() == 'true');
      final rawUpi = res.data!['upi_id'];
      if (rawUpi != null &&
          rawUpi.toString().isNotEmpty &&
          rawUpi.toString() != 'false') {
        upiId = rawUpi.toString();
      }
    }

    setState(() {
      _checkingStatus = false;
      _soloPayerIsRegistered = isReg;
      _soloPayerUpiFromApi = upiId;
      _soloPayerUpiController.text = upiId ?? '';
    });
  }

  // ── Payer status check (Group Payment) ───────────────────────────────────

  Future<void> _checkGroupPayer(String name) async {
    final member = widget.group.members.firstWhere((m) => m.name == name);
    final phone = member.phoneNumber ?? '';
    if (phone.isEmpty) {
      setState(() {
        _groupPayerRegistered[name] = false;
        _groupPayerUpiFromApi[name] = null;
        _groupPayerChecking[name] = false;
      });
      return;
    }

    String normalized = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (normalized.startsWith('+')) normalized = normalized.substring(1);
    if (!normalized.startsWith('91') && normalized.length == 10) {
      normalized = '91$normalized';
    }

    setState(() => _groupPayerChecking[name] = true);
    final res = await AuthService.checkUserStatus(normalized);
    if (!mounted) return;

    bool isReg = false;
    String? upiId;
    if (res.data != null) {
      final raw = res.data!['is_register'];
      isReg = (raw == true) || (raw?.toString().toLowerCase() == 'true');
      final rawUpi = res.data!['upi_id'];
      if (rawUpi != null &&
          rawUpi.toString().isNotEmpty &&
          rawUpi.toString() != 'false') {
        upiId = rawUpi.toString();
      }
    }

    setState(() {
      _groupPayerChecking[name] = false;
      _groupPayerRegistered[name] = isReg;
      _groupPayerUpiFromApi[name] = upiId;
      if (upiId != null) _groupPayerUpiControllers[name]?.text = upiId;
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  bool _validate() {
    if (!_formKey.currentState!.validate()) return false;

    if (_paymentType == 'Solo Payment') {
      if (_soloPayer == null) {
        _snack('Please select who paid.');
        return false;
      }
    } else {
      if (_groupPayerIds.isEmpty) {
        _snack('Please select at least one payer.');
        return false;
      }
      // total amount is sum of payments in group mode
    }

    if (_selectedParticipants.isEmpty) {
      _snack('Select at least one person to split among.');
      return false;
    }

    if (_splitType == 'Percentage') {
      final pctSum = _selectedParticipants.fold<double>(
        0,
        (s, n) =>
            s + (double.tryParse(_percentControllers[n]?.text ?? '0') ?? 0),
      );
      if ((pctSum - 100).abs() > 0.1) {
        _snack(
          'Percentages must add up to 100% (currently ${pctSum.toStringAsFixed(1)}%)',
        );
        return false;
      }
    }

    if (_splitType == 'Custom') {
      final total = double.tryParse(_amountController.text) ?? 0;
      final cSum = _selectedParticipants.fold<double>(
        0,
        (s, n) =>
            s + (double.tryParse(_customControllers[n]?.text ?? '0') ?? 0),
      );
      if ((cSum - total).abs() > 0.1) {
        _snack(
          'Custom amounts (₹${cSum.toStringAsFixed(2)}) must equal expense total (₹${total.toStringAsFixed(2)}).',
        );
        return false;
      }
    }
    return true;
  }

  // ── Build participant payload ───────────────────────────────────────────────

  List<Map<String, dynamic>> _buildParticipantData(double totalAmount) {
    return _selectedParticipants.map((p) {
      final member = widget.group.members.firstWhere((m) => m.name == p);
      double amt;
      if (_splitType == 'Equal') {
        amt = totalAmount / _selectedParticipants.length;
      } else if (_splitType == 'Percentage') {
        final pct = double.tryParse(_percentControllers[p]?.text ?? '0') ?? 0;
        amt = totalAmount * pct / 100;
      } else {
        amt = double.tryParse(_customControllers[p]?.text ?? '0') ?? 0;
      }
      return {
        'name': p,
        'phone_number': member.phoneNumber ?? '',
        'expense_amount': amt,
      };
    }).toList();
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _addExpense() async {
    if (!_validate()) return;

    // ── Group Payment ──────────────────────────────────────────────
    if (_paymentType == 'Group Payment') {
      setState(() => _isLoading = true);
      double calculatedTotal = 0;
      final Map<String, double> paymentsByPhone = {};

      for (var name in _groupPayerIds) {
        final member = widget.group.members.firstWhere((m) => m.name == name);
        final phone = _normalize(member.phoneNumber ?? '');
        final amt =
            double.tryParse(_payerAmountControllers[name]?.text ?? '0') ?? 0;
        if (amt > 0 && phone.isNotEmpty) {
          paymentsByPhone[phone] = amt;
          calculatedTotal += amt;
        }
      }

      if (calculatedTotal <= 0) {
        setState(() => _isLoading = false);
        _snack('Total amount must be greater than 0');
        return;
      }

      final List<String> memberPhones = _selectedParticipants
          .map((name) {
            final member = widget.group.members.firstWhere(
              (m) => m.name == name,
            );
            return _normalize(member.phoneNumber ?? '');
          })
          .where((p) => p.isNotEmpty)
          .toList();

      final res = await GroupService.calculateOptimalSplit(
        totalAmount: calculatedTotal,
        members: memberPhones,
        payments: paymentsByPhone,
      );

      if (!mounted) return;

      if (res.success) {
        // Resolve names for transactions before showing
        final transactions = res.data['transactions'] as List<dynamic>? ?? [];
        final Set<String> allPhones = {};
        for (var tx in transactions) {
          allPhones.add(tx['from'] as String);
          allPhones.add(tx['to'] as String);
        }
        for (var p in allPhones) {
          await _getNameFromPhone(p);
        }
        setState(() {
          _isLoading = false;
          _settlementData = res.data;
        });
      } else {
        setState(() => _isLoading = false);
        _snack(res.message);
      }
      return;
    }

    // ── Solo Payment ───────────────────────────────────────────────
    setState(() => _isLoading = true);
    final totalAmount = double.parse(_amountController.text);
    final participantData = _buildParticipantData(totalAmount);
    final upi = _soloPayerUpiController.text.trim();
    final result = await GroupService.createSubGroup(
      widget.group.id,
      _nameController.text.trim(),
      'Paid by: $_soloPayer${upi.isNotEmpty ? " (UPI: $upi)" : ""}',
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

  Future<void> _confirmGroupExpense() async {
    if (_settlementData == null) return;
    if (_nameController.text.trim().isEmpty) {
      _snack('Please enter an expense name');
      return;
    }

    setState(() => _isLoading = true);

    double totalAmount = 0;
    final Map<String, double> paymentsByPhone = {};
    final Map<String, String> upiIds = {};

    for (var name in _groupPayerIds) {
      final member = widget.group.members.firstWhere((m) => m.name == name);
      final phone = _normalize(member.phoneNumber ?? '');
      final amt =
          double.tryParse(_payerAmountControllers[name]?.text ?? '0') ?? 0;
      if (phone.isNotEmpty) {
        if (amt > 0) {
          paymentsByPhone[phone] = amt;
          totalAmount += amt;
        }
        final manualUpi = _groupPayerUpiControllers[name]?.text.trim() ?? '';
        final apiUpi = _groupPayerUpiFromApi[name] ?? '';
        if (manualUpi.isNotEmpty) {
          upiIds[phone] = manualUpi;
        } else if (apiUpi.isNotEmpty) {
          upiIds[phone] = apiUpi;
        }
      }
    }

    final List<String> memberPhones = _selectedParticipants
        .map((name) {
          final member = widget.group.members.firstWhere((m) => m.name == name);
          return _normalize(member.phoneNumber ?? '');
        })
        .where((p) => p.isNotEmpty)
        .toList();

    final res = await GroupService.updateSplit(
      totalAmount: totalAmount,
      members: memberPhones,
      payments: paymentsByPhone,
      transactions: _settlementData!['transactions'] ?? [],
      groupId: widget.group.id,
      expenseName: _nameController.text.trim(),
      upiIds: upiIds.isNotEmpty ? upiIds : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context, true);
    } else {
      _snack(res.message);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final borderColor = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
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
              // ── Expense Details ──────────────────────────────────────
              _header('Expense Details', textColor),
              const SizedBox(height: 16),
              _card(
                surfaceColor,
                borderColor,
                Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(
                        hintText: 'Expense name (e.g. Dinner, Cab)',
                        border: InputBorder.none,
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'Enter expense name' : null,
                    ),
                    if (_paymentType == 'Solo Payment') ...[
                      Divider(color: borderColor),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(color: textColor),
                        decoration: const InputDecoration(
                          hintText: 'Amount (₹)',
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.currency_rupee_rounded,
                            size: 20,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (v!.isEmpty) return 'Enter amount';
                          if (double.tryParse(v) == null)
                            return 'Invalid number';
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Payment Type Toggle ──────────────────────────────────
              _header('Payment Type', textColor),
              const SizedBox(height: 16),
              _toggle(
                options: ['Solo Payment', 'Group Payment'],
                selected: _paymentType,
                surfaceColor: surfaceColor,
                subColor: subColor,
                onTap: (val) => setState(() {
                  _paymentType = val;
                  _settlementData = null;
                  _soloPayer = null;
                  _soloPayerIsRegistered = true;
                  _soloPayerUpiFromApi = null;
                  _soloPayerUpiController.clear();
                  _groupPayerIds.clear();
                  for (final n in _uniqueNames) {
                    if (!_selectedParticipants.contains(n))
                      _selectedParticipants.add(n);
                  }
                  for (var c in _payerAmountControllers.values) c.text = '';
                }),
              ),

              const SizedBox(height: 32),

              // ── SOLO: Paid By ────────────────────────────────────────
              if (_paymentType == 'Solo Payment') ...[
                _header('Paid By', textColor),
                const SizedBox(height: 16),
                _card(
                  surfaceColor,
                  borderColor,
                  Column(
                    children: [
                      DropdownButtonHideUnderline(
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
                          items: _uniqueNames
                              .map(
                                (name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() {
                              _soloPayer = val;
                              _soloPayerUpiController.clear();
                              _soloPayerIsRegistered = true;
                              _soloPayerUpiFromApi = null;
                              _selectedParticipants.remove(val);
                              for (final n in _uniqueNames) {
                                if (n != val &&
                                    !_selectedParticipants.contains(n)) {
                                  _selectedParticipants.add(n);
                                }
                              }
                            });
                            _checkSoloPayer(val);
                          },
                        ),
                      ),

                      // Status indicator
                      if (_soloPayer != null) ...[
                        Divider(color: borderColor),
                        if (_checkingStatus)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Checking status...',
                                  style: TextStyle(
                                    color: subColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  _soloPayerIsRegistered
                                      ? Icons.verified_user_rounded
                                      : Icons.person_off_rounded,
                                  color: _soloPayerIsRegistered
                                      ? AppColors.paid
                                      : AppColors.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _soloPayerIsRegistered
                                      ? (_soloPayerUpiFromApi != null
                                            ? 'UPI: $_soloPayerUpiFromApi'
                                            : 'Registered but no UPI linked')
                                      : 'Not registered on SplitEase',
                                  style: TextStyle(
                                    color: _soloPayerIsRegistered
                                        ? AppColors.paid
                                        : AppColors.error,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // UPI field: shown when NOT registered OR registered but no UPI
                          if (!_soloPayerIsRegistered ||
                              _soloPayerUpiFromApi == null) ...[
                            Divider(color: borderColor),
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _soloPayerUpiController,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: !_soloPayerIsRegistered
                                            ? 'Enter their UPI ID for payment'
                                            : 'Add a UPI ID for payment',
                                        hintStyle: TextStyle(
                                          color: subColor,
                                          fontSize: 13,
                                        ),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // ── GROUP: Who Paid (chips + amounts) ────────────────────
              if (_paymentType == 'Group Payment') ...[
                _header('Who Paid?', textColor),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _uniqueNames.map((name) {
                    final sel = _groupPayerIds.contains(name);
                    return _chip(
                      label: name,
                      selected: sel,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _groupPayerIds.add(name);
                            _selectedParticipants.remove(name);
                            // No longer auto-filling amount from _amountController as it might be hidden
                          } else {
                            _groupPayerIds.remove(name);
                            _payerAmountControllers[name]?.text = '';
                            _groupPayerUpiControllers[name]?.text = '';
                            _groupPayerRegistered.remove(name);
                            _groupPayerUpiFromApi.remove(name);
                            if (!_selectedParticipants.contains(name)) {
                              _selectedParticipants.add(name);
                            }
                          }
                        });
                        if (val) _checkGroupPayer(name);
                      },
                    );
                  }).toList(),
                ),
                if (_groupPayerIds.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _card(
                    surfaceColor,
                    borderColor,
                    Column(
                      children: _groupPayerIds.map((n) {
                        final isChecking = _groupPayerChecking[n] == true;
                        final isReg = _groupPayerRegistered[n];
                        final upiFromApi = _groupPayerUpiFromApi[n];
                        // Show UPI field if: not registered, OR registered but no UPI linked
                        final needsUpi =
                            isReg != null && (!isReg || upiFromApi == null);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    n,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 110,
                                    child: TextField(
                                      controller: _payerAmountControllers[n],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
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
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              // Status indicator
                              if (isChecking)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Checking...',
                                        style: TextStyle(
                                          color: subColor,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isReg != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isReg
                                            ? Icons.verified_user_rounded
                                            : Icons.person_off_rounded,
                                        color: isReg
                                            ? AppColors.paid
                                            : AppColors.error,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isReg
                                            ? (upiFromApi != null
                                                  ? 'UPI: $upiFromApi'
                                                  : 'No UPI linked')
                                            : 'Not on SplitEase',
                                        style: TextStyle(
                                          color: isReg
                                              ? AppColors.paid
                                              : AppColors.error,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // UPI input if needed
                              if (needsUpi)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.account_balance_wallet_rounded,
                                        color: AppColors.primary,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: TextField(
                                          controller:
                                              _groupPayerUpiControllers[n],
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 13,
                                          ),
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            hintText: isReg == false
                                                ? 'Enter UPI ID for payment'
                                                : 'Add UPI ID',
                                            hintStyle: TextStyle(
                                              color: subColor,
                                              fontSize: 12,
                                            ),
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (n != _groupPayerIds.last)
                                Divider(color: borderColor, height: 16),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],

              // ── Split Options (Solo Only) ──────────────────────────
              if (_paymentType == 'Solo Payment') ...[
                _header('Split Options', textColor),
                const SizedBox(height: 16),
                _toggle(
                  options: ['Equal', 'Percentage', 'Custom'],
                  selected: _splitType,
                  surfaceColor: surfaceColor,
                  subColor: subColor,
                  onTap: (val) => setState(() => _splitType = val),
                ),
                const SizedBox(height: 32),
              ],

              // ── Split Among ──────────────────────────────────────────
              Row(
                children: [
                  _header('Split Among', textColor),
                  const Spacer(),
                  Text(
                    '${_selectedParticipants.length} people',
                    style: TextStyle(color: subColor, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _uniqueNames.map((name) {
                  final isPayer = _paymentType == 'Solo Payment'
                      ? _soloPayer == name
                      : _groupPayerIds.contains(name);
                  if (isPayer) return const SizedBox.shrink();
                  final sel = _selectedParticipants.contains(name);
                  return _chip(
                    label: name,
                    selected: sel,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textColor: textColor,
                    onSelected: (val) => setState(() {
                      if (val)
                        _selectedParticipants.add(name);
                      else
                        _selectedParticipants.remove(name);
                    }),
                  );
                }).toList(),
              ),

              // ── Percentage inputs ────────────────────────────────────
              if (_splitType == 'Percentage' &&
                  _selectedParticipants.isNotEmpty) ...[
                const SizedBox(height: 16),
                _card(
                  surfaceColor,
                  borderColor,
                  Column(
                    children: [
                      ..._selectedParticipants.map((n) {
                        final controller = _percentControllers[n]!;
                        double currentVal =
                            double.tryParse(controller.text) ?? 0;
                        // Clamp for slider safety
                        double sliderVal = currentVal.clamp(0.0, 100.0);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    n,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: TextField(
                                      controller: controller,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 13,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        isDense: true,
                                        suffixText: '%',
                                        border: UnderlineInputBorder(),
                                      ),
                                      onChanged: (val) {
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  thumbShape: RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  overlayShape: RoundSliderOverlayShape(
                                    overlayRadius: 12,
                                  ),
                                ),
                                child: Slider(
                                  value: sliderVal,
                                  min: 0,
                                  max: 100,
                                  activeColor: AppColors.primary,
                                  inactiveColor: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      controller.text = val.toStringAsFixed(2);
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      Divider(color: borderColor),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: TextStyle(color: subColor, fontSize: 13),
                          ),
                          Builder(
                            builder: (_) {
                              final sum = _selectedParticipants.fold<double>(
                                0,
                                (s, n) =>
                                    s +
                                    (double.tryParse(
                                          _percentControllers[n]?.text ?? '0',
                                        ) ??
                                        0),
                              );
                              final ok = (sum - 100).abs() < 0.1;
                              return Text(
                                '${sum.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: ok ? AppColors.paid : AppColors.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // ── Custom amount inputs ──────────────────────────────────
              if (_splitType == 'Custom' &&
                  _selectedParticipants.isNotEmpty) ...[
                const SizedBox(height: 16),
                _card(
                  surfaceColor,
                  borderColor,
                  Column(
                    children: [
                      ..._selectedParticipants.map(
                        (n) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                n,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: TextField(
                                  controller: _customControllers[n],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
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
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(color: borderColor),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: TextStyle(color: subColor, fontSize: 13),
                          ),
                          Builder(
                            builder: (_) {
                              final sum = _selectedParticipants.fold<double>(
                                0,
                                (s, n) =>
                                    s +
                                    (double.tryParse(
                                          _customControllers[n]?.text ?? '0',
                                        ) ??
                                        0),
                              );
                              final target =
                                  double.tryParse(_amountController.text) ?? 0;
                              final ok = (sum - target).abs() < 0.1;
                              return Text(
                                '₹${sum.toStringAsFixed(2)} / ₹${target.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: ok ? AppColors.paid : AppColors.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),
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

              if (_paymentType == 'Group Payment' &&
                  _settlementData != null) ...[
                const SizedBox(height: 32),
                _header('Optimal Settlement Plan', textColor),
                const SizedBox(height: 6),
                Text(
                  'Minimum transactions needed to settle all debts:',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                _card(
                  surfaceColor,
                  borderColor,
                  Column(
                    children: [
                      if ((_settlementData!['transactions'] as List).isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'Everyone is settled up!',
                              style: TextStyle(color: textColor),
                            ),
                          ),
                        )
                      else
                        ...(_settlementData!['transactions'] as List).map((tx) {
                          final amount = (tx['amount'] as num).toDouble();
                          final fromPhone = tx['from'] as String;
                          final toPhone = tx['to'] as String;
                          final fromName =
                              _phoneToNameCache[fromPhone] ?? fromPhone;
                          final toName = _phoneToNameCache[toPhone] ?? toPhone;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fromName,
                                        style: TextStyle(
                                          color: AppColors.error,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        fromPhone,
                                        style: TextStyle(
                                          color: AppColors.error.withValues(
                                            alpha: 0.6,
                                          ),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        toName,
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          color: AppColors.paid,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        toPhone,
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          color: AppColors.paid.withValues(
                                            alpha: 0.6,
                                          ),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '₹${amount.toStringAsFixed(2)}',
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
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : AppButton(
                        label: 'Confirm and Save Expense',
                        onPressed: _confirmGroupExpense,
                      ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widget helpers ────────────────────────────────────────────────────────

  Widget _header(String t, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(
      t,
      style: TextStyle(
        color: c,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),
  );

  Widget _card(Color bg, Color border, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      border: Border.all(color: border),
    ),
    child: child,
  );

  Widget _toggle({
    required List<String> options,
    required String selected,
    required Color surfaceColor,
    required Color subColor,
    required void Function(String) onTap,
  }) => Container(
    decoration: BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
    ),
    child: Row(
      children: options.map((opt) {
        final isSel = opt == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onTap(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: isSel ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isSel ? Colors.white : subColor,
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
  );

  FilterChip _chip({
    required String label,
    required bool selected,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required void Function(bool) onSelected,
  }) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: onSelected,
    backgroundColor: surfaceColor,
    selectedColor: AppColors.primary.withValues(alpha: 0.15),
    checkmarkColor: AppColors.primary,
    labelStyle: TextStyle(
      color: selected ? AppColors.primary : textColor,
      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: selected ? AppColors.primary : borderColor),
    ),
  );
}
