import 'package:flutter/material.dart';

/// Budget category types for cost breakdown
enum BudgetCategory {
  accommodation,
  food,
  transportation,
  activities,
  shopping,
  emergency,
  miscellaneous,
}

/// Budget optimization suggestion
class BudgetOptimization {
  final String category;
  final String suggestion;
  final double potentialSavings;
  final String impact; // 'low', 'medium', 'high'

  BudgetOptimization({
    required this.category,
    required this.suggestion,
    required this.potentialSavings,
    required this.impact,
  });
}

/// Cost breakdown for a specific category
class CostBreakdown {
  final BudgetCategory category;
  final double estimatedCost;
  final double minCost;
  final double maxCost;
  final String description;
  final IconData icon;
  final double percentage; // Percentage of total budget

  CostBreakdown({
    required this.category,
    required this.estimatedCost,
    required this.minCost,
    required this.maxCost,
    required this.description,
    required this.icon,
    required this.percentage,
  });

  String get categoryName {
    switch (category) {
      case BudgetCategory.accommodation:
        return 'Accommodation';
      case BudgetCategory.food:
        return 'Food & Dining';
      case BudgetCategory.transportation:
        return 'Transportation';
      case BudgetCategory.activities:
        return 'Activities & Attractions';
      case BudgetCategory.shopping:
        return 'Shopping';
      case BudgetCategory.emergency:
        return 'Emergency Fund';
      case BudgetCategory.miscellaneous:
        return 'Miscellaneous';
    }
  }
}

/// Daily budget breakdown
class DailyBudget {
  final DateTime date;
  final double estimatedCost;
  final List<CostBreakdown> breakdown;
  final String? notes;

  DailyBudget({
    required this.date,
    required this.estimatedCost,
    required this.breakdown,
    this.notes,
  });
}

/// Complete budget estimation result
class BudgetEstimation {
  final String tripId;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final int travelers;
  final double totalBudget;
  final double estimatedTotalCost;
  final double minTotalCost;
  final double maxTotalCost;
  final List<CostBreakdown> categoryBreakdown;
  final List<DailyBudget> dailyBudgets;
  final List<BudgetOptimization> optimizations;
  final String? aiInsights;
  final DateTime createdAt;
  final double budgetVariance; // Difference between budget and estimated cost
  final double budgetUtilization; // Percentage of budget used

  BudgetEstimation({
    required this.tripId,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.travelers,
    required this.totalBudget,
    required this.estimatedTotalCost,
    required this.minTotalCost,
    required this.maxTotalCost,
    required this.categoryBreakdown,
    required this.dailyBudgets,
    required this.optimizations,
    this.aiInsights,
    required this.createdAt,
    required this.budgetVariance,
    required this.budgetUtilization,
  });

  /// Get budget status (within budget, over budget, etc.)
  BudgetStatus get status {
    if (budgetVariance > 0) {
      return BudgetStatus.withinBudget;
    } else if (budgetVariance.abs() / totalBudget < 0.1) {
      return BudgetStatus.slightlyOver;
    } else {
      return BudgetStatus.overBudget;
    }
  }

  /// Get formatted budget variance
  String get formattedVariance {
    if (budgetVariance >= 0) {
      return '₹${budgetVariance.toStringAsFixed(0)} under budget';
    } else {
      return '₹${budgetVariance.abs().toStringAsFixed(0)} over budget';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'destination': destination,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'travelers': travelers,
      'totalBudget': totalBudget,
      'estimatedTotalCost': estimatedTotalCost,
      'minTotalCost': minTotalCost,
      'maxTotalCost': maxTotalCost,
      'categoryBreakdown': categoryBreakdown.map((c) => {
        'category': c.category.index,
        'estimatedCost': c.estimatedCost,
        'minCost': c.minCost,
        'maxCost': c.maxCost,
        'description': c.description,
        'percentage': c.percentage,
      }).toList(),
      'dailyBudgets': dailyBudgets.map((d) => {
        'date': d.date.toIso8601String(),
        'estimatedCost': d.estimatedCost,
        'breakdown': d.breakdown.map((c) => {
          'category': c.category.index,
          'estimatedCost': c.estimatedCost,
          'minCost': c.minCost,
          'maxCost': c.maxCost,
          'description': c.description,
          'percentage': c.percentage,
        }).toList(),
        'notes': d.notes,
      }).toList(),
      'optimizations': optimizations.map((o) => {
        'category': o.category,
        'suggestion': o.suggestion,
        'potentialSavings': o.potentialSavings,
        'impact': o.impact,
      }).toList(),
      'aiInsights': aiInsights,
      'createdAt': createdAt.toIso8601String(),
      'budgetVariance': budgetVariance,
      'budgetUtilization': budgetUtilization,
    };
  }

  factory BudgetEstimation.fromMap(Map<String, dynamic> map) {
    return BudgetEstimation(
      tripId: map['tripId'] ?? '',
      destination: map['destination'] ?? '',
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      travelers: map['travelers'] ?? 1,
      totalBudget: (map['totalBudget'] ?? 0).toDouble(),
      estimatedTotalCost: (map['estimatedTotalCost'] ?? 0).toDouble(),
      minTotalCost: (map['minTotalCost'] ?? 0).toDouble(),
      maxTotalCost: (map['maxTotalCost'] ?? 0).toDouble(),
      categoryBreakdown: (map['categoryBreakdown'] as List?)
          ?.map((c) => CostBreakdown(
                category: BudgetCategory.values[c['category'] ?? 0],
                estimatedCost: (c['estimatedCost'] ?? 0).toDouble(),
                minCost: (c['minCost'] ?? 0).toDouble(),
                maxCost: (c['maxCost'] ?? 0).toDouble(),
                description: c['description'] ?? '',
                icon: _getIconForCategory(BudgetCategory.values[c['category'] ?? 0]),
                percentage: (c['percentage'] ?? 0).toDouble(),
              ))
          .toList() ?? [],
      dailyBudgets: (map['dailyBudgets'] as List?)
          ?.map((d) => DailyBudget(
                date: DateTime.parse(d['date']),
                estimatedCost: (d['estimatedCost'] ?? 0).toDouble(),
                breakdown: (d['breakdown'] as List?)
                    ?.map((c) => CostBreakdown(
                          category: BudgetCategory.values[c['category'] ?? 0],
                          estimatedCost: (c['estimatedCost'] ?? 0).toDouble(),
                          minCost: (c['minCost'] ?? 0).toDouble(),
                          maxCost: (c['maxCost'] ?? 0).toDouble(),
                          description: c['description'] ?? '',
                          icon: _getIconForCategory(BudgetCategory.values[c['category'] ?? 0]),
                          percentage: (c['percentage'] ?? 0).toDouble(),
                        ))
                    .toList() ?? [],
                notes: d['notes'],
              ))
          .toList() ?? [],
      optimizations: (map['optimizations'] as List?)
          ?.map((o) => BudgetOptimization(
                category: o['category'] ?? '',
                suggestion: o['suggestion'] ?? '',
                potentialSavings: (o['potentialSavings'] ?? 0).toDouble(),
                impact: o['impact'] ?? 'low',
              ))
          .toList() ?? [],
      aiInsights: map['aiInsights'],
      createdAt: DateTime.parse(map['createdAt']),
      budgetVariance: (map['budgetVariance'] ?? 0).toDouble(),
      budgetUtilization: (map['budgetUtilization'] ?? 0).toDouble(),
    );
  }

  static IconData _getIconForCategory(BudgetCategory category) {
    switch (category) {
      case BudgetCategory.accommodation:
        return Icons.hotel;
      case BudgetCategory.food:
        return Icons.restaurant;
      case BudgetCategory.transportation:
        return Icons.directions_car;
      case BudgetCategory.activities:
        return Icons.attractions;
      case BudgetCategory.shopping:
        return Icons.shopping_bag;
      case BudgetCategory.emergency:
        return Icons.emergency;
      case BudgetCategory.miscellaneous:
        return Icons.more_horiz;
    }
  }
}

/// Budget status indicator
enum BudgetStatus {
  withinBudget,
  slightlyOver,
  overBudget,
}



