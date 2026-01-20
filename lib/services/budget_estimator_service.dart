import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/budget_model.dart';
import '../models/itinerary_model.dart';
import 'itinerary_service.dart'; // For BudgetLevel enum and budget categorization baseline

class BudgetEstimatorService {
  // Destination-specific base daily costs (per person) and multipliers
  // These reflect actual cost differences between destinations
  static const Map<String, Map<String, double>> _destinationCosts = {
    // Tier 1 cities (expensive)
    'mumbai': {'baseMultiplier': 1.4, 'baseCost': 2500},
    'delhi': {'baseMultiplier': 1.3, 'baseCost': 2300},
    'bangalore': {'baseMultiplier': 1.35, 'baseCost': 2400},
    'hyderabad': {'baseMultiplier': 1.2, 'baseCost': 2200},
    'chennai': {'baseMultiplier': 1.25, 'baseCost': 2250},
    'pune': {'baseMultiplier': 1.15, 'baseCost': 2100},
    
    // Tourist destinations (moderate to expensive)
    'goa': {'baseMultiplier': 1.1, 'baseCost': 2000},
    'kerala': {'baseMultiplier': 0.95, 'baseCost': 1900},
    'manali': {'baseMultiplier': 1.0, 'baseCost': 2000},
    'shimla': {'baseMultiplier': 0.95, 'baseCost': 1900},
    'darjeeling': {'baseMultiplier': 0.9, 'baseCost': 1800},
    'ooty': {'baseMultiplier': 0.95, 'baseCost': 1900},
    'mussorie': {'baseMultiplier': 0.95, 'baseCost': 1900},
    
    // Historical/cultural destinations (moderate)
    'rajasthan': {'baseMultiplier': 0.85, 'baseCost': 1700},
    'jaipur': {'baseMultiplier': 0.9, 'baseCost': 1800},
    'udaipur': {'baseMultiplier': 0.9, 'baseCost': 1800},
    'jodhpur': {'baseMultiplier': 0.85, 'baseCost': 1700},
    'varanasi': {'baseMultiplier': 0.8, 'baseCost': 1600},
    'agra': {'baseMultiplier': 0.85, 'baseCost': 1700},
    
    // Beach destinations
    'andaman': {'baseMultiplier': 1.2, 'baseCost': 2200},
    'lakshadweep': {'baseMultiplier': 1.15, 'baseCost': 2100},
    'pondicherry': {'baseMultiplier': 0.95, 'baseCost': 1900},
    
    // Hill stations
    'himachal': {'baseMultiplier': 0.95, 'baseCost': 1900},
    'kashmir': {'baseMultiplier': 1.0, 'baseCost': 2000},
    'leh': {'baseMultiplier': 1.1, 'baseCost': 2100},
    
    // Default (moderate cost)
    'default': {'baseMultiplier': 1.0, 'baseCost': 2000},
  };

  // Default percentage allocations for budget categories
  static const Map<BudgetCategory, double> _defaultCategoryPercentages = {
    BudgetCategory.accommodation: 0.35,
    BudgetCategory.food: 0.25,
    BudgetCategory.transportation: 0.20,
    BudgetCategory.activities: 0.15,
    BudgetCategory.shopping: 0.03,
    BudgetCategory.emergency: 0.01,
    BudgetCategory.miscellaneous: 0.01,
  };

  final GenerativeModel? _aiModel;

  BudgetEstimatorService({String? apiKey}) 
      : _aiModel = apiKey != null && apiKey.isNotEmpty
          ? GenerativeModel(
              model: 'gemini-1.5-pro', // Try gemini-1.5-pro
              apiKey: apiKey,
            )
          : null;

  /// Estimate budget for a trip based on itinerary and preferences
  Future<BudgetEstimation> estimateBudget({
    required String tripId,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required int travelers,
    required double totalBudget,
    Itinerary? itinerary,
    List<String>? preferences,
    String? budgetLevel, // 'budget', 'moderate', 'luxury'
  }) async {
    final durationInDays = endDate.difference(startDate).inDays + 1;
    final seasonMultiplier = _getSeasonMultiplier(startDate);
    final budgetLevelEnum = _parseBudgetLevel(budgetLevel);

    // Get destination-specific costs
    final destCosts = _getDestinationCosts(destination);
    final destinationBaseCost = destCosts['baseCost']!;
    final destinationMultiplier = destCosts['baseMultiplier']!;

    // Calculate base daily cost per person based on budget level
    final baseDailyCostPerPerson = _calculateBaseDailyCost(
      budgetLevelEnum,
      destination,
      durationInDays,
    );

    // Apply destination-specific pricing (more impactful)
    // Use destination base cost adjusted by budget level ratio
    final budgetLevelRatio = baseDailyCostPerPerson / 2000; // Ratio to moderate level
    final destinationAdjustedCost = destinationBaseCost * budgetLevelRatio;

    // Adjust for season
    final adjustedDailyCostPerPerson = destinationAdjustedCost * 
        destinationMultiplier * 
        seasonMultiplier;

    // Calculate INDEPENDENT estimated total cost based on actual trip costs
    // (not based on user's budget - we'll compare later)
    final independentEstimatedTotal = adjustedDailyCostPerPerson * travelers * durationInDays;

    // Calculate category breakdowns based on INDEPENDENT estimated cost
    final categoryBreakdown = _calculateCategoryBreakdown(
      independentEstimatedTotal, // Use independent estimate, not user's budget
      durationInDays,
      travelers,
      adjustedDailyCostPerPerson,
      budgetLevelEnum,
      destination,
    );

    // Calculate total estimated cost from breakdown
    final estimatedTotalCost = categoryBreakdown
        .fold(0.0, (sum, breakdown) => sum + breakdown.estimatedCost);
    
    // Calculate daily budgets (normalized to match total estimated cost)
    final dailyBudgets = _calculateDailyBudgets(
      startDate,
      endDate,
      categoryBreakdown,
      durationInDays,
      estimatedTotalCost,
      itinerary,
    );
    
    final minTotalCost = categoryBreakdown
        .fold(0.0, (sum, breakdown) => sum + breakdown.minCost);
    
    final maxTotalCost = categoryBreakdown
        .fold(0.0, (sum, breakdown) => sum + breakdown.maxCost);

    // Generate AI-powered optimizations
    final optimizations = await _generateOptimizations(
      categoryBreakdown,
      totalBudget,
      estimatedTotalCost,
      destination,
      durationInDays,
      travelers,
      preferences,
    );

    // Generate AI insights
    final aiInsights = await _generateAIInsights(
      destination,
      durationInDays,
      travelers,
      totalBudget,
      estimatedTotalCost,
      categoryBreakdown,
      preferences,
    );

    final budgetVariance = totalBudget - estimatedTotalCost;
    final double budgetUtilization = totalBudget > 0
        ? (estimatedTotalCost / totalBudget) * 100.0
        : 0.0;

    return BudgetEstimation(
      tripId: tripId,
      destination: destination,
      startDate: startDate,
      endDate: endDate,
      travelers: travelers,
      totalBudget: totalBudget,
      estimatedTotalCost: estimatedTotalCost,
      minTotalCost: minTotalCost,
      maxTotalCost: maxTotalCost,
      categoryBreakdown: categoryBreakdown,
      dailyBudgets: dailyBudgets,
      optimizations: optimizations,
      aiInsights: aiInsights,
      createdAt: DateTime.now(),
      budgetVariance: budgetVariance,
      budgetUtilization: budgetUtilization,
    );
  }

  /// Optimize existing budget estimation
  Future<BudgetEstimation> optimizeBudget({
    required BudgetEstimation currentEstimation,
    double? targetBudget,
    List<String>? priorities, // Categories to prioritize
  }) async {
    // Keep the independent estimated costs; do NOT force-fit to target budget.
    // We only adjust the declared budget and recompute optimizations/insights.
    final appliedBudget = targetBudget ?? currentEstimation.totalBudget;
    final durationInDays = currentEstimation.endDate
        .difference(currentEstimation.startDate)
        .inDays + 1;

    final optimizations = await _generateOptimizations(
      currentEstimation.categoryBreakdown,
      appliedBudget,
      currentEstimation.estimatedTotalCost,
      currentEstimation.destination,
      durationInDays,
      currentEstimation.travelers,
      priorities,
    );

    final aiInsights = await _generateAIInsights(
      currentEstimation.destination,
      durationInDays,
      currentEstimation.travelers,
      appliedBudget,
      currentEstimation.estimatedTotalCost,
      currentEstimation.categoryBreakdown,
      priorities,
    );

    final budgetVariance = appliedBudget - currentEstimation.estimatedTotalCost;
    final double budgetUtilization = appliedBudget > 0
        ? (currentEstimation.estimatedTotalCost / appliedBudget) * 100.0
        : 0.0;

    return BudgetEstimation(
      tripId: currentEstimation.tripId,
      destination: currentEstimation.destination,
      startDate: currentEstimation.startDate,
      endDate: currentEstimation.endDate,
      travelers: currentEstimation.travelers,
      totalBudget: appliedBudget,
      estimatedTotalCost: currentEstimation.estimatedTotalCost,
      minTotalCost: currentEstimation.minTotalCost,
      maxTotalCost: currentEstimation.maxTotalCost,
      categoryBreakdown: currentEstimation.categoryBreakdown,
      dailyBudgets: currentEstimation.dailyBudgets,
      optimizations: optimizations,
      aiInsights: aiInsights,
      createdAt: DateTime.now(),
      budgetVariance: budgetVariance,
      budgetUtilization: budgetUtilization,
    );
  }

  // Helper methods

  Map<String, double> _getDestinationCosts(String destination) {
    final destLower = destination.toLowerCase().trim();
    
    // Try exact match first
    if (_destinationCosts.containsKey(destLower)) {
      return Map<String, double>.from(_destinationCosts[destLower]!);
    }
    
    // Try partial match (check if destination contains any key)
    for (final key in _destinationCosts.keys) {
      if (key != 'default' && destLower.contains(key)) {
        return Map<String, double>.from(_destinationCosts[key]!);
      }
    }
    
    // Return default
    return Map<String, double>.from(_destinationCosts['default']!);
  }

  double _getSeasonMultiplier(DateTime date) {
    final month = date.month;
    // Peak season (Dec-Feb, May-Jun) - higher costs
    if (month == 12 || month == 1 || month == 2 || month == 5 || month == 6) {
      return 1.15;
    }
    // Off-season (Jul-Sep) - lower costs
    if (month >= 7 && month <= 9) {
      return 0.85;
    }
    // Shoulder season - normal costs
    return 1.0;
  }

  BudgetLevel _parseBudgetLevel(String? level) {
    if (level == null) return BudgetLevel.moderate;
    switch (level.toLowerCase()) {
      case 'budget':
        return BudgetLevel.budget;
      case 'luxury':
        return BudgetLevel.luxury;
      default:
        return BudgetLevel.moderate;
    }
  }

  double _calculateBaseDailyCost(
    BudgetLevel budgetLevel,
    String destination,
    int durationInDays,
  ) {
    // Base daily cost per person in INR
    double baseCost;
    switch (budgetLevel) {
      case BudgetLevel.budget:
        baseCost = 800;
        break;
      case BudgetLevel.moderate:
        baseCost = 2000;
        break;
      case BudgetLevel.luxury:
        baseCost = 5000;
        break;
    }

    // Longer trips get slight discount per day
    if (durationInDays > 7) {
      baseCost *= 0.95;
    }
    if (durationInDays > 14) {
      baseCost *= 0.90;
    }

    return baseCost;
  }

  List<CostBreakdown> _calculateCategoryBreakdown(
    double estimatedTotalCost, // This is now the independent estimated cost, not user's budget
    int durationInDays,
    int travelers,
    double dailyCostPerPerson,
    BudgetLevel budgetLevel,
    String destination,
  ) {
    final breakdown = <CostBreakdown>[];
    final totalDailyCost = dailyCostPerPerson * travelers * durationInDays;

    // Adjust percentages based on budget level
    final percentages = Map<BudgetCategory, double>.from(_defaultCategoryPercentages);
    
    if (budgetLevel == BudgetLevel.budget) {
      percentages[BudgetCategory.accommodation] = 0.40;
      percentages[BudgetCategory.food] = 0.30;
      percentages[BudgetCategory.activities] = 0.10;
    } else if (budgetLevel == BudgetLevel.luxury) {
      percentages[BudgetCategory.accommodation] = 0.45;
      percentages[BudgetCategory.activities] = 0.20;
      percentages[BudgetCategory.food] = 0.20;
    }

    percentages.forEach((category, percentage) {
      final estimatedCost = estimatedTotalCost * percentage; // Use independent estimate
      final variance = estimatedCost * 0.15; // 15% variance
      final minCost = estimatedCost - variance;
      final maxCost = estimatedCost + variance;

      breakdown.add(CostBreakdown(
        category: category,
        estimatedCost: estimatedCost,
        minCost: minCost > 0 ? minCost : estimatedCost * 0.5,
        maxCost: maxCost,
        description: _getCategoryDescription(category, destination, budgetLevel),
        icon: _getIconForCategory(category),
        percentage: percentage * 100,
      ));
    });

    return breakdown;
  }

  List<DailyBudget> _calculateDailyBudgets(
    DateTime startDate,
    DateTime endDate,
    List<CostBreakdown> categoryBreakdown,
    int durationInDays,
    double totalEstimatedCost,
    Itinerary? itinerary,
  ) {
    final dailyBudgets = <DailyBudget>[];
    
    // Calculate multipliers for each day (first/last days get 1.2x, others 1.0x)
    final dayMultipliers = <double>[];
    double totalMultiplier = 0.0;
    for (int i = 0; i < durationInDays; i++) {
      final isFirstDay = i == 0;
      final isLastDay = i == durationInDays - 1;
      final multiplier = (isFirstDay || isLastDay) ? 1.2 : 1.0;
      dayMultipliers.add(multiplier);
      totalMultiplier += multiplier;
    }
    
    // Normalize so daily budgets sum exactly to totalEstimatedCost
    final baseDailyCost = totalEstimatedCost / totalMultiplier;

    for (int i = 0; i < durationInDays; i++) {
      final date = startDate.add(Duration(days: i));
      final isFirstDay = i == 0;
      final isLastDay = i == durationInDays - 1;
      final dayMultiplier = dayMultipliers[i];
      
      // Calculate normalized daily cost
      final dailyCost = baseDailyCost * dayMultiplier;
      
      // Distribute categories proportionally (normalized)
      final dailyBreakdown = categoryBreakdown.map((cat) {
        // Calculate proportional cost for this day
        final catDailyCost = (cat.estimatedCost * dayMultiplier) / totalMultiplier;
        return CostBreakdown(
          category: cat.category,
          estimatedCost: catDailyCost,
          minCost: catDailyCost * 0.7,
          maxCost: catDailyCost * 1.3,
          description: cat.description,
          icon: cat.icon,
          percentage: dailyCost > 0 ? (catDailyCost / dailyCost) * 100 : 0,
        );
      }).toList();

      String? notes;
      if (isFirstDay) {
        notes = 'Arrival day - includes initial transportation and check-in';
      } else if (isLastDay) {
        notes = 'Departure day - includes checkout and final transportation';
      }

      dailyBudgets.add(DailyBudget(
        date: date,
        estimatedCost: dailyCost,
        breakdown: dailyBreakdown,
        notes: notes,
      ));
    }

    return dailyBudgets;
  }

  List<CostBreakdown> _adjustBudgetForTarget(
    List<CostBreakdown> currentBreakdown,
    double targetBudget,
    List<String>? priorities,
  ) {
    final currentTotal = currentBreakdown
        .fold(0.0, (sum, b) => sum + b.estimatedCost);
    final ratio = targetBudget / currentTotal;

    if (priorities == null || priorities.isEmpty) {
      // Proportional adjustment
      return currentBreakdown.map((breakdown) {
        return CostBreakdown(
          category: breakdown.category,
          estimatedCost: breakdown.estimatedCost * ratio,
          minCost: breakdown.minCost * ratio,
          maxCost: breakdown.maxCost * ratio,
          description: breakdown.description,
          icon: breakdown.icon,
          percentage: breakdown.percentage,
        );
      }).toList();
    }

    // Priority-based adjustment
    final priorityCategories = priorities.map((p) => _parseCategoryFromString(p)).toList();
    final nonPriorityRatio = ratio * 0.9; // Reduce non-priority by 10%
    final priorityRatio = ratio * 1.1; // Increase priority by 10%

    return currentBreakdown.map((breakdown) {
      final isPriority = priorityCategories.contains(breakdown.category);
      final adjustmentRatio = isPriority ? priorityRatio : nonPriorityRatio;
      
      return CostBreakdown(
        category: breakdown.category,
        estimatedCost: breakdown.estimatedCost * adjustmentRatio,
        minCost: breakdown.minCost * adjustmentRatio,
        maxCost: breakdown.maxCost * adjustmentRatio,
        description: breakdown.description,
        icon: breakdown.icon,
        percentage: breakdown.percentage,
      );
    }).toList();
  }

  List<DailyBudget> _recalculateDailyBudgets(
    List<DailyBudget> currentDailyBudgets,
    List<CostBreakdown> newCategoryBreakdown,
    int durationInDays,
  ) {
    // Calculate total estimated cost from new breakdown
    final totalEstimatedCost = newCategoryBreakdown
        .fold(0.0, (sum, b) => sum + b.estimatedCost);
    
    // Calculate multipliers for each day
    double totalMultiplier = 0.0;
    final dayMultipliers = <double>[];
    for (int i = 0; i < durationInDays; i++) {
      final isFirstDay = i == 0;
      final isLastDay = i == durationInDays - 1;
      final multiplier = (isFirstDay || isLastDay) ? 1.2 : 1.0;
      dayMultipliers.add(multiplier);
      totalMultiplier += multiplier;
    }
    
    final baseDailyCost = totalEstimatedCost / totalMultiplier;

    return currentDailyBudgets.asMap().entries.map((entry) {
      final index = entry.key;
      final original = entry.value;
      final dayMultiplier = dayMultipliers[index];
      final dailyCost = baseDailyCost * dayMultiplier;

      final dailyBreakdown = newCategoryBreakdown.map((cat) {
        final catDailyCost = (cat.estimatedCost * dayMultiplier) / totalMultiplier;
        return CostBreakdown(
          category: cat.category,
          estimatedCost: catDailyCost,
          minCost: catDailyCost * 0.7,
          maxCost: catDailyCost * 1.3,
          description: cat.description,
          icon: cat.icon,
          percentage: dailyCost > 0 ? (catDailyCost / dailyCost) * 100 : 0,
        );
      }).toList();

      return DailyBudget(
        date: original.date,
        estimatedCost: dailyCost,
        breakdown: dailyBreakdown,
        notes: original.notes,
      );
    }).toList();
  }

  Future<List<BudgetOptimization>> _generateOptimizations(
    List<CostBreakdown> categoryBreakdown,
    double totalBudget,
    double estimatedCost,
    String destination,
    int durationInDays,
    int travelers,
    List<String>? preferences,
  ) async {
    final optimizations = <BudgetOptimization>[];

    // Rule-based optimizations
    if (estimatedCost > totalBudget) {
      final overage = estimatedCost - totalBudget;
      
      // Find highest cost categories
      final sortedCategories = List<CostBreakdown>.from(categoryBreakdown)
        ..sort((a, b) => b.estimatedCost.compareTo(a.estimatedCost));

      for (final category in sortedCategories.take(3)) {
        final potentialSavings = category.estimatedCost * 0.15; // 15% reduction possible
        
        if (potentialSavings > 0) {
          optimizations.add(BudgetOptimization(
            category: category.categoryName,
            suggestion: _getOptimizationSuggestion(category.category, destination),
            potentialSavings: potentialSavings,
            impact: potentialSavings > overage * 0.3 ? 'high' : 'medium',
          ));
        }
      }
    }

    // AI-powered optimizations if available
    if (_aiModel != null) {
      try {
        final aiOptimizations = await _getAIOptimizations(
          categoryBreakdown,
          totalBudget,
          estimatedCost,
          destination,
          durationInDays,
          travelers,
          preferences,
        );
        optimizations.addAll(aiOptimizations);
      } catch (e) {
        print('AI optimization failed: $e');
        // Continue with rule-based optimizations
      }
    }

    return optimizations;
  }

  Future<List<BudgetOptimization>> _getAIOptimizations(
    List<CostBreakdown> categoryBreakdown,
    double totalBudget,
    double estimatedCost,
    String destination,
    int durationInDays,
    int travelers,
    List<String>? preferences,
  ) async {
    if (_aiModel == null) return [];

    final prompt = '''
You are a travel budget optimization expert. Analyze the following trip budget and provide 3-5 specific, actionable optimization suggestions.

Trip Details:
- Destination: $destination
- Duration: $durationInDays days
- Travelers: $travelers
- Total Budget: ₹${totalBudget.toStringAsFixed(0)}
- Estimated Cost: ₹${estimatedCost.toStringAsFixed(0)}

Budget Breakdown:
${categoryBreakdown.map((c) => '- ${c.categoryName}: ₹${c.estimatedCost.toStringAsFixed(0)} (${c.percentage.toStringAsFixed(1)}%)').join('\n')}

${preferences != null && preferences.isNotEmpty ? 'Preferences: ${preferences.join(', ')}' : ''}

Provide optimization suggestions in this format (one per line):
CATEGORY|SUGGESTION|SAVINGS_AMOUNT|IMPACT

Where:
- CATEGORY: One of: Accommodation, Food, Transportation, Activities, Shopping
- SUGGGESTION: Specific actionable advice (max 100 characters)
- SAVINGS_AMOUNT: Estimated savings in INR (just the number)
- IMPACT: low, medium, or high

Example:
Accommodation|Book hotels 2-3 weeks in advance for better rates|2000|high
''';

    try {
      final response = await _aiModel!.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      
      return _parseAIOptimizations(text);
    } catch (e) {
      print('Error getting AI optimizations: $e');
      return [];
    }
  }

  List<BudgetOptimization> _parseAIOptimizations(String aiResponse) {
    final optimizations = <BudgetOptimization>[];
    final lines = aiResponse.split('\n').where((l) => l.trim().isNotEmpty).toList();
    
    for (final line in lines) {
      final parts = line.split('|');
      if (parts.length >= 4) {
        try {
          final category = parts[0].trim();
          final suggestion = parts[1].trim();
          final savings = double.tryParse(parts[2].trim()) ?? 0.0;
          final impact = parts[3].trim().toLowerCase();
          
          if (savings > 0 && ['low', 'medium', 'high'].contains(impact)) {
            optimizations.add(BudgetOptimization(
              category: category,
              suggestion: suggestion,
              potentialSavings: savings,
              impact: impact,
            ));
          }
        } catch (e) {
          // Skip malformed lines
          continue;
        }
      }
    }
    
    return optimizations;
  }

  Future<String?> _generateAIInsights(
    String destination,
    int durationInDays,
    int travelers,
    double totalBudget,
    double estimatedCost,
    List<CostBreakdown> categoryBreakdown,
    List<String>? preferences,
  ) async {
    if (_aiModel == null) return null;

    final prompt = '''
You are a travel budget advisor. Provide a brief, helpful insight (2-3 sentences) about this trip budget:

Destination: $destination
Duration: $durationInDays days
Travelers: $travelers
Budget: ₹${totalBudget.toStringAsFixed(0)}
Estimated Cost: ₹${estimatedCost.toStringAsFixed(0)}

${estimatedCost > totalBudget 
  ? '⚠️ The estimated cost exceeds the budget. Provide advice on how to bring costs down.'
  : '✅ The budget looks good. Provide tips to maximize value.'}

Keep response concise and actionable (max 150 words).
''';

    try {
      final response = await _aiModel!.generateContent([Content.text(prompt)]);
      return response.text;
    } catch (e) {
      print('Error generating AI insights: $e');
      return null;
    }
  }

  String _getCategoryDescription(
    BudgetCategory category,
    String destination,
    BudgetLevel budgetLevel,
  ) {
    switch (category) {
      case BudgetCategory.accommodation:
        return 'Hotels, hostels, or other lodging for $destination';
      case BudgetCategory.food:
        return 'Meals, snacks, and dining expenses';
      case BudgetCategory.transportation:
        return 'Local transport, taxis, and inter-city travel';
      case BudgetCategory.activities:
        return 'Attractions, tours, and entertainment';
      case BudgetCategory.shopping:
        return 'Souvenirs and shopping expenses';
      case BudgetCategory.emergency:
        return 'Emergency fund for unexpected expenses';
      case BudgetCategory.miscellaneous:
        return 'Other expenses and contingencies';
    }
  }

  String _getOptimizationSuggestion(BudgetCategory category, String destination) {
    switch (category) {
      case BudgetCategory.accommodation:
        return 'Consider booking accommodations 2-3 weeks in advance or look for hostels/guesthouses for better rates';
      case BudgetCategory.food:
        return 'Mix of local street food and restaurants can reduce food costs by 20-30%';
      case BudgetCategory.transportation:
        return 'Use public transport or shared rides instead of private taxis to save significantly';
      case BudgetCategory.activities:
        return 'Look for combo tickets or group discounts for attractions';
      case BudgetCategory.shopping:
        return 'Set a shopping budget limit and stick to it';
      default:
        return 'Review expenses in this category for potential savings';
    }
  }

  BudgetCategory? _parseCategoryFromString(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('accommodation') || lower.contains('hotel')) {
      return BudgetCategory.accommodation;
    } else if (lower.contains('food') || lower.contains('dining')) {
      return BudgetCategory.food;
    } else if (lower.contains('transport')) {
      return BudgetCategory.transportation;
    } else if (lower.contains('activit')) {
      return BudgetCategory.activities;
    } else if (lower.contains('shop')) {
      return BudgetCategory.shopping;
    }
    return null;
  }

  IconData _getIconForCategory(BudgetCategory category) {
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


