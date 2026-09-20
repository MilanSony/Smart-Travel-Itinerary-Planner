import 'package:flutter/material.dart';

import 'budget_model.dart';

/// Family trips use one shared budget; group trips split costs among travellers.
enum TripSplitMode {
  family,
  group,
}

extension TripSplitModeExtension on TripSplitMode {
  String get label {
    switch (this) {
      case TripSplitMode.family:
        return 'Family trip';
      case TripSplitMode.group:
        return 'Group trip';
    }
  }

  String get subtitle {
    switch (this) {
      case TripSplitMode.family:
        return 'One shared budget — no splitting between members';
      case TripSplitMode.group:
        return 'Friends or colleagues — payer records who owes what';
    }
  }

  IconData get icon {
    switch (this) {
      case TripSplitMode.family:
        return Icons.family_restroom;
      case TripSplitMode.group:
        return Icons.groups;
    }
  }
}

enum TravelerType {
  adult,
  child,
}

extension TravelerTypeExtension on TravelerType {
  String get label {
    switch (this) {
      case TravelerType.adult:
        return 'Adult';
      case TravelerType.child:
        return 'Child';
    }
  }
}

/// Equal split or payer assigns exact amount per person.
enum SplitRule {
  equal,
  custom,
}

extension SplitRuleExtension on SplitRule {
  String get label {
    switch (this) {
      case SplitRule.equal:
        return 'Split equally';
      case SplitRule.custom:
        return 'Custom amounts';
    }
  }

  String get description {
    switch (this) {
      case SplitRule.equal:
        return 'Same share for everyone involved';
      case SplitRule.custom:
        return 'Payer enters how much each person owes them';
    }
  }
}

class SplitTraveler {
  final String id;
  final String name;
  final TravelerType type;
  /// UPI VPA used when others pay this member (e.g. milan@okaxis).
  final String? upiId;

  const SplitTraveler({
    required this.id,
    required this.name,
    this.type = TravelerType.adult,
    this.upiId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'upiId': upiId,
      };

  factory SplitTraveler.fromJson(Map<String, dynamic> json) {
    return SplitTraveler(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Member',
      type: TravelerType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => TravelerType.adult,
      ),
      upiId: json['upiId'] as String?,
    );
  }

  SplitTraveler copyWith({
    String? id,
    String? name,
    TravelerType? type,
    String? upiId,
    bool clearUpiId = false,
  }) {
    return SplitTraveler(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      upiId: clearUpiId ? null : (upiId ?? this.upiId),
    );
  }
}

class TripExpense {
  final String id;
  final String description;
  final BudgetCategory category;
  final double amount;
  final SplitRule splitRule;
  final List<String> involvedTravelerIds;
  final String? paidByTravelerId;
  /// Amount each traveller owes the payer (travelerId -> ₹). Used when [splitRule] is custom.
  final Map<String, double> customOwedAmounts;
  final bool fromEstimation;

  const TripExpense({
    required this.id,
    required this.description,
    required this.category,
    required this.amount,
    this.splitRule = SplitRule.custom,
    required this.involvedTravelerIds,
    this.paidByTravelerId,
    this.customOwedAmounts = const {},
    this.fromEstimation = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'category': category.name,
        'amount': amount,
        'splitRule': splitRule.name,
        'involvedTravelerIds': involvedTravelerIds,
        'paidByTravelerId': paidByTravelerId,
        'customOwedAmounts': customOwedAmounts,
        'fromEstimation': fromEstimation,
      };

  factory TripExpense.fromJson(Map<String, dynamic> json) {
    final rawAmounts = json['customOwedAmounts'];
    final amounts = <String, double>{};
    if (rawAmounts is Map) {
      for (final e in rawAmounts.entries) {
        final v = e.value;
        if (v is num) amounts[e.key.toString()] = v.toDouble();
      }
    }
    final rawIds = json['involvedTravelerIds'];
    return TripExpense(
      id: json['id'] as String,
      description: json['description'] as String? ?? '',
      category: BudgetCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => BudgetCategory.miscellaneous,
      ),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      splitRule: SplitRule.values.firstWhere(
        (r) => r.name == json['splitRule'],
        orElse: () => SplitRule.custom,
      ),
      involvedTravelerIds: rawIds is List
          ? rawIds.map((e) => e.toString()).toList()
          : const [],
      paidByTravelerId: json['paidByTravelerId'] as String?,
      customOwedAmounts: amounts,
      fromEstimation: json['fromEstimation'] == true,
    );
  }

  TripExpense copyWith({
    String? id,
    String? description,
    BudgetCategory? category,
    double? amount,
    SplitRule? splitRule,
    List<String>? involvedTravelerIds,
    String? paidByTravelerId,
    Map<String, double>? customOwedAmounts,
    bool? fromEstimation,
    bool clearPaidBy = false,
  }) {
    return TripExpense(
      id: id ?? this.id,
      description: description ?? this.description,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      splitRule: splitRule ?? this.splitRule,
      involvedTravelerIds: involvedTravelerIds ?? this.involvedTravelerIds,
      paidByTravelerId:
          clearPaidBy ? null : (paidByTravelerId ?? this.paidByTravelerId),
      customOwedAmounts: customOwedAmounts ?? this.customOwedAmounts,
      fromEstimation: fromEstimation ?? this.fromEstimation,
    );
  }

  bool get hasCustomSplitConfigured {
    if (splitRule != SplitRule.custom) return true;
    return customOwedAmounts.values.any((v) => v > 0);
  }
}

class ExpenseShareOwed {
  final String expenseId;
  final String expenseDescription;
  final String payerId;
  final String payerName;
  final String debtorId;
  final String debtorName;
  final double amount;

  const ExpenseShareOwed({
    required this.expenseId,
    required this.expenseDescription,
    required this.payerId,
    required this.payerName,
    required this.debtorId,
    required this.debtorName,
    required this.amount,
  });

  String get settlementKey => '${expenseId}_$debtorId';
}

class TravelerBalance {
  final SplitTraveler traveler;
  final double fairShare;
  final double paid;
  final double balance;

  const TravelerBalance({
    required this.traveler,
    required this.fairShare,
    required this.paid,
    required this.balance,
  });

  bool get isCreditor => balance > 0.01;
  bool get isDebtor => balance < -0.01;
  bool get isSettled => !isCreditor && !isDebtor;
}

class SettlementSuggestion {
  final String id;
  final String fromTravelerId;
  final String fromName;
  final String toTravelerId;
  final String toName;
  final double amount;

  const SettlementSuggestion({
    required this.id,
    required this.fromTravelerId,
    required this.fromName,
    required this.toTravelerId,
    required this.toName,
    required this.amount,
  });
}

class SplitBudgetSnapshot {
  final TripSplitMode tripMode;
  final List<SplitTraveler> travelers;
  final List<TripExpense> expenses;
  final Set<String> settledShareKeys;

  const SplitBudgetSnapshot({
    required this.tripMode,
    required this.travelers,
    required this.expenses,
    required this.settledShareKeys,
  });

  Map<String, dynamic> toJson() => {
        'tripMode': tripMode.name,
        'travelers': travelers.map((t) => t.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'settledShareKeys': settledShareKeys.toList(),
      };

  factory SplitBudgetSnapshot.fromJson(Map<String, dynamic> json) {
    return SplitBudgetSnapshot(
      tripMode: TripSplitMode.values.firstWhere(
        (m) => m.name == json['tripMode'],
        orElse: () => TripSplitMode.group,
      ),
      travelers: (json['travelers'] as List? ?? [])
          .whereType<Map>()
          .map((e) => SplitTraveler.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      expenses: (json['expenses'] as List? ?? [])
          .whereType<Map>()
          .map((e) => TripExpense.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      settledShareKeys: {
        for (final k in (json['settledShareKeys'] as List? ?? [])) k.toString(),
      },
    );
  }
}
