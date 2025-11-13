# KNN Algorithm - Detailed Example Walkthrough

## Scenario: Looking for a Ride to Bangalore

**Your Query Ride:**
```
Pickup:     Kochi
Destination: Bangalore  
Date:        Jan 15, 2024
Time:        10:00 AM
Cost:        ₹800 per seat
Seats:       3 available
Vehicle:     Toyota Innova
```

---

## Available Rides in Database

### Ride A
- **Pickup:** Kochi Airport → **Destination:** Bangalore
- **Date:** Jan 15, 2024 (same day)
- **Time:** 10:30 AM (30 min difference)
- **Cost:** ₹850
- **Seats:** 2 available
- **Vehicle:** Toyota Innova

### Ride B
- **Pickup:** Kochi → **Destination:** Mysore (close to Bangalore)
- **Date:** Jan 16, 2024 (next day)
- **Time:** 9:00 AM
- **Cost:** ₹900
- **Seats:** 3 available
- **Vehicle:** Honda City

### Ride C
- **Pickup:** Trivandrum → **Destination:** Chennai
- **Date:** Jan 20, 2024 (5 days later)
- **Time:** 6:00 PM
- **Cost:** ₹1200
- **Seats:** 5 available
- **Vehicle:** Maruti Swift

---

## STEP 1: Calculate Similarity for Ride A

### Feature 1: Pickup Location Similarity (25% weight)

**Query:** "Kochi" (6 characters)
**Ride A:** "Kochi Airport" (13 characters)

Using **Levenshtein Distance**:
- Need 7 character edits to make "Kochi" → "Kochi Airport"
- Max length: 13
- Similarity = 1.0 - (7/13) = **0.538** (53.8%)

**Weighted Score:** 0.538 × 0.25 = **0.134**

---

### Feature 2: Destination Similarity (25% weight)

**Query:** "Bangalore" 
**Ride A:** "Bangalore"

Perfect match! Similarity = **1.0** (100%)

**Weighted Score:** 1.0 × 0.25 = **0.25**

---

### Feature 3: Date Similarity (15% weight)

**Query:** Jan 15, 2024
**Ride A:** Jan 15, 2024

Same day! Difference = 0 days

Using exponential decay: e^(-0 / 7) = e^0 = **1.0** (100%)

**Weighted Score:** 1.0 × 0.15 = **0.15**

---

### Feature 4: Time Similarity (15% weight)

**Query:** 10:00 AM → 600 minutes from midnight
**Ride A:** 10:30 AM → 630 minutes from midnight
**Difference:** 30 minutes

Using exponential decay: e^(-30 / 120) = e^(-0.25) = **0.779** (77.9%)

**Weighted Score:** 0.779 × 0.15 = **0.117**

---

### Feature 5: Cost Similarity (10% weight)

**Query:** ₹800
**Ride A:** ₹850
**Difference:** ₹50

Normalized: 1.0 - (50 / 2000) = 1.0 - 0.025 = **0.975** (97.5%)

**Weighted Score:** 0.975 × 0.10 = **0.098**

---

### Feature 6: Seats Similarity (5% weight)

**Query:** 3 seats
**Ride A:** 2 seats
**Difference:** 1 seat

Normalized: 1.0 - (1 / 8) = 1.0 - 0.125 = **0.875** (87.5%)

**Weighted Score:** 0.875 × 0.05 = **0.044**

---

### Feature 7: Vehicle Similarity (5% weight)

**Query:** "Toyota Innova"
**Ride A:** "Toyota Innova"

Perfect match! Similarity = **1.0** (100%)

**Weighted Score:** 1.0 × 0.05 = **0.05**

---

## STEP 2: Total Score for Ride A

**Total Similarity Score = 0.134 + 0.25 + 0.15 + 0.117 + 0.098 + 0.044 + 0.05**
**= 0.843 (84.3%)**

---

## STEP 3: Calculate Similarity for Ride B

### Quick Calculation Summary:
- **Location:** Kochi vs Kochi = 1.0 × 0.25 = **0.25**
- **Destination:** Bangalore vs Mysore (different city) = 0.6 × 0.25 = **0.15**
- **Date:** Next day (1 day diff) = e^(-1/7) = 0.867 × 0.15 = **0.130**
- **Time:** 9:00 vs 10:00 (1 hour) = e^(-60/120) = 0.606 × 0.15 = **0.091**
- **Cost:** ₹800 vs ₹900 = 1.0 - (100/2000) = 0.95 × 0.10 = **0.095**
- **Seats:** 3 vs 3 = 1.0 × 0.05 = **0.05**
- **Vehicle:** Different models = 0.3 × 0.05 = **0.015**

**Total for Ride B: 0.781 (78.1%)**

---

## STEP 4: Calculate Similarity for Ride C

### Quick Calculation Summary:
- **Location:** Kochi vs Trivandrum = 0.4 × 0.25 = **0.10**
- **Destination:** Bangalore vs Chennai = 0.2 × 0.25 = **0.05**
- **Date:** 5 days later = e^(-5/7) = 0.489 × 0.15 = **0.073**
- **Time:** 10:00 vs 18:00 (8 hours) = e^(-480/120) = 0.018 × 0.15 = **0.003**
- **Cost:** ₹800 vs ₹1200 = 1.0 - (400/2000) = 0.8 × 0.10 = **0.08**
- **Seats:** 3 vs 5 = 1.0 - (2/8) = 0.75 × 0.05 = **0.038**
- **Vehicle:** Different models = 0.3 × 0.05 = **0.015**

**Total for Ride C: 0.359 (35.9%)**

---

## STEP 5: Rank the Results

| Ride | Total Score | Rank | Description |
|------|-------------|------|-------------|
| **Ride A** | **84.3%** | 🥇 #1 | Very Similar - Perfect match! |
| **Ride B** | **78.1%** | 🥈 #2 | Similar - Close match |
| **Ride C** | **35.9%** | 🥉 #3 | Different - Not recommended |

---

## STEP 6: Return Top K Results (K=3)

KNN returns:
```
1. Ride A: 84.3% similar ⭐⭐⭐⭐⭐
   - Same destination (Bangalore)
   - Same date
   - Same vehicle
   - Minor differences in location and time
   
2. Ride B: 78.1% similar ⭐⭐⭐⭐
   - Different destination (Mysore)
   - Next day
   - Different vehicle
   
3. Ride C: 35.9% similar ⭐
   - Very different destination (Chennai)
   - Much later date
   - Different location, time, cost
```

---

## Real-World Application Flow

```
1. User enters: "Looking for Kochi → Bangalore on Jan 15"
   
2. KNN Algorithm:
   ├─ Compares your query with ALL rides in database
   ├─ Calculates 7 similarity scores for each ride
   ├─ Combines scores with weighted average
   └─ Ranks rides from most to least similar

3. Returns Top K=5 most similar rides:
   ├─ Ride A: 84.3% - Excellent match!
   ├─ Ride B: 78.1% - Good alternative
   ├─ Ride C: 65.2% - Acceptable
   ├─ Ride D: 52.8% - Marginal
   └─ Ride E: 45.1% - Below threshold

4. Display in UI:
   ┌───────────────────────────────────┐
   │ ⭐ Recommended for You (KNN)       │
   ├───────────────────────────────────┤
   │ 🥇 Kochi Airport → Bangalore       │
   │    Jan 15, 10:30 • ₹850 • 84%     │
   │                                    │
   │ 🥈 Kochi → Mysore                  │
   │    Jan 16, 9:00 • ₹900 • 78%      │
   └───────────────────────────────────┘
```

---

## Why This Works

### ✅ **Multi-Factor Matching**
- Doesn't just look at location
- Considers time, cost, vehicle, etc.

### ✅ **Weighted Importance**
- Location matters more (50% combined)
- Vehicle matters less (5%)

### ✅ **Temporal Intelligence**
- Same day = high score
- 1 week later = low score
- Uses exponential decay (realistic!)

### ✅ **Tolerates Partial Matches**
- Even if cost is different, still recommended
- Combines multiple imperfect features into a good match

---

## Advanced Example: User Preference Learning

Let's say you've previously requested:
- Kochi → Mumbai (multiple times)
- Bangalore → Delhi
- Chennai → Bangalore

KNN learns your patterns:
```
Pattern 1: You prefer South Indian cities
Pattern 2: You like morning departures (9-11 AM)
Pattern 3: You budget around ₹500-900

Next time you search:
Query: "Mumbai trips"
KNN finds:
  - Kochi → Mumbai (matches your origin preference)
  - Morning departure (matches time preference)
  - ₹650 (matches budget)
  Result: 89% similarity → Highly Recommended!
```

---

## Code Example

```dart
// In your app
final knnService = KnnService(k: 5);

// Your search query
final mySearch = RideOffer(
  destination: 'Bangalore',
  pickupLocation: 'Kochi',
  pickupDate: DateTime(2024, 1, 15),
  pickupTime: '10:00',
  costPerSeat: 800.0,
  availableSeats: 3,
  vehicleModel: 'Toyota Innova',
);

// Find similar rides
final similarRides = knnService.findSimilarRides(mySearch, allRides);

// Display results
for (final result in similarRides) {
  print('${result.similarityPercentage} similar');
  print('Route: ${result.ride.pickupLocation} → ${result.ride.destination}');
  print('Cost: ₹${result.ride.costPerSeat}');
  print('Match: ${result.similarityDescription}\n');
}
```

**Output:**
```
84.3% similar
Route: Kochi Airport → Bangalore
Cost: ₹850
Match: Very Similar

78.1% similar
Route: Kochi → Mysore
Cost: ₹900
Match: Similar
```

This is how KNN provides intelligent, multi-factor ride recommendations in your Trip Genie app!


