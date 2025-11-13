import '../models/ride_model.dart';
import 'knn_service.dart';
import 'ride_matching_service.dart';

/// Demonstration of KNN Service Usage
/// 
/// This file shows various ways to use the KNN algorithm in Trip Genie
class KnnDemo {
  
  /// Example 1: Basic KNN Search
  /// Find similar rides to a given query ride
  static void basicSearch() {
    // Create KNN service with K=5 (finds top 5 similar rides)
    final knnService = KnnService(k: 5);
    
    // Example query ride
    final queryRide = RideOffer(
      id: 'q1',
      userId: 'user1',
      userName: 'John Doe',
      userEmail: 'john@example.com',
      destination: 'Bangalore',
      pickupLocation: 'Kochi Airport',
      pickupDate: DateTime(2024, 1, 15),
      pickupTime: '10:00',
      availableSeats: 3,
      costPerSeat: 800.0,
      vehicleNumber: 'KL-01-AB-1234',
      vehicleModel: 'Toyota Innova',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    // List of all available rides
    final allRides = [
      // Similar ride (should score high)
      RideOffer(
        id: 'r1',
        userId: 'user2',
        userName: 'Jane Smith',
        userEmail: 'jane@example.com',
        destination: 'Bangalore',
        pickupLocation: 'Kochi Airport',
        pickupDate: DateTime(2024, 1, 15),
        pickupTime: '10:30', // 30 min difference
        availableSeats: 2,
        costPerSeat: 850.0,
        vehicleNumber: 'KL-02-CD-5678',
        vehicleModel: 'Toyota Innova',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      
      // Somewhat similar ride
      RideOffer(
        id: 'r2',
        userId: 'user3',
        userName: 'Bob Wilson',
        userEmail: 'bob@example.com',
        destination: 'Mysore', // Different destination but close
        pickupLocation: 'Kochi',
        pickupDate: DateTime(2024, 1, 16), // Next day
        pickupTime: '09:00',
        availableSeats: 3,
        costPerSeat: 900.0,
        vehicleNumber: 'KL-03-EF-9012',
        vehicleModel: 'Honda City',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      
      // Different ride (should score lower)
      RideOffer(
        id: 'r3',
        userId: 'user4',
        userName: 'Alice Brown',
        userEmail: 'alice@example.com',
        destination: 'Chennai',
        pickupLocation: 'Mumbai',
        pickupDate: DateTime(2024, 2, 1), // Much later
        pickupTime: '18:00',
        availableSeats: 5,
        costPerSeat: 1200.0,
        vehicleNumber: 'MH-01-GH-3456',
        vehicleModel: 'Maruti Swift',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
    
    // Find similar rides
    final similarRides = knnService.findSimilarRides(queryRide, allRides);
    
    // Display results
    print('\n=== KNN Search Results ===');
    for (final result in similarRides) {
      print('\nRide: ${result.ride.id}');
      print('  Destination: ${result.ride.pickupLocation} → ${result.ride.destination}');
      print('  Similarity: ${result.similarityScore.toStringAsFixed(3)}');
      print('  Percentage: ${result.similarityPercentage}');
      print('  Description: ${result.similarityDescription}');
    }
  }
  
  /// Example 2: Getting Detailed Feature Breakdown
  static void detailedBreakdown() {
    final knnService = KnnService();
    
    final ride1 = RideOffer(
      id: 'ride1',
      userId: 'user1',
      userName: 'Driver 1',
      userEmail: 'driver1@example.com',
      destination: 'Kochi',
      pickupLocation: 'Thiruvananthapuram',
      pickupDate: DateTime(2024, 1, 20),
      pickupTime: '08:00',
      availableSeats: 2,
      costPerSeat: 500.0,
      vehicleNumber: 'KL-01-XX-0001',
      vehicleModel: 'Honda City',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    final ride2 = RideOffer(
      id: 'ride2',
      userId: 'user2',
      userName: 'Driver 2',
      userEmail: 'driver2@example.com',
      destination: 'Kochi',
      pickupLocation: 'Thiruvananthapuram',
      pickupDate: DateTime(2024, 1, 21), // Next day
      pickupTime: '08:30',
      availableSeats: 3,
      costPerSeat: 550.0,
      vehicleNumber: 'KL-02-YY-0002',
      vehicleModel: 'Honda City',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    // Get detailed similarity breakdown
    final breakdown = knnService.getSimilarityBreakdown(ride1, ride2);
    
    print('\n=== Detailed Similarity Breakdown ===');
    breakdown.forEach((feature, score) {
      print('$feature: ${(score * 100).toStringAsFixed(1)}%');
    });
  }
  
  /// Example 3: Customizing Feature Weights
  static void customWeights() {
    final knnService = KnnService(k: 3);
    
    // Scenario: User cares most about location and price
    knnService.updateFeatureWeight('pickupLocation', 0.40);
    knnService.updateFeatureWeight('destination', 0.30);
    knnService.updateFeatureWeight('cost', 0.20);
    knnService.updateFeatureWeight('date', 0.05);
    knnService.updateFeatureWeight('time', 0.05);
    knnService.normalizeWeights();
    
    print('\n=== Custom Feature Weights ===');
    knnService.featureWeights.forEach((feature, weight) {
      print('$feature: ${(weight * 100).toStringAsFixed(1)}%');
    });
  }
  
  /// Example 4: Using with Ride Matching Service
  static Future<void> personalizedRecommendations(String userId) async {
    final rideService = RideMatchingService();
    
    // Get personalized recommendations based on user history
    final recommendations = await rideService.getRecommendedRides(userId);
    
    print('\n=== Personalized Recommendations ===');
    print('Found ${recommendations.length} recommended rides for user: $userId');
    
    for (final ride in recommendations) {
      print('\n- ${ride.pickupLocation} → ${ride.destination}');
      print('  Date: ${ride.pickupDate.day}/${ride.pickupDate.month}');
      print('  Time: ${ride.pickupTime}');
      print('  Cost: ₹${ride.costPerSeat}');
      print('  Seats: ${ride.availableSeats}');
    }
  }
  
  /// Example 5: Finding Similarity Score Threshold
  static void thresholdFiltering(List<RideOffer> allRides, RideOffer queryRide) {
    final knnService = KnnService(k: allRides.length);
    
    final allSimilarities = knnService.findSimilarRides(queryRide, allRides);
    
    // Filter only highly similar rides (>70% similarity)
    final highlySimilar = allSimilarities
        .where((result) => result.similarityScore >= 0.70)
        .toList();
    
    print('\n=== Threshold Filtering (70% similarity) ===');
    print('Found ${highlySimilar.length} highly similar rides out of ${allSimilarities.length}');
    
    for (final result in highlySimilar) {
      print('\n${result.ride.pickupLocation} → ${result.ride.destination}');
      print('Similarity: ${result.similarityPercentage}');
    }
  }
  
  /// Example 6: Batch Processing Multiple Queries
  static void batchProcessing(List<RideOffer> allRides, List<RideOffer> queries) {
    final knnService = KnnService(k: 5);
    
    print('\n=== Batch Processing ===');
    for (int i = 0; i < queries.length; i++) {
      final query = queries[i];
      final results = knnService.findSimilarRides(query, allRides);
      
      print('\nQuery ${i + 1}: ${query.pickupLocation} → ${query.destination}');
      print('Found ${results.length} similar rides');
      
      if (results.isNotEmpty) {
        print('Best match: ${results.first.ride.pickupLocation} → ${results.first.ride.destination}');
        print('Similarity: ${results.first.similarityPercentage}');
      }
    }
  }
}

/// Example usage in your app
/// 
/// ```dart
/// // In your UI code
/// final recommendations = await rideService.getRecommendedRides(userId);
/// 
/// // Display recommended rides
/// for (final ride in recommendations) {
///   // Show in UI
/// }
/// ```
/// 
/// ```dart
/// // Custom KNN search for specific query
/// final knnService = KnnService(k: 10);
/// final similarRides = knnService.findSimilarRides(queryRide, allRides);
/// 
/// // Show similarity details
/// for (final result in similarRides) {
///   print('${result.similarityPercentage} similar to your search');
///   // Display in UI
/// }
/// ```


