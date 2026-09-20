import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/budget_model.dart';
import '../models/itinerary_model.dart';
import '../models/split_budget_model.dart';
import '../services/split_budget_service.dart';
import 'split_expense_editor.dart';
import 'upi_payment_screen.dart';

class SplitBudgetScreen extends StatefulWidget {
  final BudgetEstimation estimation;
  final Itinerary? itinerary;

  const SplitBudgetScreen({
    super.key,
    required this.estimation,
    this.itinerary,
  });

  @override
  State<SplitBudgetScreen> createState() => _SplitBudgetScreenState();
}

class _SplitBudgetScreenState extends State<SplitBudgetScreen> {
  static const _primary = Color(0xFF1E3A5F);
  static const _accent = Color(0xFF6C5CE7);
  static const _surface = Colors.white;
  static const _border = Color(0xFFE5E7EB);
  static const _muted = Color(0xFF6B7280);

  final SplitBudgetService _service = SplitBudgetService();

  TripSplitMode _tripMode = TripSplitMode.group;
  List<SplitTraveler> _travelers = [];
  List<TripExpense> _expenses = [];
  final Set<String> _settledShareKeys = {};
  int _currentTab = 0;
  bool _budgetBreakdownExpanded = true;
  bool _loading = true;

  String get _storageKey => _service.storageKey(
        estimation: widget.estimation,
        itinerary: widget.itinerary,
      );

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final saved = await _service.loadSnapshot(_storageKey);
    if (!mounted) return;

    if (saved != null) {
      _tripMode = saved.tripMode;
      _travelers = List<SplitTraveler>.from(saved.travelers);
      _settledShareKeys
        ..clear()
        ..addAll(saved.settledShareKeys);
      final imported = _service.importFromEstimation(
        widget.estimation,
        _travelers,
      );
      _expenses = _service.mergeSavedExpenses(
        saved: saved.expenses,
        fromEstimation: imported,
      );
    } else {
      _tripMode = _service.suggestTripMode(widget.itinerary);
      _travelers = _service.createDefaultTravelers(
        travelerCount: widget.estimation.travelers,
        itinerary: widget.itinerary,
      );
      _expenses = _service.importFromEstimation(widget.estimation, _travelers);
    }

    setState(() => _loading = false);
    unawaited(_persist());
  }

  Future<void> _persist() async {
    if (_loading || _travelers.isEmpty) return;
    await _service.saveSnapshot(
      _storageKey,
      SplitBudgetSnapshot(
        tripMode: _tripMode,
        travelers: List<SplitTraveler>.from(_travelers),
        expenses: List<TripExpense>.from(_expenses),
        settledShareKeys: Set<String>.from(_settledShareKeys),
      ),
    );
  }

  void _commit(VoidCallback fn) {
    setState(fn);
    unawaited(_persist());
  }

  @override
  void dispose() {
    unawaited(_persist());
    super.dispose();
  }

  List<ExpenseShareOwed> get _owedShares => _service.calculateOwedShares(
        travelers: _travelers,
        expenses: _expenses,
      );

  List<TravelerBalance> get _balances => _service.calculateBalances(
        travelers: _travelers,
        expenses: _expenses,
        settledShareKeys: _settledShareKeys,
      );

  List<SettlementSuggestion> get _settlements =>
      _service.suggestSettlements(_balances);

  String _formatMoney(double amount) =>
      '\u20B9${NumberFormat('#,##,###').format(amount.round())}';

  String _formatDateRange() {
    final fmt = DateFormat('d MMM yyyy');
    return '${fmt.format(widget.estimation.startDate)} \u2013 ${fmt.format(widget.estimation.endDate)}';
  }

  void _setTripMode(TripSplitMode mode) {
    if (_tripMode == mode) return;
    _commit(() {
      _tripMode = mode;
      _currentTab = 0;
    });
  }

  void _toggleShareSettled(String key) {
    _commit(() {
      if (_settledShareKeys.contains(key)) {
        _settledShareKeys.remove(key);
      } else {
        _settledShareKeys.add(key);
      }
    });
  }

  List<TripExpense> get _paidExpenses =>
      _expenses.where((e) => e.paidByTravelerId != null).toList();

  int get _tripDays =>
      widget.estimation.endDate.difference(widget.estimation.startDate).inDays + 1;

  @override
  Widget build(BuildContext context) {
    final isGroup = _tripMode == TripSplitMode.group;
    final tabs = isGroup
        ? const ['Members', 'Expenses', 'Settle']
        : const ['Budget', 'Members'];
    final tabIndex = _currentTab.clamp(0, tabs.length - 1);

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F5FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        unawaited(_persist());
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Split & Settle',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          _buildBudgetOverviewCard(),
          const SizedBox(height: 14),
          _buildTripTypeSelector(),
          const SizedBox(height: 14),
          _buildTabPills(tabs, tabIndex),
          const SizedBox(height: 18),
          ..._tabBody(isGroup, tabIndex),
        ],
      ),
      floatingActionButton: isGroup && tabIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _showAddExpenseDialog,
              backgroundColor: _accent,
              elevation: 4,
              icon: const Icon(Icons.add),
              label: const Text('Record expense'),
            )
          : null,
      ),
    );
  }

  List<Widget> _tabBody(bool isGroup, int tabIndex) {
    if (!isGroup) {
      return tabIndex == 0
          ? _buildFamilyOverviewContent()
          : _buildMembersContent(isGroup: false);
    }
    switch (tabIndex) {
      case 1:
        return _buildExpensesContent();
      case 2:
        return _buildSettlementContent();
      default:
        return _buildMembersContent(isGroup: true);
    }
  }

  Widget _buildTabPills(List<String> tabs, int tabIndex) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECF4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _currentTab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: tabIndex == i ? _surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: tabIndex == i
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    tabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: tabIndex == i ? _primary : _muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _proCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _primary,
              letterSpacing: -0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: _muted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTripTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TRIP TYPE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _muted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: TripSplitMode.values.map((mode) {
            final selected = _tripMode == mode;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: mode == TripSplitMode.family ? 6 : 0,
                  left: mode == TripSplitMode.group ? 6 : 0,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _setTripMode(mode),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: selected
                            ? const LinearGradient(
                                colors: [Color(0xFF6C5CE7), Color(0xFF8B7CF6)],
                              )
                            : null,
                        color: selected ? null : _surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? Colors.transparent : _border,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: _accent.withValues(alpha: 0.28),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            mode.icon,
                            size: 20,
                            color: selected ? Colors.white : _muted,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              mode.label,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: selected ? Colors.white : _primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          _tripMode.subtitle,
          style: const TextStyle(fontSize: 12, color: _muted, height: 1.35),
        ),
      ],
    );
  }

  Widget _buildBudgetOverviewCard() {
    final est = widget.estimation;
    final categories = est.categoryBreakdown.where((c) => c.estimatedCost > 0).toList();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [_primary, const Color(0xFF2C5282)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.map_outlined, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        est.destination,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateRange(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '$_tripDays days · ${est.travelers} travellers · ${_tripMode.label}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated trip budget',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatMoney(est.estimatedTotalCost),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  est.travelers > 1
                      ? '~${_formatMoney(est.estimatedTotalCost / est.travelers)} per person · ${_formatMoney(est.estimatedTotalCost / _tripDays)} per day'
                      : '${_formatMoney(est.estimatedTotalCost / _tripDays)} per day',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _budgetChip('Your limit', _formatMoney(est.totalBudget)),
                _budgetChip('Min', _formatMoney(est.minTotalCost)),
                _budgetChip('Max', _formatMoney(est.maxTotalCost)),
                _budgetChip(
                  'Status',
                  est.budgetVariance >= 0 ? 'On track' : 'Over budget',
                  color: est.budgetVariance >= 0
                      ? const Color(0xFF34D399)
                      : const Color(0xFFFCA5A5),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(
                    () => _budgetBreakdownExpanded = !_budgetBreakdownExpanded,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.pie_chart_outline, size: 18, color: _accent),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Budget breakdown by category',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _primary,
                            ),
                          ),
                        ),
                        Icon(
                          _budgetBreakdownExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: _muted,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_budgetBreakdownExpanded) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (categories.isEmpty)
                          const Text(
                            'Generate budget in Budget Estimator for category details.',
                            style: TextStyle(fontSize: 13, color: _muted),
                          )
                        else
                          ...categories.map((c) => _buildBudgetCategoryRow(c)),
                        const SizedBox(height: 8),
                        Text(
                          est.formattedVariance,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: est.budgetVariance >= 0
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetChip(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksSteps() {
    const steps = [
      ('1', 'Add members', 'Name everyone on the trip'),
      ('2', 'Record expenses', 'Payer logs bill & owed amounts'),
      ('3', 'Settle up', 'Mark paid when money is returned'),
    ];
    return _proCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How it works',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: _primary,
            ),
          ),
          const SizedBox(height: 14),
          ...steps.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accent, _accent.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      s.$1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.$2,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _primary,
                          ),
                        ),
                        Text(
                          s.$3,
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCategoryRow(CostBreakdown c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_categoryIcon(c.category), size: 18, color: _accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.categoryName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${c.percentage.toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatMoney(c.estimatedCost),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (c.percentage / 100).clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: const Color(0xFFE5E7EB),
                    color: _accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(BudgetCategory category) {
    switch (category) {
      case BudgetCategory.accommodation:
        return Icons.hotel_rounded;
      case BudgetCategory.food:
        return Icons.restaurant_rounded;
      case BudgetCategory.transportation:
        return Icons.directions_car_rounded;
      case BudgetCategory.activities:
        return Icons.local_activity_rounded;
      case BudgetCategory.shopping:
        return Icons.shopping_bag_rounded;
      case BudgetCategory.emergency:
        return Icons.health_and_safety_rounded;
      case BudgetCategory.miscellaneous:
        return Icons.more_horiz_rounded;
    }
  }

  List<Widget> _buildFamilyOverviewContent() {
    final est = widget.estimation;
    final days = est.dailyBudgets;

    return [
      _proCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_outline, color: Color(0xFF059669)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shared family budget',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: _primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Costs are not split between family members. Use the figures above as your spending guide.',
                    style: TextStyle(fontSize: 13, color: _muted, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _proCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Budget snapshot',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _primary),
            ),
            const SizedBox(height: 12),
            _kvRow('Estimated total', _formatMoney(est.estimatedTotalCost)),
            _kvRow('Your limit', _formatMoney(est.totalBudget)),
            _kvRow('Duration', '$_tripDays days'),
            _kvRow('Daily average', _formatMoney(est.estimatedTotalCost / _tripDays)),
            _kvRow('Travelers', '${est.travelers}'),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (est.budgetUtilization / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: const Color(0xFFE5E7EB),
                color: est.budgetVariance >= 0
                    ? const Color(0xFF059669)
                    : const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${est.budgetUtilization.toStringAsFixed(0)}% of limit used · ${est.formattedVariance}',
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
      ),
      if (days.isNotEmpty) ...[
        _sectionTitle('Daily estimates'),
        ...days.take(7).map(
          (d) => _proCard(
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18, color: _accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    DateFormat('EEE, d MMM').format(d.date),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: _primary),
                  ),
                ),
                Text(
                  _formatMoney(d.estimatedCost),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: _primary),
                ),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  Widget _kvRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, color: _muted)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _primary,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMembersContent({required bool isGroup}) {
    return [
      if (isGroup) ...[
        _buildHowItWorksSteps(),
        const SizedBox(height: 4),
      ],
      _sectionTitle(
        isGroup ? 'Group members' : 'Family members',
        subtitle: isGroup
            ? '${_travelers.length} people on this trip'
            : 'Names for reference only on family trips.',
      ),
      if (isGroup)
        ..._travelers.map((t) => _buildMemberCard(t, _balanceFor(t.id), isGroup))
      else
        ..._travelers.map((t) => _buildMemberCard(t, null, isGroup)),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _addTraveler,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: _accent),
            foregroundColor: _accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.person_add_outlined, size: 20),
          label: Text(isGroup ? 'Add member' : 'Add family member'),
        ),
      ),
    ];
  }

  List<Widget> _buildExpensesContent() {
    final paid = _paidExpenses;
    final unpaid = _expenses.where((e) => e.paidByTravelerId == null).toList();
    final owed = _owedShares;

    return [
      _sectionTitle(
        'Expense records',
        subtitle:
            'Select who paid, then enter the exact amount each member owes them.',
      ),
      if (paid.isEmpty)
        _proCard(
          child: Row(
            children: [
              Icon(Icons.receipt_long_outlined, color: Colors.amber.shade800),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'No expenses recorded yet. Tap "Set up" below or use Record expense.',
                  style: TextStyle(fontSize: 13, color: _muted, height: 1.4),
                ),
              ),
            ],
          ),
        )
      else ...[
        _sectionHeader('Paid expenses', Icons.check_circle_outline),
        const SizedBox(height: 8),
        ...paid.map((e) => _buildPaidExpenseCard(e, owed)),
      ],
      if (unpaid.isNotEmpty) ...[
        const SizedBox(height: 8),
        _sectionHeader('Pending \u2014 assign payer', Icons.schedule),
        const SizedBox(height: 8),
        ...unpaid.map((e) => _buildUnpaidExpenseCard(e)),
      ],
    ];
  }

  List<Widget> _buildSettlementContent() {
    final owed = _owedShares;
    final settledCount = _service.countSettledShares(owed, _settledShareKeys);
    final unsettledCount = _service.countUnsettledShares(owed, _settledShareKeys);
    final balances = _balances;
    final settlements = _settlements;
    final hasPayments = _service.hasAnyPayments(_expenses);

    return [
      _proCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _settlementStat('Paid back', settledCount, const Color(0xFF059669)),
            _settlementStat('Outstanding', unsettledCount, const Color(0xFFD97706)),
            _settlementStat('Members', _travelers.length, _accent),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (!hasPayments)
        _proCard(
          child: const Text(
            'Record expenses on the Expenses tab first.',
            style: TextStyle(fontSize: 13, color: _muted, height: 1.4),
          ),
        ),
      if (hasPayments) ...[
        _sectionTitle(
          'Member balances',
          subtitle: 'Paid upfront vs. total owed across all expenses.',
        ),
        ...balances.map((b) => _buildBalanceCard(b)),
        const SizedBox(height: 16),
        _sectionTitle(
          'Payment summary',
          subtitle: 'Tap Pay UPI to pay in-app with PIN, like ride booking.',
        ),
        const SizedBox(height: 8),
        if (unsettledCount == 0 && owed.isNotEmpty)
          _proCard(
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'All outstanding amounts marked as paid.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (settlements.isEmpty && owed.isNotEmpty)
          const Text(
            'Mark each amount as paid on the Expenses tab.',
            style: TextStyle(fontSize: 13, color: _muted),
          )
        else
          ...settlements.map((s) => _buildSettlementCard(s)),
      ],
    ];
  }

  TravelerBalance? _balanceFor(String travelerId) {
    for (final b in _balances) {
      if (b.traveler.id == travelerId) return b;
    }
    return null;
  }

  Color _avatarColor(int index) {
    const colors = [
      Color(0xFF6C5CE7),
      Color(0xFF4A90E2),
      Color(0xFF26A69A),
      Color(0xFFFF6B35),
      Color(0xFF9C27B0),
    ];
    return colors[index % colors.length];
  }

  Widget _buildMemberCard(
    SplitTraveler traveler,
    TravelerBalance? balance,
    bool isGroup,
  ) {
    final index = _travelers.indexWhere((t) => t.id == traveler.id);
    final avatarColor = _avatarColor(index < 0 ? 0 : index);

    return _proCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  avatarColor,
                  avatarColor.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: avatarColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              traveler.name.isNotEmpty ? traveler.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  traveler.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 2),
                if (!isGroup)
                  Text(
                    '${traveler.type.label} · shared family budget',
                    style: const TextStyle(fontSize: 12, color: _muted),
                  )
                else if (balance != null && _service.hasAnyPayments(_expenses))
                  _buildMemberBalanceLine(balance)
                else
                  Text(
                    traveler.upiId != null && traveler.upiId!.isNotEmpty
                        ? traveler.upiId!
                        : 'Add UPI ID to receive payments',
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: _muted, size: 20),
            onPressed: () => _showEditTravelerDialog(traveler, isGroup),
          ),
          if (_travelers.length > 1)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFDC2626), size: 20),
              tooltip: 'Remove',
              onPressed: () => _removeTraveler(traveler.id),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberBalanceLine(TravelerBalance balance) {
    if (balance.isSettled) {
      return const Text(
        'All settled',
        style: TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w500),
      );
    }
    if (balance.isCreditor) {
      return Text(
        'To receive ${_formatMoney(balance.balance)}',
        style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w600),
      );
    }
    if (balance.isDebtor) {
      return Text(
        'Owes ${_formatMoney(balance.fairShare)} · Paid ${_formatMoney(balance.paid)}',
        style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
      );
    }
    return Text(
      'Paid ${_formatMoney(balance.paid)}',
      style: const TextStyle(fontSize: 12, color: _muted),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _primary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaidExpenseCard(
    TripExpense expense,
    List<ExpenseShareOwed> owed,
  ) {
    final payer = _service.travelerById(_travelers, expense.paidByTravelerId!);
    final expenseOwed = owed.where((o) => o.expenseId == expense.id).toList();
    final splitComplete = _service.expenseSplitIsComplete(expense);
    final payerShare = _service.payerOwnShare(
      expense: expense,
      allTravelers: _travelers,
    );

    return _proCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.description.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatMoney(expense.amount),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _primary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showExpenseEditor(expense),
                  child: const Text('Edit'),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF059669).withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.account_circle_outlined,
                    size: 18, color: Color(0xFF059669)),
                const SizedBox(width: 8),
                Text(
                  'Paid by ${payer?.name ?? 'Unknown'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
          if (!splitComplete)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Text(
                  'Enter how much each member owes ${payer?.name ?? 'the payer'}.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                ),
              ),
            )
          else if (expenseOwed.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Amounts owed to ${payer?.name}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ),
            ...expenseOwed.map((share) => _buildOwedRow(share)),
          ] else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${payer?.name ?? 'Payer'} covered this expense alone.',
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
            ),
          if (payerShare > 0.01 && splitComplete)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                "${payer?.name}'s own portion: ${_formatMoney(payerShare)}",
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOwedRow(ExpenseShareOwed share) {
    final settled = _settledShareKeys.contains(share.settlementKey);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: settled
            ? const Color(0xFFECFDF5)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: settled ? const Color(0xFF6EE7B7) : _border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  share.debtorName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: settled ? _muted : _primary,
                    decoration: settled ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  settled ? 'Payment received' : 'Owes ${share.payerName}',
                  style: TextStyle(
                    fontSize: 11,
                    color: settled ? const Color(0xFF059669) : _muted,
                  ),
                ),
                if (!settled)
                  TextButton(
                    onPressed: () => _payShareWithUpi(share),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      alignment: Alignment.centerLeft,
                    ),
                    child: const Text('Pay UPI'),
                  ),
              ],
            ),
          ),
          Text(
            _formatMoney(share.amount),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: settled ? _muted : _primary,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _toggleShareSettled(share.settlementKey),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: settled
                    ? const Color(0xFF059669)
                    : _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                settled ? 'Paid' : 'Mark paid',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: settled ? Colors.white : _accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnpaidExpenseCard(TripExpense expense) {
    return _proCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.receipt_outlined, color: _muted, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatMoney(expense.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _accent,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Assign payer and enter owed amounts',
                  style: TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
          Flexible(
            child: FilledButton(
              onPressed: () => _showExpenseEditor(expense),
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: const Text('Set up'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settlementStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
      ],
    );
  }

  Widget _buildBalanceCard(TravelerBalance balance) {
    final color = balance.isCreditor
        ? const Color(0xFF059669)
        : balance.isDebtor
            ? const Color(0xFFDC2626)
            : _muted;

    final statusLabel = balance.isCreditor
        ? 'To receive'
        : balance.isDebtor
            ? 'Outstanding'
            : 'Settled';

    return _proCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(
              balance.traveler.name.isNotEmpty
                  ? balance.traveler.name[0].toUpperCase()
                  : '?',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  balance.traveler.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Paid ${_formatMoney(balance.paid)} · Owes ${_formatMoney(balance.fairShare)}',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                balance.isSettled
                    ? '\u2014'
                    : '${balance.balance >= 0 ? '+' : ''}${_formatMoney(balance.balance.abs())}',
                style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 15),
              ),
              Text(statusLabel, style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementCard(SettlementSuggestion s) {
    return _proCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_forward, color: _accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.fromName} \u2192 ${s.toName}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: _primary),
                ),
                const Text(
                  'Suggested transfer',
                  style: TextStyle(fontSize: 11, color: _muted),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _paySettlementWithUpi(s),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                  label: const Text('Pay UPI'),
                ),
              ],
            ),
          ),
          Text(
            _formatMoney(s.amount),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: _accent,
            ),
          ),
        ],
      ),
    );
  }

  void _removeTraveler(String id) {
    if (_travelers.length <= 1) return;
    _commit(() {
      _travelers.removeWhere((t) => t.id == id);
      _expenses = _expenses
          .map(
            (e) => e.copyWith(
              involvedTravelerIds:
                  e.involvedTravelerIds.where((tid) => tid != id).toList(),
              clearPaidBy: e.paidByTravelerId == id,
              customOwedAmounts: Map.from(e.customOwedAmounts)..remove(id),
            ),
          )
          .where((e) => e.involvedTravelerIds.isNotEmpty || e.fromEstimation)
          .toList();
      _settledShareKeys.removeWhere((k) => k.contains(id));
    });
  }

  void _addTraveler() {
    final id = 'traveler_${DateTime.now().millisecondsSinceEpoch}';
    _commit(() {
      _travelers.add(
        SplitTraveler(
          id: id,
          name: 'Member ${_travelers.length + 1}',
        ),
      );
      _expenses = _expenses
          .map(
            (e) => e.copyWith(
              involvedTravelerIds: [...e.involvedTravelerIds, id],
            ),
          )
          .toList();
    });
  }

  Future<void> _showEditTravelerDialog(
    SplitTraveler traveler,
    bool isGroup,
  ) async {
    final result = await showDialog<MemberEditResult>(
      context: context,
      builder: (ctx) => NameEditDialog(
        traveler: traveler,
        isGroup: isGroup,
      ),
    );
    if (!mounted || result == null) return;
    final idx = _travelers.indexWhere((t) => t.id == traveler.id);
    if (idx < 0) return;
    _commit(() {
      _travelers[idx] = traveler.copyWith(
        name: result.name,
        type: result.type,
        upiId: result.upiId,
        clearUpiId: result.upiId == null,
      );
    });
  }

  Future<bool> _openSplitUpiCheckout({
    required String fromName,
    required String toName,
    required double amount,
    required String purpose,
  }) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UpiPaymentScreen(
          amount: amount,
          purposeLabel: purpose,
          successHint: 'This split is now marked as paid',
          payerName: fromName,
          payeeName: toName,
        ),
      ),
    );
    return ok ?? false;
  }

  Future<void> _paySettlementWithUpi(SettlementSuggestion s) async {
    final paid = await _openSplitUpiCheckout(
      fromName: s.fromName,
      toName: s.toName,
      amount: s.amount,
      purpose: 'Trip settle ${s.fromName} to ${s.toName}',
    );
    if (!mounted || !paid) return;
    _commit(() {
      final keys = _service.unsettledShareKeysForTransfer(
        shares: _owedShares,
        settledKeys: _settledShareKeys,
        fromTravelerId: s.fromTravelerId,
        toTravelerId: s.toTravelerId,
      );
      _settledShareKeys.addAll(keys);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${s.fromName} \u2192 ${s.toName} payment successful'),
        ),
      );
    }
  }

  Future<void> _payShareWithUpi(ExpenseShareOwed share) async {
    final paid = await _openSplitUpiCheckout(
      fromName: share.debtorName,
      toName: share.payerName,
      amount: share.amount,
      purpose: 'Trip ${share.expenseDescription}',
    );
    if (!mounted || !paid) return;
    _commit(() {
      _settledShareKeys.add(share.settlementKey);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${share.debtorName} \u2192 ${share.payerName} payment successful',
          ),
        ),
      );
    }
  }

  Future<void> _showAddExpenseDialog() async {
    await _showExpenseEditor(
      TripExpense(
        id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
        description: '',
        category: BudgetCategory.miscellaneous,
        amount: 0,
        involvedTravelerIds: _travelers.map((t) => t.id).toList(),
      ),
      isNew: true,
    );
  }

  Future<void> _showExpenseEditor(TripExpense expense, {bool isNew = false}) async {
    final result = await showModalBottomSheet<ExpenseEditOutcome>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExpenseEditorSheet(
        expense: expense,
        isNew: isNew,
        travelers: List<SplitTraveler>.from(_travelers),
        service: _service,
      ),
    );
    if (!mounted || result == null) return;
    _commit(() {
      if (result.deleted) {
        _expenses.removeWhere((e) => e.id == expense.id);
        _settledShareKeys.removeWhere((k) => k.startsWith('${expense.id}_'));
        return;
      }
      final updated = result.expense;
      if (updated == null) return;
      if (isNew) {
        _expenses.add(updated);
      } else {
        final idx = _expenses.indexWhere((e) => e.id == expense.id);
        if (idx >= 0) _expenses[idx] = updated;
      }
    });
  }
}
