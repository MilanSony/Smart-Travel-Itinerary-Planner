import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/budget_model.dart';
import '../models/split_budget_model.dart';
import '../services/split_budget_service.dart';

class NameEditDialog extends StatefulWidget {
  final SplitTraveler traveler;
  final bool isGroup;

  const NameEditDialog({
    super.key,
    required this.traveler,
    required this.isGroup,
  });

  @override
  State<NameEditDialog> createState() => _NameEditDialogState();
}

class MemberEditResult {
  final String name;
  final TravelerType type;
  final String? upiId;

  const MemberEditResult({
    required this.name,
    required this.type,
    this.upiId,
  });
}

class _NameEditDialogState extends State<NameEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _upiController;
  late TravelerType _type;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.traveler.name);
    _upiController = TextEditingController(text: widget.traveler.upiId ?? '');
    _type = widget.traveler.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit member'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Milan',
              ),
            ),
            if (widget.isGroup) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _upiController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'UPI ID (optional)',
                  hintText: 'milan@okaxis',
                  helperText: 'Others can pay you from Settle',
                ),
              ),
            ],
            if (!widget.isGroup) ...[
              const SizedBox(height: 12),
              DropdownButton<TravelerType>(
                isExpanded: true,
                value: _type,
                items: TravelerType.values
                    .map(
                      (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final upi = _upiController.text.trim();
            Navigator.pop<MemberEditResult>(
              context,
              MemberEditResult(
                name: name.isEmpty ? widget.traveler.name : name,
                type: _type,
                upiId: upi.isEmpty ? null : upi,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class ExpenseEditOutcome {
  final TripExpense? expense;
  final bool deleted;

  const ExpenseEditOutcome.saved(this.expense) : deleted = false;
  const ExpenseEditOutcome.deleted()
      : expense = null,
        deleted = true;
}

class ExpenseEditorSheet extends StatefulWidget {
  final TripExpense expense;
  final bool isNew;
  final List<SplitTraveler> travelers;
  final SplitBudgetService service;

  const ExpenseEditorSheet({
    super.key,
    required this.expense,
    required this.isNew,
    required this.travelers,
    required this.service,
  });

  @override
  State<ExpenseEditorSheet> createState() => _ExpenseEditorSheetState();
}

class _ExpenseEditorSheetState extends State<ExpenseEditorSheet> {
  static const _accent = Color(0xFF6C5CE7);
  static const _muted = Color(0xFF6B7280);

  late final TextEditingController _descController;
  late final TextEditingController _amountController;
  late BudgetCategory _category;
  late SplitRule _splitRule;
  String? _paidBy;
  late Set<String> _involved;
  final Map<String, TextEditingController> _customControllers = {};
  bool _syncingFields = false;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _descController = TextEditingController(text: expense.description);
    _amountController = TextEditingController(
      text: expense.amount > 0 ? expense.amount.toStringAsFixed(0) : '',
    );
    _category = expense.category;
    _splitRule = expense.splitRule;
    _paidBy = expense.paidByTravelerId;
    _involved = Set<String>.from(expense.involvedTravelerIds);
    for (final t in widget.travelers) {
      final existing = expense.customOwedAmounts[t.id];
      _customControllers[t.id] = TextEditingController(
        text: existing != null && existing > 0 ? existing.toStringAsFixed(0) : '',
      );
    }
    _amountController.addListener(_onAmountsChanged);
    for (final c in _customControllers.values) {
      c.addListener(_onAmountsChanged);
    }
  }

  void _onAmountsChanged() {
    if (_syncingFields || !mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountsChanged);
    _amountController.dispose();
    _descController.dispose();
    for (final c in _customControllers.values) {
      c.removeListener(_onAmountsChanged);
      c.dispose();
    }
    super.dispose();
  }

  String _formatMoney(double amount) =>
      '\u20B9${NumberFormat('#,##,###').format(amount.round())}';

  List<SplitTraveler> get _debtors => widget.travelers
      .where((t) => _involved.contains(t.id) && t.id != _paidBy)
      .toList();

  double get _totalAmount => double.tryParse(_amountController.text) ?? 0;

  double get _sumAssignedToOthers {
    var sum = 0.0;
    for (final d in _debtors) {
      sum += double.tryParse(_customControllers[d.id]?.text ?? '') ?? 0;
    }
    return sum;
  }

  double get _payerShare =>
      (_totalAmount - _sumAssignedToOthers).clamp(0.0, _totalAmount).toDouble();

  void _applyEqualSplit() {
    if (_totalAmount <= 0 || _involved.isEmpty) return;
    final temp = widget.expense.copyWith(
      amount: _totalAmount,
      splitRule: SplitRule.equal,
      involvedTravelerIds: _involved.toList(),
    );
    final equalMap = widget.service.buildEqualOwedAmounts(
      expense: temp,
      allTravelers: widget.travelers,
    );
    _syncingFields = true;
    for (final d in _debtors) {
      final v = equalMap[d.id] ?? 0;
      _customControllers[d.id]?.text = v > 0 ? v.toStringAsFixed(0) : '';
    }
    _syncingFields = false;
  }

  Map<String, double> _readCustomMap() {
    final map = <String, double>{};
    for (final d in _debtors) {
      final v = double.tryParse(_customControllers[d.id]?.text ?? '');
      if (v != null && v > 0) map[d.id] = v;
    }
    if (_paidBy != null && _payerShare > 0) {
      map[_paidBy!] = _payerShare;
    }
    return map;
  }

  void _save() {
    final amount = double.tryParse(_amountController.text);
    if (_descController.text.trim().isEmpty ||
        amount == null ||
        amount <= 0 ||
        _involved.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter description, amount, and at least one member'),
        ),
      );
      return;
    }
    if (_paidBy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select who paid this bill')),
      );
      return;
    }

    late final Map<String, double> customMap;
    var savedRule = _splitRule;
    if (_splitRule == SplitRule.equal) {
      final temp = widget.expense.copyWith(
        amount: amount,
        splitRule: SplitRule.equal,
        involvedTravelerIds: _involved.toList(),
        paidByTravelerId: _paidBy,
      );
      customMap = widget.service.buildEqualOwedAmounts(
        expense: temp,
        allTravelers: widget.travelers,
      );
    } else {
      customMap = _readCustomMap();
      final othersSum = customMap.entries
          .where((e) => e.key != _paidBy)
          .fold<double>(0, (s, e) => s + e.value);
      if (othersSum <= 0 && _involved.length > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter how much each person owes the payer'),
          ),
        );
        return;
      }
      if (othersSum > amount + 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assigned amounts exceed the total bill')),
        );
        return;
      }
      savedRule = SplitRule.custom;
    }

    Navigator.pop(
      context,
      ExpenseEditOutcome.saved(
        widget.expense.copyWith(
          description: _descController.text.trim(),
          category: _category,
          amount: amount,
          splitRule: savedRule,
          paidByTravelerId: _paidBy,
          involvedTravelerIds: _involved.toList(),
          customOwedAmounts: customMap,
          fromEstimation: widget.isNew ? false : widget.expense.fromEstimation,
        ),
      ),
    );
  }

  String _categoryLabel(BudgetCategory c) {
    switch (c) {
      case BudgetCategory.accommodation:
        return 'Accommodation';
      case BudgetCategory.food:
        return 'Food & Dining';
      case BudgetCategory.transportation:
        return 'Transportation';
      case BudgetCategory.activities:
        return 'Activities';
      case BudgetCategory.shopping:
        return 'Shopping';
      case BudgetCategory.emergency:
        return 'Emergency';
      case BudgetCategory.miscellaneous:
        return 'Miscellaneous';
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    String? payerName;
    for (final t in widget.travelers) {
      if (t.id == _paidBy) {
        payerName = t.name;
        break;
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.88,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.isNew ? 'Record expense' : 'Edit expense',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
                      TextField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'e.g. Dinner bill',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total bill amount (\u20B9)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: const InputDecoration(labelText: 'Category'),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<BudgetCategory>(
                            isExpanded: true,
                            value: _category,
                            items: BudgetCategory.values
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(_categoryLabel(c)),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _category = v;
                                if (v == BudgetCategory.food ||
                                    v == BudgetCategory.accommodation) {
                                  _splitRule = SplitRule.custom;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Who paid this bill?',
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            value: _paidBy,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Not assigned yet'),
                              ),
                              ...widget.travelers.map(
                                (t) => DropdownMenuItem<String?>(
                                  value: t.id,
                                  child: Text(t.name),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _paidBy = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Who is this expense for?',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Uncheck anyone who should not share this bill.',
                        style: TextStyle(fontSize: 12, color: _muted),
                      ),
                      ...widget.travelers.map(
                        (t) => CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(t.name),
                          value: _involved.contains(t.id),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _involved.add(t.id);
                              } else {
                                _involved.remove(t.id);
                                if (_paidBy == t.id) _paidBy = null;
                              }
                            });
                          },
                        ),
                      ),
                      if (_paidBy != null && _involved.length > 1) ...[
                        const Divider(height: 24),
                        const Text(
                          'Split this bill',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Enter the exact amount each member owes the payer.',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<SplitRule>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: SplitRule.custom,
                              label: Text('Custom'),
                            ),
                            ButtonSegment(
                              value: SplitRule.equal,
                              label: Text('Equal'),
                            ),
                          ],
                          selected: {_splitRule},
                          onSelectionChanged: (s) {
                            setState(() {
                              _splitRule = s.first;
                              if (_splitRule == SplitRule.equal) {
                                _applyEqualSplit();
                              }
                            });
                          },
                        ),
                        if (_splitRule == SplitRule.equal)
                          TextButton.icon(
                            onPressed: () {
                              _applyEqualSplit();
                              setState(() {});
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Recalculate equal split'),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Amount owed to ${payerName ?? 'the payer'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (_debtors.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Only the payer is involved — no split needed.',
                              style: TextStyle(fontSize: 12, color: _muted),
                            ),
                          )
                        else
                          ..._debtors.map(
                            (d) => Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: TextField(
                                controller: _customControllers[d.id],
                                keyboardType: TextInputType.number,
                                enabled: _splitRule == SplitRule.custom ||
                                    _debtors.length == 1,
                                decoration: InputDecoration(
                                  labelText: '${d.name} owes (\u20B9)',
                                  prefixIcon: const Icon(Icons.person_outline),
                                ),
                              ),
                            ),
                          ),
                        if (_totalAmount > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${payerName ?? 'Payer'}'s own share: ${_formatMoney(_payerShare)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF312E81),
                                  ),
                                ),
                                Text(
                                  'Assigned to others: ${_formatMoney(_sumAssignedToOthers)} / ${_formatMoney(_totalAmount)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF4338CA),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      if (!widget.isNew)
                        TextButton(
                          onPressed: () => Navigator.pop(
                            context,
                            const ExpenseEditOutcome.deleted(),
                          ),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(backgroundColor: _accent),
                        child: Text(widget.isNew ? 'Add' : 'Save'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
