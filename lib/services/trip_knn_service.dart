import 'dart:math';

/// Lightweight Trip model used only for similarity comparisons in the UI.
class TripLite {
  final String id;
  final String destination;
  final int? durationInDays;
  final List<String> interests;
  final String? budget; // e.g., 'low', 'medium', 'high'
  final DateTime? createdAt;

  TripLite({
    required this.id,
    required this.destination,
    required this.durationInDays,
    required this.interests,
    required this.budget,
    required this.createdAt,
  });

  static TripLite fromFirestore(Map<String, dynamic> data) {
    return TripLite(
      id: (data['id'] as String?) ?? '',
      destination: (data['destination'] as String?)?.trim() ?? '',
      durationInDays: data['durationInDays'] as int?,
      interests: ((data['interests'] as List?)?.cast<String>()) ?? const [],
      budget: data['budget'] as String?,
      createdAt: null,
    );
  }
}

/// Trip KNN service that ranks trips similar to a query trip.
class TripKnnService {
  final int k;
  TripKnnService({this.k = 5});

  // Feature weights (must sum roughly to 1.0)
  final Map<String, double> featureWeights = {
    'destination': 0.45, // destination matters most
    'duration': 0.20,
    'interests': 0.25,
    'budget': 0.10,
  };

  List<TripSimilarityResult> findSimilarTrips(TripLite query, List<TripLite> all) {
    if (all.isEmpty) return [];

    final results = <TripSimilarityResult>[];
    for (final t in all) {
      if (t.id == query.id) continue;
      final score = _similarity(query, t);
      results.add(TripSimilarityResult(trip: t, similarity: score));
    }
    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    return results.take(k).toList();
  }

  double _similarity(TripLite a, TripLite b) {
    double total = 0.0;

    // destination (string similarity)
    final destSim = _stringSimilarity(a.destination, b.destination);
    total += destSim * featureWeights['destination']!;

    // duration (numeric similarity)
    final durSim = _numericSimilarity(
      (a.durationInDays ?? 0).toDouble(),
      (b.durationInDays ?? 0).toDouble(),
      maxRange: 30.0,
    );
    total += durSim * featureWeights['duration']!;

    // interests (Jaccard)
    final intSim = _jaccardSimilarity(a.interests, b.interests);
    total += intSim * featureWeights['interests']!;

    // budget (categorical exact/near match)
    final budSim = _budgetSimilarity(a.budget, b.budget);
    total += budSim * featureWeights['budget']!;

    return total.clamp(0.0, 1.0);
  }

  double _stringSimilarity(String x, String y) {
    if (x.isEmpty && y.isEmpty) return 1.0;
    if (x.toLowerCase() == y.toLowerCase()) return 1.0;
    final d = _levenshtein(x.toLowerCase(), y.toLowerCase());
    final m = max(x.length, y.length);
    if (m == 0) return 1.0;
    return (1.0 - d / m).clamp(0.0, 1.0);
  }

  double _numericSimilarity(double a, double b, {required double maxRange}) {
    final diff = (a - b).abs();
    return (1.0 - (diff / maxRange)).clamp(0.0, 1.0);
  }

  double _jaccardSimilarity(List<String> a, List<String> b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    final sa = a.map((e) => e.toLowerCase()).toSet();
    final sb = b.map((e) => e.toLowerCase()).toSet();
    final inter = sa.intersection(sb).length;
    final union = sa.union(sb).length;
    if (union == 0) return 0.0;
    return inter / union;
  }

  double _budgetSimilarity(String? a, String? b) {
    if (a == null || b == null) return 0.0;
    if (a == b) return 1.0;
    // Simple adjacency: low~medium, medium~high considered 0.5 similar
    final order = ['low', 'medium', 'high'];
    final ia = order.indexOf(a.toLowerCase());
    final ib = order.indexOf(b.toLowerCase());
    if (ia == -1 || ib == -1) return 0.0;
    return (ia - ib).abs() == 1 ? 0.5 : 0.0;
  }

  int _levenshtein(String s, String t) {
    final m = s.length, n = t.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (int i = 0; i <= m; i++) dp[i][0] = i;
    for (int j = 0; j <= n; j++) dp[0][j] = j;
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (s[i - 1] == t[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 + min(dp[i - 1][j - 1], min(dp[i - 1][j], dp[i][j - 1]));
        }
      }
    }
    return dp[m][n];
  }
}

class TripSimilarityResult {
  final TripLite trip;
  final double similarity;
  TripSimilarityResult({required this.trip, required this.similarity});

  String get similarityPercent => '${(similarity * 100).toStringAsFixed(1)}%';
}



