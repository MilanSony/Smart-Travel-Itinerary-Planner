import '../models/ride_model.dart';
import 'dart:math';

/// KNN Service for finding similar rides based on multiple features
/// 
/// This service implements the K-Nearest Neighbors algorithm to find
/// rides that are most similar to a given query ride based on features like:
/// - Pickup location similarity
/// - Destination similarity
/// - Pickup date/time proximity
/// - Cost per seat similarity
/// - Available seats similarity
/// - Vehicle model similarity
class KnnService {
  /// Configuration weights for different features
  /// Adjust these weights to prioritize certain features over others
  final Map<String, double> featureWeights = {
    'pickupLocation': 0.25,   // 25% weight
    'destination': 0.25,      // 25% weight
    'date': 0.15,             // 15% weight
    'time': 0.15,             // 15% weight
    'cost': 0.10,             // 10% weight
    'seats': 0.05,            // 5% weight
    'vehicleModel': 0.05,     // 5% weight
  };

  /// Number of nearest neighbors to find (K value)
  final int k;

  KnnService({this.k = 5});

  /// Finds K nearest similar rides to a given query ride
  /// 
  /// [queryRide] The ride to find similar rides for
  /// [allRides] List of all available rides to search from
  /// 
  /// Returns a list of similar rides sorted by similarity score (highest first)
  List<RideSimilarityResult> findSimilarRides(
    RideOffer queryRide,
    List<RideOffer> allRides,
  ) {
    if (allRides.isEmpty) return [];

    // Calculate similarity scores for all rides
    final List<RideSimilarityResult> similarities = [];

    for (final ride in allRides) {
      // Skip if it's the same ride
      if (ride.id == queryRide.id) continue;

      // Calculate overall similarity score
      final similarity = _calculateSimilarity(queryRide, ride);

      similarities.add(
        RideSimilarityResult(
          ride: ride,
          similarityScore: similarity,
        ),
      );
    }

    // Sort by similarity score (highest first) and return top K
    similarities.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    return similarities.take(k).toList();
  }

  /// Calculates the overall similarity score between two rides
  /// 
  /// Returns a score between 0.0 (completely different) and 1.0 (identical)
  double _calculateSimilarity(RideOffer ride1, RideOffer ride2) {
    double totalScore = 0.0;

    // Feature 1: Pickup Location Similarity
    final locationSimilarity = _calculateStringSimilarity(
      ride1.pickupLocation,
      ride2.pickupLocation,
    );
    totalScore += locationSimilarity * featureWeights['pickupLocation']!;

    // Feature 2: Destination Similarity
    final destinationSimilarity = _calculateStringSimilarity(
      ride1.destination,
      ride2.destination,
    );
    totalScore += destinationSimilarity * featureWeights['destination']!;

    // Feature 3: Date Similarity
    final dateSimilarity = _calculateDateSimilarity(
      ride1.pickupDate,
      ride2.pickupDate,
    );
    totalScore += dateSimilarity * featureWeights['date']!;

    // Feature 4: Time Similarity
    final timeSimilarity = _calculateTimeSimilarity(
      ride1.pickupTime,
      ride2.pickupTime,
    );
    totalScore += timeSimilarity * featureWeights['time']!;

    // Feature 5: Cost Similarity
    final costSimilarity = _calculateNumericSimilarity(
      ride1.costPerSeat,
      ride2.costPerSeat,
      maxRange: 2000.0, // Assuming max cost difference of 2000
    );
    totalScore += costSimilarity * featureWeights['cost']!;

    // Feature 6: Seats Similarity
    final seatsSimilarity = _calculateNumericSimilarity(
      ride1.availableSeats.toDouble(),
      ride2.availableSeats.toDouble(),
      maxRange: 8.0, // Assuming max 8 seats
    );
    totalScore += seatsSimilarity * featureWeights['seats']!;

    // Feature 7: Vehicle Model Similarity
    final modelSimilarity = _calculateStringSimilarity(
      ride1.vehicleModel,
      ride2.vehicleModel,
    );
    totalScore += modelSimilarity * featureWeights['vehicleModel']!;

    return totalScore.clamp(0.0, 1.0);
  }

  /// Calculates similarity between two strings using Levenshtein distance
  /// 
  /// Returns a score between 0.0 (completely different) and 1.0 (identical)
  double _calculateStringSimilarity(String str1, String str2) {
    if (str1.toLowerCase() == str2.toLowerCase()) return 1.0;
    
    final distance = _levenshteinDistance(
      str1.toLowerCase(),
      str2.toLowerCase(),
    );
    
    final maxLength = str1.length > str2.length ? str1.length : str2.length;
    
    if (maxLength == 0) return 1.0;
    
    return 1.0 - (distance / maxLength);
  }

  /// Calculates similarity between two dates
  /// 
  /// Returns a score between 0.0 (very different dates) and 1.0 (same date)
  double _calculateDateSimilarity(DateTime date1, DateTime date2) {
    final difference = (date1.difference(date2).inDays).abs();
    
    // Calculate similarity: same day = 1.0, decreases with days difference
    // Using exponential decay for date similarity
    return exp(-difference / 7.0).clamp(0.0, 1.0); // 7 days = 37% similarity
  }

  /// Calculates similarity between two time strings (format: HH:MM)
  /// 
  /// Returns a score between 0.0 (very different times) and 1.0 (same time)
  double _calculateTimeSimilarity(String time1, String time2) {
    try {
      final parts1 = time1.split(':');
      final parts2 = time2.split(':');
      
      if (parts1.length != 2 || parts2.length != 2) return 0.5;
      
      final hour1 = int.parse(parts1[0]);
      final minute1 = int.parse(parts1[1]);
      final hour2 = int.parse(parts2[0]);
      final minute2 = int.parse(parts2[1]);
      
      final minutes1 = hour1 * 60 + minute1;
      final minutes2 = hour2 * 60 + minute2;
      
      final difference = (minutes1 - minutes2).abs();
      
      // Calculate similarity: same time = 1.0, decreases with minutes difference
      // Using exponential decay for time similarity (1 hour = 60 minutes)
      return exp(-difference / 120.0).clamp(0.0, 1.0); // 2 hours = 37% similarity
    } catch (e) {
      return 0.5; // Default similarity if parsing fails
    }
  }

  /// Calculates similarity between two numeric values
  /// 
  /// Returns a score between 0.0 (very different values) and 1.0 (same value)
  double _calculateNumericSimilarity(double value1, double value2, {required double maxRange}) {
    final difference = (value1 - value2).abs();
    
    if (difference == 0) return 1.0;
    
    // Calculate similarity using normalized difference
    final normalizedDiff = difference / maxRange;
    return (1.0 - normalizedDiff).clamp(0.0, 1.0);
  }

  /// Calculates Levenshtein distance between two strings
  /// 
  /// Returns the minimum number of single-character edits needed to transform
  /// one string into another
  int _levenshteinDistance(String str1, String str2) {
    final m = str1.length;
    final n = str2.length;

    // Create a 2D array to store distances
    final List<List<int>> dp = List.generate(
      m + 1,
      (_) => List.filled(n + 1, 0),
    );

    // Initialize base cases
    for (int i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    // Fill the distance table
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (str1[i - 1] == str2[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 + [
            dp[i - 1][j],      // deletion
            dp[i][j - 1],      // insertion
            dp[i - 1][j - 1],  // substitution
          ].reduce((a, b) => a < b ? a : b);
        }
      }
    }

    return dp[m][n];
  }

  /// Updates the weight for a specific feature
  void updateFeatureWeight(String feature, double weight) {
    if (featureWeights.containsKey(feature)) {
      featureWeights[feature] = weight.clamp(0.0, 1.0);
    }
  }

  /// Normalizes all feature weights to sum to 1.0
  void normalizeWeights() {
    final totalWeight = featureWeights.values.reduce((a, b) => a + b);
    
    if (totalWeight > 0) {
      for (final key in featureWeights.keys) {
        featureWeights[key] = featureWeights[key]! / totalWeight;
      }
    }
  }

  /// Gets a summary of why a ride is similar
  Map<String, double> getSimilarityBreakdown(RideOffer ride1, RideOffer ride2) {
    return {
      'pickupLocation': _calculateStringSimilarity(ride1.pickupLocation, ride2.pickupLocation),
      'destination': _calculateStringSimilarity(ride1.destination, ride2.destination),
      'date': _calculateDateSimilarity(ride1.pickupDate, ride2.pickupDate),
      'time': _calculateTimeSimilarity(ride1.pickupTime, ride2.pickupTime),
      'cost': _calculateNumericSimilarity(ride1.costPerSeat, ride2.costPerSeat, maxRange: 2000.0),
      'seats': _calculateNumericSimilarity(ride1.availableSeats.toDouble(), ride2.availableSeats.toDouble(), maxRange: 8.0),
      'vehicleModel': _calculateStringSimilarity(ride1.vehicleModel, ride2.vehicleModel),
    };
  }
}

/// Result class for similar rides
/// Contains the ride and its similarity score
class RideSimilarityResult {
  final RideOffer ride;
  final double similarityScore;
  final Map<String, double>? featureScores;

  RideSimilarityResult({
    required this.ride,
    required this.similarityScore,
    this.featureScores,
  });

  /// Returns a human-readable similarity percentage
  String get similarityPercentage => '${(similarityScore * 100).toStringAsFixed(1)}%';

  /// Returns a description of how similar the ride is
  String get similarityDescription {
    if (similarityScore >= 0.8) return 'Very Similar';
    if (similarityScore >= 0.6) return 'Similar';
    if (similarityScore >= 0.4) return 'Somewhat Similar';
    return 'Different';
  }
}


