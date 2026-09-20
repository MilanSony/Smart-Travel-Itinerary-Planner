import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/budget_model.dart';
import '../models/itinerary_model.dart';
import '../models/split_budget_model.dart';

class SplitBudgetService {
  TripSplitMode suggestTripMode(Itinerary? itinerary) {
    final children = itinerary?.numChildren ?? 0;
    if (children > 0) return TripSplitMode.family;
    return TripSplitMode.group;
  }

  List<SplitTraveler> createDefaultTravelers({
    required int travelerCount,
    Itinerary? itinerary,
  }) {
    final adults = itinerary?.numAdults;
    final children = itinerary?.numChildren;

    if (adults != null && adults > 0) {
      final childCount = children ?? 0;
      final travelers = <SplitTraveler>[];
      for (var i = 0; i < adults; i++) {
        travelers.add(
          SplitTraveler(
            id: 'adult_$i',
            name: 'Member ${i + 1}',
            type: TravelerType.adult,
          ),
        );
      }
      for (var i = 0; i < childCount; i++) {
        travelers.add(
          SplitTraveler(
            id: 'child_$i',
            name: 'Child ${i + 1}',
            type: TravelerType.child,
          ),
        );
      }
      return travelers;
    }

    return List.generate(
      travelerCount.clamp(1, 20),
      (i) => SplitTraveler(
        id: 'traveler_$i',
        name: 'Member ${i + 1}',
        type: TravelerType.adult,
      ),
    );
  }

  /// Budget categories as placeholders — payer assigns custom splits when logging.
  List<TripExpense> importFromEstimation(
    BudgetEstimation estimation,
    List<SplitTraveler> travelers,
  ) {
    final ids = travelers.map((t) => t.id).toList();
    return estimation.categoryBreakdown
        .where((c) => c.estimatedCost > 0)
        .map(
          (c) => TripExpense(
            id: 'est_${c.category.index}',
            description: c.categoryName,
            category: c.category,
            amount: c.estimatedCost,
            splitRule: _defaultRuleForCategory(c.category),
            involvedTravelerIds: List<String>.from(ids),
            fromEstimation: true,
          ),
        )
        .toList();
  }

  SplitRule _defaultRuleForCategory(BudgetCategory category) {
    switch (category) {
      case BudgetCategory.food:
      case BudgetCategory.accommodation:
        return SplitRule.custom;
      default:
        return SplitRule.equal;
    }
  }

  SplitTraveler? travelerById(List<SplitTraveler> travelers, String id) {
    for (final t in travelers) {
      if (t.id == id) return t;
    }
    return null;
  }

  Map<String, double> buildEqualOwedAmounts({
    required TripExpense expense,
    required List<SplitTraveler> allTravelers,
  }) {
    final involved = allTravelers
        .where((t) => expense.involvedTravelerIds.contains(t.id))
        .toList();
    if (involved.isEmpty || expense.amount <= 0) return {};

    final share = expense.amount / involved.length;
    return {for (final t in involved) t.id: share};
  }

  double amountOwedByTraveler({
    required TripExpense expense,
    required String travelerId,
    required List<SplitTraveler> allTravelers,
  }) {
    if (!expense.involvedTravelerIds.contains(travelerId)) return 0;
    if (expense.amount <= 0) return 0;

    if (expense.splitRule == SplitRule.custom) {
      if (expense.customOwedAmounts.isNotEmpty) {
        return expense.customOwedAmounts[travelerId] ?? 0;
      }
      return 0;
    }

    final involved = allTravelers
        .where((t) => expense.involvedTravelerIds.contains(t.id))
        .toList();
    if (involved.isEmpty) return 0;
    return expense.amount / involved.length;
  }

  double payerOwnShare({
    required TripExpense expense,
    required List<SplitTraveler> allTravelers,
  }) {
    final payerId = expense.paidByTravelerId;
    if (payerId == null) return 0;

    if (expense.splitRule == SplitRule.custom) {
      final othersOwed = expense.customOwedAmounts.entries
          .where((e) => e.key != payerId)
          .fold<double>(0, (sum, e) => sum + e.value);
      final payerCustom = expense.customOwedAmounts[payerId] ?? 0;
      if (expense.customOwedAmounts.isNotEmpty) {
        return payerCustom > 0
            ? payerCustom
            : (expense.amount - othersOwed).clamp(0, expense.amount);
      }
      return 0;
    }

    return amountOwedByTraveler(
      expense: expense,
      travelerId: payerId,
      allTravelers: allTravelers,
    );
  }

  List<ExpenseShareOwed> calculateOwedShares({
    required List<SplitTraveler> travelers,
    required List<TripExpense> expenses,
  }) {
    final owed = <ExpenseShareOwed>[];

    for (final expense in expenses) {
      final payerId = expense.paidByTravelerId;
      if (payerId == null) continue;

      final payer = travelerById(travelers, payerId);
      if (payer == null) continue;

      final debtors = travelers.where((t) {
        if (t.id == payerId) return false;
        if (!expense.involvedTravelerIds.contains(t.id)) return false;
        final amount = amountOwedByTraveler(
          expense: expense,
          travelerId: t.id,
          allTravelers: travelers,
        );
        return amount > 0.01;
      });

      for (final debtor in debtors) {
        final amount = amountOwedByTraveler(
          expense: expense,
          travelerId: debtor.id,
          allTravelers: travelers,
        );
        owed.add(
          ExpenseShareOwed(
            expenseId: expense.id,
            expenseDescription: expense.description,
            payerId: payer.id,
            payerName: payer.name,
            debtorId: debtor.id,
            debtorName: debtor.name,
            amount: amount,
          ),
        );
      }
    }

    return owed;
  }

  List<TravelerBalance> calculateBalances({
    required List<SplitTraveler> travelers,
    required List<TripExpense> expenses,
    Set<String> settledShareKeys = const {},
  }) {
    final owedShares = calculateOwedShares(
      travelers: travelers,
      expenses: expenses,
    );

    return travelers.map((traveler) {
      var fairShare = 0.0;
      var paid = 0.0;

      for (final expense in expenses) {
        fairShare += amountOwedByTraveler(
          expense: expense,
          travelerId: traveler.id,
          allTravelers: travelers,
        );
        if (expense.paidByTravelerId == traveler.id) {
          paid += expense.amount;
        }
      }

      var balance = paid - fairShare;

      for (final share in owedShares) {
        if (share.debtorId == traveler.id &&
            settledShareKeys.contains(share.settlementKey)) {
          balance += share.amount;
        }
        if (share.payerId == traveler.id &&
            settledShareKeys.contains(share.settlementKey)) {
          balance -= share.amount;
        }
      }

      return TravelerBalance(
        traveler: traveler,
        fairShare: fairShare,
        paid: paid,
        balance: balance,
      );
    }).toList();
  }

  List<SettlementSuggestion> suggestSettlements(
    List<TravelerBalance> balances,
  ) {
    final creditors = balances
        .where((b) => b.isCreditor)
        .map(
          (b) => _SettlementNode(
            id: b.traveler.id,
            name: b.traveler.name,
            amount: b.balance,
          ),
        )
        .toList();

    final debtors = balances
        .where((b) => b.isDebtor)
        .map(
          (b) => _SettlementNode(
            id: b.traveler.id,
            name: b.traveler.name,
            amount: b.balance.abs(),
          ),
        )
        .toList();

    final suggestions = <SettlementSuggestion>[];
    var ci = 0;
    var di = 0;
    var counter = 0;

    while (ci < creditors.length && di < debtors.length) {
      final pay = creditors[ci].amount < debtors[di].amount
          ? creditors[ci].amount
          : debtors[di].amount;

      if (pay > 0.01) {
        suggestions.add(
          SettlementSuggestion(
            id: 'settle_${counter++}',
            fromTravelerId: debtors[di].id,
            fromName: debtors[di].name,
            toTravelerId: creditors[ci].id,
            toName: creditors[ci].name,
            amount: pay,
          ),
        );
      }

      creditors[ci].amount -= pay;
      debtors[di].amount -= pay;

      if (creditors[ci].amount <= 0.01) ci++;
      if (debtors[di].amount <= 0.01) di++;
    }

    return suggestions;
  }

  bool hasAnyPayments(List<TripExpense> expenses) {
    return expenses.any((e) => e.paidByTravelerId != null);
  }

  bool expenseSplitIsComplete(TripExpense expense) {
    if (expense.paidByTravelerId == null) return false;
    if (expense.splitRule == SplitRule.equal) return true;

    final assigned = expense.customOwedAmounts.values.fold<double>(0, (a, b) => a + b);
    final payerShare = expense.amount - assigned;
    return assigned > 0 && (assigned + payerShare - expense.amount).abs() < 1;
  }

  int countUnsettledShares(
    List<ExpenseShareOwed> shares,
    Set<String> settledKeys,
  ) {
    return shares.where((s) => !settledKeys.contains(s.settlementKey)).length;
  }

  int countSettledShares(
    List<ExpenseShareOwed> shares,
    Set<String> settledKeys,
  ) {
    return shares.where((s) => settledKeys.contains(s.settlementKey)).length;
  }

  /// Expense-level dues from [fromTravelerId] to [toTravelerId] that are still open.
  List<String> unsettledShareKeysForTransfer({
    required List<ExpenseShareOwed> shares,
    required Set<String> settledKeys,
    required String fromTravelerId,
    required String toTravelerId,
  }) {
    return shares
        .where(
          (s) =>
              s.debtorId == fromTravelerId &&
              s.payerId == toTravelerId &&
              !settledKeys.contains(s.settlementKey),
        )
        .map((s) => s.settlementKey)
        .toList();
  }

  String storageKey({
    required BudgetEstimation estimation,
    Itinerary? itinerary,
  }) {
    final dest = estimation.destination.toLowerCase().trim();
    final start =
        '${estimation.startDate.year}-${estimation.startDate.month}-${estimation.startDate.day}';
    final end =
        '${estimation.endDate.year}-${estimation.endDate.month}-${estimation.endDate.day}';
    final title = (itinerary?.title ?? '').toLowerCase().trim();
    return 'split_budget_v1|$title|$dest|$start|$end';
  }

  Future<SplitBudgetSnapshot?> loadSnapshot(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final snapshot = SplitBudgetSnapshot.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (snapshot.travelers.isEmpty) return null;
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSnapshot(String key, SplitBudgetSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(snapshot.toJson()));
  }

  List<TripExpense> mergeSavedExpenses({
    required List<TripExpense> saved,
    required List<TripExpense> fromEstimation,
  }) {
    final savedById = {for (final e in saved) e.id: e};
    final merged = <TripExpense>[];
    for (final fresh in fromEstimation) {
      final existing = savedById[fresh.id];
      if (existing == null) {
        merged.add(fresh);
      } else if (existing.paidByTravelerId != null) {
        merged.add(existing);
      } else {
        merged.add(
          existing.copyWith(
            amount: fresh.amount,
            description: fresh.description,
          ),
        );
      }
    }
    for (final e in saved) {
      if (!merged.any((m) => m.id == e.id)) {
        merged.add(e);
      }
    }
    return merged;
  }
}

class _SettlementNode {
  final String id;
  final String name;
  double amount;

  _SettlementNode({
    required this.id,
    required this.name,
    required this.amount,
  });
}
