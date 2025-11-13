# KNN Algorithm Implementation in Trip Genie

## Overview

I've successfully implemented the **K-Nearest Neighbors (KNN)** algorithm for intelligent ride recommendations in your Trip Genie application. This machine learning integration helps users find rides that match their preferences based on multiple features.

## Files Created/Modified

### 1. **New File: `lib/services/knn_service.dart`**
   - Core KNN algorithm implementation
   - Handles similarity calculations across multiple ride features
   - Configurable feature weights for personalized recommendations

### 2. **Modified: `lib/services/ride_matching_service.dart`**
   - Integrated KNN service into the ride matching service
   - Added `findSimilarRides()` method
   - Added `getRecommendedRides()` method for personalized recommendations
   - Added methods to customize KNN weights

### 3. **Modified: `lib/screens/find_rides_screen.dart`**
   - Added "Recommended for You" section powered by KNN
   - Visual indicator showing "ML Powered" recommendations
   - Horizontal scrollable list of recommended rides

## How KNN Works in This Implementation

### Features Considered

The algorithm evaluates rides based on 7 key features:

1. **Pickup Location** (25% weight)
   - String similarity using Levenshtein distance
   - Finds rides from similar locations

2. **Destination** (25% weight)
   - Matches rides going to similar destinations

3. **Pickup Date** (15% weight)
   - Considers temporal proximity
   - Rides on the same day or close dates score higher

4. **Pickup Time** (15% weight)
   - Evaluates time similarity
   - Considers rides at similar times as more relevant

5. **Cost per Seat** (10% weight)
   - Compares pricing
   - Finds rides with similar costs

6. **Available Seats** (5% weight)
   - Matches ride capacity

7. **Vehicle Model** (5% weight)
   - Considers vehicle type similarity

### Similarity Scoring

Each feature is scored from **0.0 to 1.0**, then combined with weighted average:

```
Total Similarity = Σ (Feature_Score × Feature_Weight)
```

### Key Components

#### 1. Levenshtein Distance Algorithm
```dart
int _levenshteinDistance(String str1, String str2)
```
- Calculates minimum character edits needed to transform one string into another
- Used for location and vehicle model similarity

#### 2. Date Similarity
```dart
double _calculateDateSimilarity(DateTime date1, DateTime date2)
```
- Uses exponential decay formula
- Same day = 100% similarity
- 7 days difference ≈ 37% similarity

#### 3. Time Similarity
```dart
double _calculateTimeSimilarity(String time1, String time2)
```
- Converts time to minutes for comparison
- Same time = 100% similarity
- 2-hour difference ≈ 37% similarity

#### 4. Numeric Similarity
```dart
double _calculateNumericSimilarity(double value1, double value2)
```
- Normalizes difference within a maximum range
- Used for cost and seat comparison

## Usage Examples

### 1. Finding Similar Rides

```dart
final knnService = KnnService(k: 5); // Find top 5 similar rides
final similarRides = knnService.findSimilarRides(queryRide, allRides);

for (final result in similarRides) {
  print('Ride: ${result.ride.destination}');
  print('Similarity: ${result.similarityScore}'); // 0.0 to 1.0
  print('Percentage: ${result.similarityPercentage}'); // e.g., "85.3%"
  print('Description: ${result.similarityDescription}'); // e.g., "Very Similar"
}
```

### 2. Getting Personalized Recommendations

```dart
final rideService = RideMatchingService();
final recommendations = await rideService.getRecommendedRides(userId);

// Returns rides based on user's previous preferences
```

### 3. Customizing Feature Weights

```dart
rideService.updateKnnWeights({
  'pickupLocation': 0.30,  // Increase location importance
  'destination': 0.30,
  'date': 0.10,
  'time': 0.10,
  'cost': 0.10,
  'seats': 0.05,
  'vehicleModel': 0.05,
});
```

### 4. Getting Detailed Similarity Breakdown

```dart
final breakdown = knnService.getSimilarityBreakdown(ride1, ride2);
print(breakdown); 
// {
//   'pickupLocation': 0.85,
//   'destination': 0.92,
//   'date': 0.75,
//   'time': 0.60,
//   'cost': 0.80,
//   'seats': 0.67,
//   'vehicleModel': 0.50,
// }
```

## How Recommendations Work

1. **User History Analysis**
   - System fetches user's previous ride requests
   - Identifies preferred routes and patterns

2. **Pattern Recognition**
   - Uses most recent ride preferences as query
   - Finds K nearest neighbors based on all features

3. **Personalized Results**
   - Returns top K most similar rides
   - Scores each ride with similarity percentage

## UI Integration

The Find Rides screen now displays:

```
┌─────────────────────────────────────┐
│ ⭐ Recommended for You (KNN) 🧠      │
│ [ML Powered badge]                   │
├─────────────────────────────────────┤
│ [← Scroll horizontally →]            │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐  │
│ │ Ride 1  │ │ Ride 2  │ │ Ride 3  │  │
│ │ 85% sim │ │ 78% sim │ │ 72% sim │  │
│ └─────────┘ └─────────┘ └─────────┘  │
├─────────────────────────────────────┤
│ 📋 All Available Rides               │
│ (Standard list view)                 │
└─────────────────────────────────────┘
```

## Benefits

1. **Improved User Experience**
   - Users see relevant rides first
   - Reduces search time

2. **Personalization**
   - Learns from user behavior
   - Adapts to preferences over time

3. **Smart Matching**
   - Considers multiple factors simultaneously
   - Not just simple filters

4. **Scalable**
   - Easy to adjust feature weights
   - Can add more features in future

## Testing

To test the implementation:

1. Create sample ride offers using the "Create Sample Offers" button
2. Request a ride to build your preference history
3. Return to Find Rides screen to see recommendations
4. Watch the "Recommended for You" section populate with similar rides

## Customization Options

### Changing K Value
```dart
final knnService = KnnService(k: 10); // Get top 10 instead of 5
```

### Adjusting Feature Importance
```dart
// Prefer location over everything else
knnService.updateFeatureWeight('pickupLocation', 0.50);
knnService.normalizeWeights(); // Ensure weights sum to 1.0
```

### Different Similarity Thresholds
```dart
// In knn_service.dart, adjust decay factors:
// For date: exp(-difference / 7.0)  // 7 days = 37% similarity
// For time: exp(-difference / 120.0) // 2 hours = 37% similarity
```

## Performance Considerations

- **Time Complexity**: O(n) where n = number of rides
- **Space Complexity**: O(k) where k = number of neighbors
- Computationally efficient for typical ride-sharing datasets
- Real-time recommendations for instant feedback

## Future Enhancements

1. **Geographic Distance**: Use actual coordinates for location similarity
2. **User Ratings**: Factor in rider/driver ratings
3. **Time of Day Preferences**: Learn preferred travel times
4. **Price Sensitivity**: Consider budget constraints
5. **Collaborative Filtering**: Learn from similar users

## Technical Notes

- Uses **exponential decay** for temporal features (date, time)
- **Normalized difference** for numeric features
- **Levenshtein distance** for string matching
- **Weighted average** for composite similarity
- All scores clamped between 0.0 and 1.0 for consistency

## Integration Status

✅ KNN Service Created
✅ Ride Matching Integration  
✅ UI Updates Complete
✅ No Linting Errors
✅ Ready for Testing

The KNN implementation is now fully integrated into your Trip Genie application!


