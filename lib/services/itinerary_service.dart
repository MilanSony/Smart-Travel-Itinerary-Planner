
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/itinerary_model.dart';

// Budget level categories for smart cost estimation
enum BudgetLevel {
  budget,      // Low budget - backpacker style
  moderate,    // Mid-range budget - comfortable travel
  luxury,      // High budget - premium experience
}

class ItineraryService {
  static const String _userAgent = 'TripGenie/1.0 (Flutter App)';
  static const int _maxPlacesPerType = 20;
  static const int _maxPlacesPerDay = 6;
  // How many attractions per day to target (morning, afternoon, evening)
  static const int _targetAttractionsPerDay = 3;

  // Categorize budget level based on total budget, duration, and travelers
  BudgetLevel _categorizeBudgetLevel(double totalBudget, int durationInDays, int travelers) {
    final dailyBudgetPerPerson = totalBudget / (durationInDays * travelers);
    
    if (dailyBudgetPerPerson < 800) {
      return BudgetLevel.budget;      // Under ₹800 per person per day
    } else if (dailyBudgetPerPerson < 2000) {
      return BudgetLevel.moderate;    // ₹800-2000 per person per day
    } else {
      return BudgetLevel.luxury;      // Above ₹2000 per person per day
    }
  }

  // Get budget-appropriate cost for restaurants
  String _getBudgetAppropriateRestaurantCost(BudgetLevel budgetLevel, bool isDinner) {
    switch (budgetLevel) {
      case BudgetLevel.budget:
        return isDinner ? '₹100-300 per person' : '₹80-200 per person';
      case BudgetLevel.moderate:
        return isDinner ? '₹300-600 per person' : '₹200-400 per person';
      case BudgetLevel.luxury:
        return isDinner ? '₹600-1500 per person' : '₹400-800 per person';
    }
  }

  // Get budget-appropriate cost for attractions
  String _getBudgetAppropriateAttractionCost(BudgetLevel budgetLevel, String attractionType) {
    switch (budgetLevel) {
      case BudgetLevel.budget:
        switch (attractionType) {
          case 'museum': return '₹20-80 per person';
          case 'gallery': return '₹10-40 per person';
          case 'zoo': return '₹40-120 per person';
          case 'theme_park': return '₹150-600 per person';
          case 'monument': return '₹10-40 per person';
          case 'park': return '₹10-25 per person';
          default: return '₹20-80 per person';
        }
      case BudgetLevel.moderate:
        switch (attractionType) {
          case 'museum': return '₹40-150 per person';
          case 'gallery': return '₹25-100 per person';
          case 'zoo': return '₹80-200 per person';
          case 'theme_park': return '₹400-1000 per person';
          case 'monument': return '₹15-80 per person';
          case 'park': return '₹15-40 per person';
          default: return '₹40-150 per person';
        }
      case BudgetLevel.luxury:
        switch (attractionType) {
          case 'museum': return '₹80-300 per person';
          case 'gallery': return '₹80-250 per person';
          case 'zoo': return '₹150-400 per person';
          case 'theme_park': return '₹800-2000 per person';
          case 'monument': return '₹30-150 per person';
          case 'park': return '₹30-100 per person';
          default: return '₹80-300 per person';
        }
    }
  }

  // Get budget-appropriate transportation cost
  String _getBudgetAppropriateTransportCost(BudgetLevel budgetLevel, String transportation) {
    switch (budgetLevel) {
      case BudgetLevel.budget:
        switch (transportation.toLowerCase()) {
          case 'public transport': return '₹80-150 per person';
          case 'rental car': return '₹600-1200 per day';
          case 'bike sharing': return '₹40-120 per day';
          default: return '₹80-150 per person';
        }
      case BudgetLevel.moderate:
        switch (transportation.toLowerCase()) {
          case 'public transport': return '₹150-300 per person';
          case 'rental car': return '₹1200-2500 per day';
          case 'bike sharing': return '₹80-200 per day';
          default: return '₹150-300 per person';
        }
      case BudgetLevel.luxury:
        switch (transportation.toLowerCase()) {
          case 'public transport': return '₹300-600 per person';
          case 'rental car': return '₹2500-5000 per day';
          case 'bike sharing': return '₹150-400 per day';
          default: return '₹300-600 per person';
        }
    }
  }

  Future<Itinerary?> generateItinerary({
    required String destination,
    required int durationInDays,
    List<String> interests = const [],
    int travelers = 1,
    String? budget,
    String? transportation,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Parse budget and categorize budget level
    double? budgetAmount;
    BudgetLevel budgetLevel = BudgetLevel.moderate; // Default
    
    if (budget != null && budget.isNotEmpty) {
      budgetAmount = double.tryParse(budget);
      if (budgetAmount != null) {
        budgetLevel = _categorizeBudgetLevel(budgetAmount, durationInDays, travelers);
      }
    }
    // Wrap the main generation logic so we can apply a 15s ceiling with a fallback
    Future<Itinerary?> _generateCore() async {
    try {
      print('Starting itinerary generation for: $destination');
      
      // Step 1: Geocode the destination
      final geocodeData = await _geocodeDestination(destination);
      if (geocodeData == null) {
        print('No geocoding data found, trying fallback...');
          return _generateFallbackItinerary(destination, durationInDays, interests, travelers, startDate: startDate, endDate: endDate);
      }

      final displayName = geocodeData['display_name'];
      final List<dynamic> bbox = geocodeData['boundingbox'];
      final String bboxString = '${bbox[0]},${bbox[2]},${bbox[1]},${bbox[3]}';

      print('Geocoding successful: $displayName');
      print('Bounding box: $bboxString');

      // Step 2: Fetch comprehensive place data
      final places = await _fetchPlaces(bboxString, interests);
      if (places.isEmpty) {
        print('No places found, trying fallback...');
          return _generateFallbackItinerary(destination, durationInDays, interests, travelers, startDate: startDate, endDate: endDate);
      }

      // Step 3: Categorize and filter places
      final categorizedPlaces = _categorizePlaces(places);
      
      // Step 4: Generate smart itinerary
      final dayPlans = _generateSmartItinerary(
        categorizedPlaces, 
        durationInDays, 
        interests,
        travelers,
        budgetAmount,
        transportation,
        destination,
        budgetLevel,
      );

      if (dayPlans.isEmpty) {
        print('No day plans generated, trying fallback...');
          return _generateFallbackItinerary(destination, durationInDays, interests, travelers, startDate: startDate, endDate: endDate);
      }

      // Step 5: Calculate total cost
      double? totalCost;
      if (budgetAmount != null) {
        // Adjust day costs to match user's budget exactly
        _adjustDayCostsToMatchBudget(dayPlans, budgetAmount);
        totalCost = budgetAmount;
      } else {
        totalCost = _calculateBudgetAwareTotalCost(dayPlans, travelers, budgetLevel);
      }

      print('Itinerary generated successfully with ${dayPlans.length} days');

      return Itinerary(
        destination: displayName,
        title: 'Your Adventure in $destination',
        dayPlans: dayPlans,
        summary: _generateSummary(destination, durationInDays, interests),
        totalEstimatedCost: totalCost,
          startDate: startDate,
          endDate: endDate,
      );

    } catch (e) {
      print("Error generating itinerary with OSM: $e");
      print("Error type: ${e.runtimeType}");
      
      // Try fallback if network fails
      if (e.toString().contains('SocketException') || 
          e.toString().contains('HandshakeException') ||
          e.toString().contains('TimeoutException')) {
        print('Network error detected, trying fallback itinerary...');
        try {
            return _generateFallbackItinerary(destination, durationInDays, interests, travelers, startDate: startDate, endDate: endDate);
        } catch (fallbackError) {
          print('Fallback also failed: $fallbackError');
          throw Exception('Network connection error. Please check your internet connection and try again.');
        }
      } else {
        throw Exception('Failed to generate itinerary: ${e.toString()}');
      }
      }
    }

    // Enforce a 15-second ceiling; on timeout, immediately return fallback
    return await _generateCore().timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        print('Itinerary generation timed out after 15s - using fallback');
        return _generateFallbackItinerary(destination, durationInDays, interests, travelers, startDate: startDate, endDate: endDate);
      },
    );
  }

  /// Public method to get destination coordinates
  Future<Map<String, double>?> getDestinationCoordinates(String destination) async {
    try {
      // Try fallback first for faster response
      final fallbackCoords = _getFallbackCoordinates(destination);
      if (fallbackCoords != null) {
        print('Using fallback coordinates for: $destination');
        return fallbackCoords;
      }
      
      final geocodeData = await _geocodeDestination(destination);
      if (geocodeData == null) {
        // Try fallback as last resort
        final fallback = _getFallbackCoordinates(destination);
        return fallback;
      }
      
      final lat = geocodeData['lat'] is double 
          ? geocodeData['lat'] as double
          : double.tryParse(geocodeData['lat']?.toString() ?? '');
      final lon = geocodeData['lon'] is double
          ? geocodeData['lon'] as double
          : double.tryParse(geocodeData['lon']?.toString() ?? '');
      
      if (lat == null || lon == null) {
        // Try fallback as last resort
        final fallback = _getFallbackCoordinates(destination);
        return fallback;
      }
      
      return {'lat': lat, 'lon': lon};
    } catch (e) {
      print('Error getting coordinates: $e');
      // Try fallback as last resort
      final fallback = _getFallbackCoordinates(destination);
      return fallback;
    }
  }

  Future<Map<String, dynamic>?> _geocodeDestination(String destination) async {
    // Try fallback coordinates for common Indian cities first
    final fallbackCoords = _getFallbackCoordinates(destination);
    if (fallbackCoords != null) {
      print('Using fallback coordinates for: $destination');
      return {
        'lat': fallbackCoords['lat'],
        'lon': fallbackCoords['lon'],
        'display_name': destination,
        'boundingbox': [
          fallbackCoords['lat']! - 0.1,
          fallbackCoords['lat']! + 0.1,
          fallbackCoords['lon']! - 0.1,
          fallbackCoords['lon']! + 0.1,
        ],
      };
    }

    // Retry logic: try up to 3 times with increasing timeout
    int maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      final geocodeUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(destination)}&format=json&limit=1&addressdetails=1&accept-language=en'
      );
      
        print('Geocoding request for: $destination (Attempt $attempt/$maxRetries)');
      print('URL: $geocodeUrl');
        
        // Increase timeout with each retry: 15s, 20s, 25s
        final timeoutDuration = Duration(seconds: 15 + (attempt * 5));
      
      final response = await http.get(geocodeUrl, headers: {'User-Agent': _userAgent}).timeout(
          timeoutDuration,
        onTimeout: () {
            throw Exception('Geocoding timeout after ${timeoutDuration.inSeconds}s');
        },
      );

      print('Geocoding response status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('Geocoding failed with status: ${response.statusCode}');
          if (attempt < maxRetries) {
            print('Retrying...');
            await Future.delayed(Duration(seconds: attempt)); // Wait before retry
            continue;
          }
        throw Exception('Failed to geocode destination. Status: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      print('Geocoding data received: ${data.length} results');
      
      if (data.isEmpty) {
        print('No geocoding results found for: $destination');
        return null;
      }

      return data[0];
    } catch (e) {
        print('Geocoding error (Attempt $attempt): $e');
        if (attempt == maxRetries) {
          // Last attempt failed, try fallback coordinates
          print('All geocoding attempts failed, using fallback coordinates');
          final fallback = _getFallbackCoordinates(destination);
          if (fallback != null) {
            return {
              'lat': fallback['lat'],
              'lon': fallback['lon'],
              'display_name': destination,
              'boundingbox': [
                fallback['lat']! - 0.1,
                fallback['lat']! + 0.1,
                fallback['lon']! - 0.1,
                fallback['lon']! + 0.1,
              ],
            };
          }
          rethrow;
        }
        // Wait before retrying
        await Future.delayed(Duration(seconds: attempt));
      }
    }
    return null;
  }

  /// Get fallback coordinates for common Indian destinations
  Map<String, double>? _getFallbackCoordinates(String destination) {
    final destLower = destination.toLowerCase().trim();
    
    // Common Indian cities with their coordinates
    final cityCoords = {
      // Added: Gavi and Kanyakumari for hotel/transport suggestions
      'gavi': {'lat': 9.4300, 'lon': 77.1300},
      'kanyakumari': {'lat': 8.0883, 'lon': 77.5385},
      'cape comorin': {'lat': 8.0883, 'lon': 77.5385},
      'thiruvananthapuram': {'lat': 8.5244, 'lon': 76.9366},
      'trivandrum': {'lat': 8.5244, 'lon': 76.9366},
      'kochi': {'lat': 9.9312, 'lon': 76.2673},
      'cochin': {'lat': 9.9312, 'lon': 76.2673},
      'goa': {'lat': 15.2993, 'lon': 74.1240},
      'mumbai': {'lat': 19.0760, 'lon': 72.8777},
      'bombay': {'lat': 19.0760, 'lon': 72.8777},
      'delhi': {'lat': 28.6139, 'lon': 77.2090},
      'new delhi': {'lat': 28.6139, 'lon': 77.2090},
      'bangalore': {'lat': 12.9716, 'lon': 77.5946},
      'bengaluru': {'lat': 12.9716, 'lon': 77.5946},
      'chennai': {'lat': 13.0827, 'lon': 80.2707},
      'madras': {'lat': 13.0827, 'lon': 80.2707},
      'hyderabad': {'lat': 17.3850, 'lon': 78.4867},
      'kolkata': {'lat': 22.5726, 'lon': 88.3639},
      'calcutta': {'lat': 22.5726, 'lon': 88.3639},
      'pune': {'lat': 18.5204, 'lon': 73.8567},
      'jaipur': {'lat': 26.9124, 'lon': 75.7873},
      'udaipur': {'lat': 24.5854, 'lon': 73.7125},
      'jodhpur': {'lat': 26.2389, 'lon': 73.0243},
      'jaisalmer': {'lat': 26.9157, 'lon': 70.9083},
      'manali': {'lat': 32.2432, 'lon': 77.1892},
      'shimla': {'lat': 31.1048, 'lon': 77.1734},
      'darjeeling': {'lat': 27.0360, 'lon': 88.2627},
      'mysore': {'lat': 12.2958, 'lon': 76.6394},
      'mysuru': {'lat': 12.2958, 'lon': 76.6394},
      'munnar': {'lat': 10.0889, 'lon': 77.0595},
      'ooty': {'lat': 11.4102, 'lon': 76.6950},
      'udagamandalam': {'lat': 11.4102, 'lon': 76.6950},
      'kodaikanal': {'lat': 10.2381, 'lon': 77.4892},
      'coorg': {'lat': 12.3375, 'lon': 75.8069},
      'kodagu': {'lat': 12.3375, 'lon': 75.8069},
      'hampi': {'lat': 15.3350, 'lon': 76.4600},
      'rishikesh': {'lat': 30.0869, 'lon': 78.2676},
      'haridwar': {'lat': 29.9457, 'lon': 78.1642},
      'varanasi': {'lat': 25.3176, 'lon': 82.9739},
      'banaras': {'lat': 25.3176, 'lon': 82.9739},
      'kashi': {'lat': 25.3176, 'lon': 82.9739},
      'port blair': {'lat': 11.6234, 'lon': 92.7265},
      'andaman': {'lat': 11.6234, 'lon': 92.7265},
      'havelock': {'lat': 11.9689, 'lon': 93.0014},
      'leh': {'lat': 34.1526, 'lon': 77.5771},
      'ladakh': {'lat': 34.1526, 'lon': 77.5771},
      'manali': {'lat': 32.2432, 'lon': 77.1892},
      'shimla': {'lat': 31.1048, 'lon': 77.1734},
      'darjeeling': {'lat': 27.0360, 'lon': 88.2627},
      'mussoorie': {'lat': 30.4546, 'lon': 78.0798},
      'nainital': {'lat': 29.3919, 'lon': 79.4542},
      'khajuraho': {'lat': 24.8525, 'lon': 79.9333},
      'gokarna': {'lat': 14.5500, 'lon': 74.3167},
      'pondicherry': {'lat': 11.9416, 'lon': 79.8083},
      'puducherry': {'lat': 11.9416, 'lon': 79.8083},
      'puri': {'lat': 19.8135, 'lon': 85.8315},
      'konark': {'lat': 19.8876, 'lon': 86.0945},
      'wayanad': {'lat': 11.6854, 'lon': 76.1320},
      'thekkady': {'lat': 9.6000, 'lon': 77.1667},
      'periyar': {'lat': 9.6000, 'lon': 77.1667},
      'alleppey': {'lat': 9.4981, 'lon': 76.3388},
      'alappuzha': {'lat': 9.4981, 'lon': 76.3388},
      'varkala': {'lat': 8.7375, 'lon': 76.7167},
      'kovalam': {'lat': 8.4000, 'lon': 76.9781},
      'thekkady': {'lat': 9.6000, 'lon': 77.1667},
      'kumarakom': {'lat': 9.6167, 'lon': 76.4333},
      'bekal': {'lat': 12.3894, 'lon': 75.0333},
      'athirappilly': {'lat': 10.2833, 'lon': 76.5667},
      'amritsar': {'lat': 31.6340, 'lon': 74.8723},
      'varanasi': {'lat': 25.3176, 'lon': 82.9739},
      'agra': {'lat': 27.1767, 'lon': 78.0081},
      'rishikesh': {'lat': 30.0869, 'lon': 78.2676},
      'haridwar': {'lat': 29.9457, 'lon': 78.1642},
    };
    
    // Check exact match
    if (cityCoords.containsKey(destLower)) {
      return cityCoords[destLower];
    }
    
    // Check partial match (e.g., "Thiruvananthapuram" contains "thiruvananthapuram")
    for (final entry in cityCoords.entries) {
      if (destLower.contains(entry.key) || entry.key.contains(destLower)) {
        return entry.value;
      }
    }
    
    return null;
  }

  Future<List<PlaceDetails>> _fetchPlaces(String bbox, List<String> interests) async {
    // Retry logic: try up to 2 times with moderate timeouts; fall back quickly on repeated timeouts
    const int maxRetries = 2;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Enhanced Overpass query - fetch more famous attractions
        // Use shorter timeouts to avoid long waits on slow Overpass responses
        final queryTimeout = 18 + (attempt * 6); // 24s max
        final overpassQuery = '''
          [out:json][timeout:$queryTimeout];
          (
            // Tourism attractions (most important - expanded)
            node["tourism"]["name"](\$bbox);
            way["tourism"]["name"](\$bbox);
            relation["tourism"]["name"](\$bbox);
            
            // Specific famous attraction types
            node["tourism"~"^(attraction|museum|gallery|zoo|theme_park|monument|memorial|artwork|viewpoint|information|aquarium)\$"]["name"](\$bbox);
            way["tourism"~"^(attraction|museum|gallery|zoo|theme_park|monument|memorial|artwork|viewpoint|information|aquarium)\$"]["name"](\$bbox);
            
            // Natural attractions (expanded)
            node["natural"~"^(beach|waterfall|peak|hill|cliff|cave|volcano|spring|geyser|bay|cape|island)\$"]["name"](\$bbox);
            way["natural"~"^(beach|waterfall|peak|hill|cliff|cave|volcano|spring|geyser|bay|cape|island)\$"]["name"](\$bbox);
            
            // Historic sites and heritage
            node["historic"]["name"](\$bbox);
            way["historic"]["name"](\$bbox);
            node["historic"~"^(castle|fort|palace|ruins|monument|memorial|tomb|archaeological_site|tower)\$"]["name"](\$bbox);
            way["historic"~"^(castle|fort|palace|ruins|monument|memorial|tomb|archaeological_site|tower)\$"]["name"](\$bbox);
            
            // Parks and gardens (expanded)
            node["leisure"~"^(park|garden|nature_reserve|beach_resort|marina|water_park)\$"]["name"](\$bbox);
            way["leisure"~"^(park|garden|nature_reserve|beach_resort|marina|water_park)\$"]["name"](\$bbox);
            
            // Places of worship (famous temples, churches, mosques)
            node["amenity"="place_of_worship"]["name"](\$bbox);
            way["amenity"="place_of_worship"]["name"](\$bbox);
            
            // Man-made attractions
            node["man_made"~"^(tower|bridge|lighthouse|observatory|monument|obelisk)\$"]["name"](\$bbox);
            way["man_made"~"^(tower|bridge|lighthouse|observatory|monument|obelisk)\$"]["name"](\$bbox);
            
            // Water bodies and lakes
            node["natural"="water"]["name"](\$bbox);
            way["natural"="water"]["name"](\$bbox);
            
            // Food & drink (for meal planning)
            node["amenity"~"^(restaurant|cafe|bar|fast_food)\$"]["name"](\$bbox);
            way["amenity"~"^(restaurant|cafe|bar|fast_food)\$"]["name"](\$bbox);
            
            // Entertainment and culture
            node["amenity"~"^(cinema|theatre|arts_centre|nightclub|casino)\$"]["name"](\$bbox);
            way["amenity"~"^(cinema|theatre|arts_centre|nightclub|casino)\$"]["name"](\$bbox);
        );
        out center meta;
      ''';

        // Replace bbox placeholder
      final finalQuery = overpassQuery.replaceAll(r'$bbox', bbox);
      
        print('Fetching places for bbox: $bbox (Attempt $attempt/$maxRetries, timeout: ${queryTimeout}s)');
      
      final overpassUrl = Uri.parse('https://overpass-api.de/api/interpreter');
        
        // HTTP timeout should be slightly longer than query timeout (kept shorter to fail fast)
        final httpTimeout = Duration(seconds: queryTimeout + 6);
        
      final response = await http.post(
        overpassUrl, 
        body: {'data': finalQuery},
        headers: {'User-Agent': _userAgent}
      ).timeout(
          httpTimeout,
        onTimeout: () {
            throw Exception('Request timeout after ${httpTimeout.inSeconds}s');
        },
      );

      print('Overpass API response status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('Overpass API failed with status: ${response.statusCode}');
          if (attempt < maxRetries) {
            print('Retrying...');
            await Future.delayed(Duration(seconds: attempt * 2)); // Wait before retry
            continue;
          }
        print('Response body: ${response.body}');
        throw Exception('Failed to fetch places from Overpass API. Status: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final elements = data['elements'] as List;
      
      print('Overpass API returned ${elements.length} elements');

      // Convert to PlaceDetails and filter
      final places = elements
          .map((element) => PlaceDetails.fromOsmElement(element))
          .where((place) => place.name != 'Unnamed Place' && place.name.isNotEmpty)
          .toList();

      print('Filtered to ${places.length} valid places');

      // Simplified duplicate removal for better performance
      final uniquePlaces = <String, PlaceDetails>{};
      for (final place in places) {
        final key = _getPlaceKey(place);
        if (!uniquePlaces.containsKey(key)) {
          uniquePlaces[key] = place;
        }
      }

      print('Final unique places: ${uniquePlaces.length}');
      return uniquePlaces.values.toList();
    } catch (e) {
        print('Error fetching places (Attempt $attempt): $e');
        final isTimeout = e.toString().toLowerCase().contains('timeout');
        if (attempt == maxRetries || isTimeout) {
          // Fail fast on timeout or after final attempt to trigger fallback itinerary
          print('Stopping place fetch and switching to fallback itinerary');
          return [];
        }
        // Wait before retrying with exponential backoff
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    return []; // Return empty list to trigger fallback
  }

  Map<String, List<PlaceDetails>> _categorizePlaces(List<PlaceDetails> places) {
    final categorized = <String, List<PlaceDetails>>{
      'attractions': [],
      'restaurants': [],
      'cafes': [],
      'bars': [],
      'shopping': [],
      'accommodation': [],
      'entertainment': [],
      'parks': [],
      'religious': [],
    };

    for (final place in places) {
      // Promote key natural/heritage places into attractions (e.g., beaches, waterfalls, forts)
      final natural = place.additionalTags['natural'];
      final historic = place.additionalTags['historic'];
      final heritage = place.additionalTags['heritage'];
      final water = place.additionalTags['water'];
      final leisure = place.additionalTags['leisure'];
      final manMade = place.additionalTags['man_made'];

      if (place.tourismType != null) {
        switch (place.tourismType) {
          case 'attraction':
          case 'museum':
          case 'gallery':
          case 'zoo':
          case 'theme_park':
          case 'monument':
          case 'memorial':
          case 'artwork':
          case 'viewpoint':
            categorized['attractions']!.add(place);
            break;
          case 'hotel':
          case 'hostel':
          case 'guest_house':
          case 'apartment':
          case 'resort':
            categorized['accommodation']!.add(place);
            break;
        }
      }

      if (place.amenityType != null) {
        switch (place.amenityType) {
          case 'restaurant':
            categorized['restaurants']!.add(place);
            break;
          case 'cafe':
            categorized['cafes']!.add(place);
            break;
          case 'bar':
          case 'pub':
          case 'nightclub':
            categorized['bars']!.add(place);
            break;
          case 'cinema':
          case 'theatre':
          case 'casino':
          case 'arts_centre':
            categorized['entertainment']!.add(place);
            break;
          case 'place_of_worship':
          case 'monastery':
            categorized['religious']!.add(place);
            break;
        }
      }

      // Check for shopping and leisure
      if (place.additionalTags.containsKey('shop')) {
        categorized['shopping']!.add(place);
      }
      if (leisure == 'park' || leisure == 'garden') {
        categorized['parks']!.add(place);
      }

      // Natural sights and heritage – treat as attractions (PRIORITIZE TOURIST ATTRACTIONS)
      final isBeach = natural == 'beach' || place.name.toLowerCase().contains('beach');
      final isWaterfall = natural == 'waterfall' || (water == 'waterfall') || place.name.toLowerCase().contains('waterfall') || place.name.toLowerCase().contains('falls');
      final isViewpoint = place.tourismType == 'viewpoint' || place.name.toLowerCase().contains('viewpoint') || place.name.toLowerCase().contains('view point') || place.name.toLowerCase().contains('point');
      final isPeak = natural == 'peak' || natural == 'hill' || place.name.toLowerCase().contains('peak') || place.name.toLowerCase().contains('hill');
      final isLake = natural == 'lake' || natural == 'river' || place.name.toLowerCase().contains('lake');
      final isFort = (historic == 'ruins' || historic == 'castle' || historic == 'fort' || manMade == 'fortification') || place.name.toLowerCase().contains('fort');
      final isPalace = historic == 'palace' || place.name.toLowerCase().contains('palace');
      final isHeritage = heritage != null || place.name.toLowerCase().contains('heritage');
      final isCave = natural == 'cave' || place.name.toLowerCase().contains('cave');
      final isValley = place.name.toLowerCase().contains('valley');
      
      // Add all tourist attractions to attractions category
      if (isBeach || isWaterfall || isViewpoint || isPeak || isLake || isFort || isPalace || isHeritage || isCave || isValley) {
        categorized['attractions']!.add(place);
      }
    }

    // Limit places per category
    for (final key in categorized.keys) {
      if (categorized[key]!.length > _maxPlacesPerType) {
        categorized[key] = categorized[key]!.take(_maxPlacesPerType).toList();
      }
    }

    return categorized;
  }

  // Curated keywords for major destinations to boost main attractions
  List<String> _getCuratedKeywords(String destination) {
    final key = destination.toLowerCase();
    
    // Goa - Beach Paradise
    if (key.contains('goa') || key.contains('panaji') || key.contains('panjim')) {
      return [
        // Famous Beaches
        'baga beach', 'calangute beach', 'anjuna beach', 'candolim beach', 'palolem beach',
        'miramar beach', 'arambol beach', 'vagator beach', 'benaulim beach', 'colva beach',
        'agonda beach', 'morjim beach', 'ashwem beach', 'sinquerim beach', 'betalbatim beach',
        'varca beach', 'cavelossim beach', 'mobor beach', 'galgibaga beach', 'butterfly beach',
        // Viewpoints & Scenic Spots
        'chapora fort', 'aguada fort', 'reis magos fort', 'terekhol fort', 'corjuem fort',
        'dona paula', 'dona paula viewpoint', 'cabo de rama fort', 'tito lane', 'anjuna viewpoint',
        // Waterfalls & Nature
        'dudhsagar falls', 'tambdi surla waterfall', 'harvalem falls', 'kuskem falls',
        // Heritage & Culture
        'basilica of bom jesus', 'se cathedral', 'shri mangeshi temple', 'shri shantadurga temple',
        'old goa', 'divar island', 'chorao island', 'spice plantation', 'anjuna flea market',
        'mapusa market', 'panjim church', 'santa monica church', 'margao market',
        // Wildlife & Adventure
        'bondla wildlife sanctuary', 'mollem national park', 'bhagwan mahavir wildlife sanctuary',
        'grand island', 'scuba diving', 'dolphin watching', 'water sports', 'parasailing',
        'jet skiing', 'banana boat ride', 'sunset cruise', 'casino cruise',
      ];
    }
    
    // Kerala
    if (key.contains('kochi') || key.contains('cochin')) {
      return [
        'fort kochi', 'chinese fishing nets', 'santa cruz basilica', 'st francis church',
        'jew town', 'mattancherry palace', 'dutch palace', 'paradesi synagogue',
        'marine drive', 'cherai beach', 'bolgatty palace', 'willingdon island',
        'kerala kathakali centre', 'kerala folklore museum', 'hill palace', 'lulu mall',
        'kashi art gallery', 'kerala backwaters', 'kumbalangi village', 'mangalavanam bird sanctuary',
        'pallipuram fort', 'thripunithura hill palace', 'kalady', 'edappally church',
      ];
    }
    if (key.contains('kerala') || key.contains('trivandrum') || key.contains('thiruvananthapuram')) {
      return [
        'kovalam beach', 'padmanabhaswamy temple', 'napier museum', 'kuthiramalika palace',
        'ponmudi hills', 'varkala beach', 'alleppey backwaters', 'munnar tea gardens',
        'periyar wildlife sanctuary', 'kumarakom', 'fort kochi', 'athirappilly falls',
        'wayanad', 'thekkady', 'kerala backwaters', 'kathakali performance', 'kalaripayattu',
        'guruvayur temple', 'sabarimala', 'bekal fort', 'palakkad fort', 'kannur fort',
        'thalassery fort', 'st angelo fort', 'kappad beach', 'payyambalam beach',
        'silent valley national park', 'eravikulam national park', 'parambikulam wildlife sanctuary',
      ];
    }
    
    // Munnar - Famous hill station with tea gardens, viewpoints, waterfalls
    if (key.contains('munnar')) {
      return [
        'tea museum', 'mattupetty dam', 'echo point', 'top station', 'kundala lake',
        'attukal waterfalls', 'lakhom waterfalls', 'chinnar wildlife sanctuary',
        'eravikulam national park', 'anaimudi peak', 'marayoor sandalwood forest',
        'lockhart gap', 'photo point', 'blossom park', 'rose garden', 'tea gardens',
        'pothamedu viewpoint', 'meesapulimala', 'kolukkumalai tea estate',
        'chinnakanal waterfalls', 'power house waterfalls', 'lakkom waterfalls',
        'mattupetty viewpoint', 'kundala dam', 'devikulam', 'munnar town',
        'tata tea museum', 'lockhart tea estate', 'kanan devan hills',
      ];
    }
    
    // Gavi - Eco Tourism Paradise in Kerala
    if (key.contains('gavi')) {
      return [
        'gavi eco tourism', 'periyar tiger reserve', 'gavi dam', 'gavi lake',
        'sabarimala', 'pamba', 'pathanamthitta', 'kakki reservoir', 'sengulam dam',
        'pullumedu', 'neelimala', 'appachimedu', 'shabarimala temple', 'pamba river',
        'gavi forest', 'wildlife sanctuary', 'elephant spotting', 'bird watching',
        'jungle safari', 'trekking', 'camping', 'nature walk', 'eco tourism',
        'periyar lake', 'kumily', 'thekkady', 'cardamom hills', 'spice plantation',
      ];
    }
    
    // Ponmudi - Golden Peak
    if (key.contains('ponmudi')) {
      return [
        'ponmudi hills', 'golden peak', 'ponmudi viewpoint', 'meenmutty waterfalls',
        'ponmudi tea estate', 'ponmudi trekking', 'ponmudi valley', 'ponmudi peak',
        'ponmudi forest', 'ponmudi wildlife', 'ponmudi hills station', 'ponmudi resort',
        'ponmudi adventure', 'ponmudi nature', 'ponmudi camping', 'ponmudi bird watching',
      ];
    }
    
    // Kollam - Cashew Capital
    if (key.contains('kollam') || key.contains('quilon')) {
      return [
        'kollam beach', 'ashtamudi lake', 'thenmala', 'palaruvi falls', 'jatayu earth center',
        'munroe island', 'thangassery', 'kollam backwaters', 'ashtamudi backwaters',
        'sasthamkotta lake', 'amritapuri', 'kollam port', 'thangassery lighthouse',
        'kollam cashew', 'kollam market', 'kollam fort', 'kollam temple',
        'kollam boat race', 'kollam fishing', 'kollam heritage', 'kollam culture',
      ];
    }
    
    // Thenmala - Honey Hills
    if (key.contains('thenmala')) {
      return [
        'thenmala dam', 'thenmala eco tourism', 'thenmala butterfly park', 'thenmala adventure park',
        'thenmala deer park', 'thenmala boating', 'thenmala trekking', 'thenmala forest',
        'thenmala waterfalls', 'thenmala nature', 'thenmala camping', 'thenmala safari',
      ];
    }
    
    // Palaruvi Falls
    if (key.contains('palaruvi')) {
      return [
        'palaruvi waterfalls', 'palaruvi falls', 'palaruvi nature', 'palaruvi trekking',
        'palaruvi forest', 'palaruvi adventure', 'palaruvi picnic', 'palaruvi photography',
      ];
    }
    
    // Jatayu Earth Center
    if (key.contains('jatayu')) {
      return [
        'jatayu earth center', 'jatayu statue', 'jatayu rock', 'jatayu adventure park',
        'jatayu nature park', 'jatayu museum', 'jatayu viewpoint', 'jatayu sculpture',
        'jatayu park', 'jatayu tourism', 'jatayu heritage', 'jatayu culture',
      ];
    }
    
    // Munroe Island
    if (key.contains('munroe island') || key.contains('munro island')) {
      return [
        'munroe island', 'munroe backwaters', 'munroe island canoeing', 'munroe island village',
        'munroe island tour', 'munroe island boat ride', 'munroe island nature', 'munroe island fishing',
        'munroe island bird watching', 'munroe island homestay', 'munroe island experience',
      ];
    }
    
    // Kozhikode - City of Spices
    if (key.contains('kozhikode') || key.contains('calicut')) {
      return [
        'kozhikode beach', 'kappad beach', 'mananchira square', 'tali temple', 'pazhassi raja museum',
        'beypore beach', 'kadalundi bird sanctuary', 'thusharagiri falls', 'kakkayam dam',
        'kozhikode backwaters', 'kozhikode fort', 'kozhikode market', 'kozhikode cuisine',
        'kozhikode halwa', 'kozhikode biryani', 'kozhikode culture', 'kozhikode heritage',
        'kozhikode lighthouse', 'kozhikode port', 'kozhikode spice market', 'kozhikode handicrafts',
      ];
    }
    
    // Kannur - Crown of Kerala
    if (key.contains('kannur')) {
      return [
        'payyambalam beach', 'muzhappilangad beach', 'st angelo fort', 'thalassery fort',
        'kannur fort', 'arakkal museum', 'madayipara', 'ezhimala', 'kannur lighthouse',
        'kannur beach', 'kannur backwaters', 'kannur theyyam', 'kannur culture',
        'kannur heritage', 'kannur handloom', 'kannur cuisine', 'kannur fishing',
        'kannur boat race', 'kannur temple', 'kannur mosque', 'kannur church',
      ];
    }
    
    // Thrissur - Cultural Capital
    if (key.contains('thrissur')) {
      return [
        'thrissur pooram', 'vadakkunnathan temple', 'punnathur kotta', 'guruvayur temple',
        'athirappilly falls', 'vazhachal falls', 'thrissur zoo', 'thrissur museum',
        'thrissur round', 'thrissur kerala kalamandalam', 'thrissur cultural center',
        'thrissur art gallery', 'thrissur heritage', 'thrissur festival', 'thrissur temple',
        'thrissur church', 'thrissur mosque', 'thrissur cuisine', 'thrissur culture',
      ];
    }
    
    // Palakkad - Granary of Kerala
    if (key.contains('palakkad')) {
      return [
        'palakkad fort', 'silent valley national park', 'malampuzha dam', 'nelliampathy hills',
        'parambikulam tiger reserve', 'attapadi', 'kalpathi', 'palakkad gap', 'malampuzha garden',
        'malampuzha rock garden', 'malampuzha boating', 'nelliampathy tea estate', 'nelliampathy viewpoint',
        'parambikulam dam', 'parambikulam wildlife', 'silent valley trekking', 'palakkad temple',
        'palakkad heritage', 'palakkad culture', 'palakkad cuisine', 'palakkad handicrafts',
      ];
    }
    
    // Kottayam - Land of Letters
    if (key.contains('kottayam')) {
      return [
        'kottayam backwaters', 'kumarakom bird sanctuary', 'vaikom', 'ettumanoor temple',
        'thirunakkara temple', 'poonjar palace', 'ilaveezhapoonchira', 'kottayam church',
        'kottayam heritage', 'kottayam culture', 'kottayam cuisine', 'kottayam boat race',
        'kottayam temple', 'kottayam museum', 'kottayam library', 'kottayam printing',
      ];
    }
    
    // Kuttanad - Rice Bowl of Kerala
    if (key.contains('kuttanad')) {
      return [
        'kuttanad backwaters', 'kuttanad paddy fields', 'kuttanad houseboat', 'kuttanad village',
        'kuttanad boat race', 'kuttanad culture', 'kuttanad farming', 'kuttanad tourism',
        'kuttanad experience', 'kuttanad homestay', 'kuttanad nature', 'kuttanad heritage',
      ];
    }
    
    // Pathiramanal - Bird Island
    if (key.contains('pathiramanal')) {
      return [
        'pathiramanal island', 'pathiramanal bird sanctuary', 'pathiramanal backwaters',
        'pathiramanal bird watching', 'pathiramanal boat ride', 'pathiramanal nature',
        'pathiramanal tourism', 'pathiramanal experience',
      ];
    }
    
    // Ambalapuzha - Temple Town
    if (key.contains('ambalapuzha')) {
      return [
        'ambalapuzha temple', 'ambalapuzha palpayasam', 'ambalapuzha krishna temple',
        'ambalapuzha boat race', 'ambalapuzha culture', 'ambalapuzha heritage',
        'ambalapuzha backwaters', 'ambalapuzha tourism',
      ];
    }
    
    // Krishnapuram Palace
    if (key.contains('krishnapuram')) {
      return [
        'krishnapuram palace', 'krishnapuram museum', 'krishnapuram heritage',
        'krishnapuram architecture', 'krishnapuram history', 'krishnapuram tourism',
      ];
    }
    
    // Karumadi
    if (key.contains('karumadi')) {
      return [
        'karumadi kuttan', 'karumadi buddha', 'karumadi temple', 'karumadi heritage',
        'karumadi history', 'karumadi culture', 'karumadi tourism',
      ];
    }
    
    // Champakulam
    if (key.contains('champakulam')) {
      return [
        'champakulam boat race', 'champakulam church', 'champakulam backwaters',
        'champakulam culture', 'champakulam heritage', 'champakulam tourism',
        'champakulam experience', 'champakulam village',
      ];
    }
    
    // Ilaveezhapoonchira
    if (key.contains('ilaveezhapoonchira')) {
      return [
        'ilaveezhapoonchira', 'ilaveezhapoonchira valley', 'ilaveezhapoonchira viewpoint',
        'ilaveezhapoonchira trekking', 'ilaveezhapoonchira nature', 'ilaveezhapoonchira adventure',
        'ilaveezhapoonchira camping', 'ilaveezhapoonchira photography',
      ];
    }
    
    // Ashtamudi Lake
    if (key.contains('ashtamudi')) {
      return [
        'ashtamudi lake', 'ashtamudi backwaters', 'ashtamudi boat ride', 'ashtamudi houseboat',
        'ashtamudi bird watching', 'ashtamudi fishing', 'ashtamudi nature', 'ashtamudi tourism',
        'ashtamudi experience', 'ashtamudi sunset', 'ashtamudi village',
      ];
    }
    
    // Ooty - Queen of Hill Stations
    if (key.contains('ooty') || key.contains('udagamandalam')) {
      return [
        'ooty lake', 'botanical gardens', 'doddabetta peak', 'rose garden', 'tea factory',
        'pykara falls', 'pykara lake', 'mudumalai national park', 'nilgiri mountain railway',
        'catherine falls', 'kalhatti falls', 'emerald lake', 'avalanche lake', 'wax museum',
        'toy train', 'government museum', 'st stephen church', 'tribal museum',
        'ketti valley viewpoint', 'lamb rock', 'dolphin nose', 'needle rock',
      ];
    }
    
    // Kodaikanal - Princess of Hill Stations
    if (key.contains('kodaikanal')) {
      return [
        'kodaikanal lake', 'coakers walk', 'pillar rocks', 'silver cascade falls',
        'bear shola falls', 'dolphin nose', 'green valley viewpoint', 'kurinji andavar temple',
        'bryant park', 'chettiar park', 'moir point', 'upper lake view', 'berijam lake',
        'vattakanal', 'thousand pillar rock', 'poombarai village', 'guna cave',
        'shenbaganur museum', 'christ the king church', 'la salette church',
      ];
    }

    // Kottayam - Land of Letters, Lakes & Latex
    if (key.contains('kottayam')) {
      return [
        'kumarakom', 'kumarakom bird sanctuary', 'vembanad lake', 'kottayam backwaters',
        'kuttanad', 'pathiramanal island', 'ilaveezhapoonchira', 'vaikom', 'ettumanoor temple',
        'thirunakkara mahadeva temple', 'poonjar palace', 'thazhathangadi juma masjid',
        'malliyoor sri mahaganapathy', 'pallipurathukavu', 'cheriapally', 'valiyapally',
        'thuruthikkadavu', 'marmala waterfalls', 'wagamon', 'ramakkalmedu', 'pala', 'adimaly',
        'manarcad', 'mangala devi temple', 'kottayam heritage', 'kottayam museum',
      ];
    }
    
    // Coorg - Scotland of India
    if (key.contains('coorg') || key.contains('kodagu')) {
      return [
        'abbey falls', 'raja seat', 'madhikeri fort', 'omkareshwara temple',
        'talakaveri', 'nagarahole national park', 'dubare elephant camp', 'iruppu falls',
        'golden temple', 'nalknad palace', 'tadiandamol peak', 'mandalpatti viewpoint',
        'barapole river', 'chettalli coffee estate', 'coffee museum', 'cauvery nisargadhama',
        'bhagamandala', 'triveni sangam', 'harangi dam', 'kushalnagar',
      ];
    }
    
    // Hampi - UNESCO World Heritage Site
    if (key.contains('hampi')) {
      return [
        'virupaksha temple', 'vittala temple', 'hemakuta hill', 'hampi bazaar',
        'lotus mahal', 'elephant stables', 'queen bath', 'hazara rama temple',
        'krishna temple', 'achutaraya temple', 'zanana enclosure', 'royal enclosure',
        'matanga hill', 'anjaneya hill', 'tungabhadra river', 'coracle ride',
        'sugriva cave', 'sanapur lake', 'daroji bear sanctuary', 'badavilinga temple',
      ];
    }
    
    // Rishikesh - Yoga Capital & Adventure Hub
    if (key.contains('rishikesh')) {
      return [
        'lakshman jhula', 'ram jhula', 'triveni ghat', 'geeta bhawan', 'swarg ashram',
        'neelkanth mahadev temple', 'bharat mandir', 'trimbakeshwar temple', 'shivpuri',
        'rafting point', 'beatles ashram', 'kunjapuri temple', 'patna waterfall',
        'garud chatti waterfall', 'phool chatti waterfall', 'rajaji national park',
        'vashishta cave', 'shivpuri river rafting', 'janki setu', 'ram jhula market',
      ];
    }
    
    // Haridwar - Gateway to Gods
    if (key.contains('haridwar')) {
      return [
        'har ki pauri', 'maya devi temple', 'chandi devi temple', 'mansa devi temple',
        'daksha mahadev temple', 'bharat mata mandir', 'shantikunj', 'pawan dham',
        'ganga aarti', 'rajaji national park', 'chilla wildlife sanctuary',
        'neel dhara pakshi vihar', 'sapt rishi ashram', 'vaishno devi temple',
        'piran kaliyar', 'doodhadhari barfani temple', 'bara bazaar',
      ];
    }
    
    // Varanasi - Spiritual Capital
    if (key.contains('varanasi') || key.contains('banaras') || key.contains('kashi')) {
      return [
        'kashi vishwanath temple', 'dashashwamedh ghat', 'assi ghat', 'manikarnika ghat',
        'sarnath', 'dhamek stupa', 'ganga aarti', 'tulsi manas temple', 'sankat mochan temple',
        'durga temple', 'bharat mata temple', 'ramnagar fort', 'banaras hindu university',
        'jala temple', 'new vishwanath temple', 'chunar fort', 'rajghat',
        'boat ride ganges', 'evening aarti', 'sarnath museum', 'deer park',
      ];
    }
    
    // Andaman - Tropical Paradise
    if (key.contains('andaman') || key.contains('port blair') || key.contains('havelock')) {
      return [
        'cellular jail', 'radhanagar beach', 'elephant beach', 'kalapathar beach',
        'ross island', 'north bay island', 'jolly buoy island', 'red skin island',
        'chidiya tapu', 'wandoor beach', 'corbyns cove', 'baratang island',
        'limestone caves', 'mud volcano', 'maharashtra beach', 'vijaynagar beach',
        'mount harriet', 'chatham saw mill', 'samudrika museum', 'anthropological museum',
      ];
    }
    
    // Leh-Ladakh - Land of High Passes
    if (key.contains('leh') || key.contains('ladakh')) {
      return [
        'pangong lake', 'nubra valley', 'khardung la', 'magnetic hill', 'gurudwara pathar sahib',
        'leh palace', 'shanti stupa', 'hemis monastery', 'thiksey monastery', 'diskit monastery',
        'alchi monastery', 'lamayuru monastery', 'tso moriri', 'tso kar', 'zanskar valley',
        'kargil', 'drass', 'suru valley', 'bactrian camel ride', 'confluence of indus and zanskar',
      ];
    }
    
    // Manali - Valley of Gods
    if (key.contains('manali')) {
      return [
        'rohtang pass', 'solang valley', 'hadimba temple', 'manu temple', 'vashisht temple',
        'old manali', 'mall road', 'jogini falls', 'beas kund', 'chandrakhani pass',
        'hamta pass', 'bhrigu lake', 'gulaba', 'kothi', 'rahi falls', 'manikaran',
        'great himalayan national park', 'pin valley national park', 'paragliding solang',
        'river rafting', 'skiing solang', 'zorbing', 'atv rides',
      ];
    }
    
    // Shimla - Queen of Hills
    if (key.contains('shimla')) {
      return [
        'mall road', 'ridge', 'jakhu temple', 'christ church', 'gaiety theatre',
        'kufri', 'chadwick falls', 'tara devi temple', 'himalayan bird park',
        'indian institute of advanced study', 'summer hill', 'prospect hill',
        'annandale', 'scandal point', 'laxminarayan temple', 'kali bari temple',
        'state museum', 'viceregal lodge', 'gorton castle', 'peterhoff',
        'wildflower hall', 'chail', 'kasauli', 'solan', 'barog',
      ];
    }
    
    // Darjeeling - Queen of the Himalayas
    if (key.contains('darjeeling')) {
      return [
        'tiger hill', 'batasia loop', 'peace pagoda', 'padmaja naidu himalayan zoological park',
        'himalayan mountaineering institute', 'ropeway', 'tea garden', 'rock garden',
        'ganga maya park', 'observatory hill', 'st andrew church', 'lloyd botanical garden',
        'toy train', 'darjeeling himalayan railway', 'ghoom', 'kalimpong', 'mirik',
        'sandakphu', 'singalila national park', 'phalut', 'kanchenjunga national park',
      ];
    }
    
    // Mussoorie - Queen of the Hills
    if (key.contains('mussoorie')) {
      return [
        'kempty falls', 'gun hill', 'lal tibba', 'camel back road', 'mussoorie lake',
        'company garden', 'jwalaji temple', 'christ church', 'landour', 'happy valley',
        'clouds end', 'nag tibba', 'dhanolti', 'surkanda devi temple', 'george everest house',
        'mussoorie heritage centre', 'ropeway', 'bhatta falls', 'mossy falls',
      ];
    }
    
    // Nainital - Lake District of India
    if (key.contains('nainital')) {
      return [
        'naini lake', 'naina devi temple', 'tiffin top', 'snow view point', 'eco cave gardens',
        'high altitude zoo', 'lands end', 'kilbury bird sanctuary', 'hanuman garhi',
        'gurney house', 'st john church', 'mallital', 'tallital', 'nainital boat club',
        'pangot', 'sattal', 'bhimtal', 'naukuchiatal', 'khurpatal',
      ];
    }
    
    // Khajuraho - Temples of Love
    if (key.contains('khajuraho')) {
      return [
        'kandariya mahadev temple', 'lakshmana temple', 'vishvanatha temple', 'parshvanatha temple',
        'adhinatha temple', 'chaturbhuj temple', 'jain temples', 'archaeological museum',
        'light and sound show', 'raja cafe', 'lakshmana temple complex', 'western group temples',
        'eastern group temples', 'southern group temples', 'panna national park',
      ];
    }
    
    // Gokarna - Beach Paradise
    if (key.contains('gokarna')) {
      return [
        'om beach', 'kudle beach', 'half moon beach', 'paradise beach', 'gokarna beach',
        'mahabaleshwar temple', 'mahaganapati temple', 'kotiteertha', 'bhadrakali temple',
        'sirsi', 'yana', 'mirjan fort', 'aigumbe falls', 'jog falls',
      ];
    }
    
    // Pondicherry - French Riviera of the East
    if (key.contains('pondicherry') || key.contains('puducherry')) {
      return [
        'promenade beach', 'rock beach', 'auroville', 'auroville beach', 'paradise beach',
        'sri aurobindo ashram', 'immaculate conception cathedral', 'sacred heart basilica',
        'french quarter', 'botanical garden', 'chunnambar boat house', 'serenity beach',
        'matrimandir', 'auroville beach', 'raj niwas', 'government park',
      ];
    }
    
    // Puri - Spiritual Beach Destination
    if (key.contains('puri')) {
      return [
        'jagannath temple', 'puri beach', 'chilika lake', 'konark sun temple',
        'golden beach', 'swargadwar', 'gundicha temple', 'loknath temple',
        'sakshi gopal temple', 'ramachandi temple', 'pipli', 'ragurajpur',
        'satapada', 'nirmaljhara', 'balighai beach', 'chandrabhaga beach',
      ];
    }
    
    // Konark - Sun Temple
    if (key.contains('konark')) {
      return [
        'konark sun temple', 'konark beach', 'chandrabhaga beach', 'archaeological museum',
        'ramachandi temple', 'beleswar beach', 'pipli', 'ragurajpur',
      ];
    }
    
    // Wayanad - Green Paradise
    if (key.contains('wayanad')) {
      return [
        'edakkal caves', 'banasura sagar dam', 'chembra peak', 'meenmutty waterfalls',
        'soochipara falls', 'kuruva island', 'pookode lake', 'lakkidi viewpoint',
        'thirunelli temple', 'muthanga wildlife sanctuary', 'tholpetty wildlife sanctuary',
        'wayanad heritage museum', 'phantom rock', 'neelimala viewpoint', 'chain tree',
      ];
    }
    
    // Thekkady - Wildlife & Spice
    if (key.contains('thekkady') || key.contains('periyar')) {
      return [
        'periyar national park', 'periyar lake', 'elephant junction', 'spice plantation',
        'kathakali centre', 'mullaperiyar dam', 'mangala devi temple', 'vandiperiyar',
        'kumily', 'boat ride periyar', 'jungle safari', 'elephant ride',
        'tiger reserve', 'cardamom hills', 'kurisumala', 'pandikuzhi',
      ];
    }
    
    // Alleppey - Backwaters Paradise
    if (key.contains('alleppey') || key.contains('alappuzha')) {
      return [
        'alleppey backwaters', 'houseboat', 'vembanad lake', 'marari beach',
        'kuttanad', 'karumadi kuttan', 'revi karunakaran museum', 'amritapuri',
        'pathiramanal island', 'krishnapuram palace', 'kayamkulam', 'champakulam',
        'kumarakom bird sanctuary', 'nehru trophy boat race', 'punnamada lake',
      ];
    }
    
    // Varkala - Cliff Beach Paradise
    if (key.contains('varkala')) {
      return [
        'varkala beach', 'papanasam beach', 'kappil beach', 'janardhana swamy temple',
        'sivagiri mutt', 'kadakkal', 'anchuthengu fort', 'ponnumthuruthu island',
        'edava beach', 'kappil lake', 'varkala cliff', 'golden beach',
      ];
    }
    
    // Kovalam - Beach Paradise
    if (key.contains('kovalam')) {
      return [
        'kovalam beach', 'lighthouse beach', 'hawah beach', 'samudra beach',
        'halcyon castle', 'kovalam lighthouse', 'karamana river', 'vettukad church',
        'padmanabhaswamy temple', 'shanghumukham beach', 'vellayani lake',
      ];
    }
    
    // Mumbai
    if (key.contains('mumbai') || key.contains('bombay')) {
      return [
        'gateway of india', 'marine drive', 'juhu beach', 'elephanta caves', 'haji ali dargah',
        'siddhivinayak temple', 'banganga tank', 'prince of wales museum', 'chhatrapati shivaji terminus',
        'bandra worli sea link', 'colaba causeway', 'crawford market', 'dharavi', 'bollywood studios',
        'essel world', 'powai lake', 'sanjay gandhi national park', 'kanheri caves', 'global vipassana pagoda',
        'mahalaxmi temple', 'iskcon temple', 'mount mary church', 'bandra fort', 'worli sea face',
        'versova beach', 'girgaon chowpatty', 'rajabai clock tower', 'flora fountain', 'victoria terminus',
        'dr bhau daji lad museum', 'manish market', 'chor bazaar', 'kalaghoda art district',
      ];
    }
    
    // Delhi
    if (key.contains('delhi') || key.contains('new delhi')) {
      return [
        'red fort', 'qutub minar', 'india gate', 'lotus temple', 'jama masjid', 'humayun tomb',
        'akshardham temple', 'connaught place', 'chandni chowk', 'rajpath', 'rashtrapati bhavan',
        'parliament house', 'purana qila', 'jantar mantar', 'gurudwara bangla sahib', 'national museum',
        'crafts museum', 'dilli haat', 'sarojini nagar market', 'karol bagh', 'lajpat nagar',
        'janpath market', 'palika bazaar', 'khan market', 'rajiv chowk', 'india habitat centre',
        'national gallery of modern art', 'safdarjung tomb', 'lodhi garden', 'garden of five senses',
        'national zoological park', 'islamic cultural centre', 'birla mandir', 'lakshmi narayan temple',
      ];
    }
    
    // Bangalore
    if (key.contains('bangalore') || key.contains('bengaluru')) {
      return [
        'cubbon park', 'lalbagh botanical garden', 'vidhana soudha', 'tipu sultan palace',
        'bangalore palace', 'isckon temple', 'ulsoor lake', 'bannerghatta national park',
        'wonderla', 'commercial street', 'brigade road', 'mg road', 'ub city', 'phoenix marketcity',
        'innovative film city', 'nandi hills', 'hampi', 'mysore palace', 'chamundi hills',
        'srirangapatna', 'brindavan gardens', 'bandipur national park', 'coorg', 'ooty',
        'shivanasamudra falls', 'talakadu', 'somnathpur temple', 'belur halebidu', 'shravanabelagola',
        'national gallery of modern art', 'visvesvaraya industrial museum', 'venkatappa art gallery',
        'government museum', 'kempegowda museum', 'hal aerospace museum', 'indian institute of science',
      ];
    }
    
    // Rajasthan
    if (key.contains('jaipur') || key.contains('rajasthan')) {
      return [
        'amber fort', 'hawa mahal', 'city palace', 'jantar mantar', 'jal mahal', 'nahargarh fort',
        'jaigarh fort', 'birla temple', 'govind dev ji temple', 'galta ji temple', 'sambhar lake',
        'raj mandir cinema', 'central park', 'jawahar circle garden', 'sisodia rani garden',
        'ram niwas garden', 'albert hall museum', 'maharaja sawai man singh museum',
        'pink city', 'bapu bazaar', 'johari bazaar', 'tripolia bazaar', 'chandpole bazaar',
        'rajasthan high court', 'vidhan sabha', 'secretariat', 'rajasthan university',
      ];
    }
    if (key.contains('udaipur')) {
      return [
        'city palace', 'lake pichola', 'jag mandir', 'jagdish temple', 'fateh sagar lake',
        'saheliyon ki bari', 'sajjangarh palace', 'monsoon palace', 'kumbhalgarh fort',
        'ranakpur temple', 'eklingji temple', 'nathdwara temple', 'chittorgarh fort',
        'doodh talai', 'sukhadia circle', 'maharana pratap memorial', 'aravalli hills',
        'udaipur solar observatory', 'bagore ki haveli', 'shilpgram', 'bharatiya lok kala museum',
      ];
    }
    if (key.contains('jodhpur')) {
      return [
        'mehrangarh fort', 'jaswant thada', 'ummaid bhawan palace', 'mandore garden',
        'ghanta ghar', 'clock tower', 'sardar market', 'osian temples', 'bishnoi village',
        'kaylana lake', 'machia biological park', 'rao jodha desert rock park',
        'stepwell', 'toorji ka jhalra', 'mahamandir temple', 'chamunda mata temple',
        'ranisagar lake', 'bal samand lake', 'jodhpur fort', 'blue city',
      ];
    }
    if (key.contains('jaisalmer')) {
      return [
        'jaisalmer fort', 'patwon ki haveli', 'salim singh ki haveli', 'nathmal ki haveli',
        'sam sand dunes', 'khuri sand dunes', 'desert national park', 'bada bagh',
        'gadisar lake', 'tazia tower', 'jain temples', 'akal wood fossil park',
        'kuldhara village', 'khaba fort', 'longewala war memorial', 'tanot mata temple',
        'ramdevra temple', 'pokhran', 'thar desert', 'camel safari', 'desert camping',
      ];
    }
    
    // Himachal Pradesh
    if (key.contains('manali') || key.contains('himachal')) {
      return [
        'rohtang pass', 'solang valley', 'hadimba temple', 'manu temple', 'vashisht temple',
        'old manali', 'mall road', 'jogini falls', 'beas kund', 'chandrakhani pass',
        'hamta pass', 'bhrigu lake', 'gulaba', 'kothi', 'rahi falls', 'manikaran',
        'kasol', 'malana', 'tosh', 'kheerganga', 'parvati valley', 'great himalayan national park',
        'pin valley national park', 'dalhousie', 'khajjiar', 'dharamshala', 'mcleod ganj',
        'triund', 'bhagsu falls', 'st john church', 'namgyal monastery', 'tibet museum',
      ];
    }
    if (key.contains('shimla')) {
      return [
        'mall road', 'ridge', 'jakhu temple', 'christ church', 'gaiety theatre',
        'kufri', 'chadwick falls', 'tara devi temple', 'himalayan bird park',
        'indian institute of advanced study', 'summer hill', 'prospect hill',
        'annandale', 'scandal point', 'laxminarayan temple', 'kali bari temple',
        'state museum', 'viceregal lodge', 'gorton castle', 'peterhoff',
        'wildflower hall', 'chail', 'kasauli', 'solan', 'barog',
      ];
    }
    
    // Tamil Nadu
    if (key.contains('chennai') || key.contains('madras')) {
      return [
        'marina beach', 'kapaleeshwarar temple', 'san thome basilica', 'fort st george',
        'government museum', 'valluvar kottam', 'birla planetarium', 'guindy national park',
        'anna centenary library', 'sri parthasarathy temple', 'ashtalakshmi temple',
        'kalakshetra foundation', 'theosophical society', 'adyar banyan tree',
        'mylapore', 'triplicane', 'george town', 't nagar', 'pondy bazaar',
        'phoenix market city', 'express avenue', 'forum mall', 'spencer plaza',
        'crocodile bank', 'mahabalipuram', 'kanchipuram', 'vellore fort',
      ];
    }
    if (key.contains('madurai')) {
      return [
        'meenakshi temple', 'thirumalai nayakkar palace', 'gandhi museum', 'alagar kovil',
        'koodal azhagar temple', 'thiruparankundram temple', 'vaigai dam', 'gandhi memorial museum',
        'rajaji park', 'mariamman teppakulam', 'vellore fort', 'sri rangam temple',
        'srirangapatna', 'thanjavur', 'brihadeeswarar temple', 'gangaikonda cholapuram',
        'darasuram temple', 'chidambaram temple', 'rameshwaram', 'kanyakumari',
      ];
    }
    
    // Kanyakumari - Southernmost Tip of India
    if (key.contains('kanyakumari') || key.contains('cape comorin')) {
      return [
        'vivekananda rock memorial', 'thiruvalluvar statue', 'kanyakumari beach', 'sunrise point',
        'sunset point', 'gandhi memorial', 'kumari amman temple', 'our lady of ransom church',
        'vattakottai fort', 'mathur hanging bridge', 'padmanabhapuram palace', 'suchindram temple',
        'thanumalayan temple', 'st xavier church', 'baywatch amusement park', 'wax museum',
        'tsunami memorial', 'gandhi mandapam', 'kanyakumari lighthouse', 'sanguthurai beach',
        'chothavilai beach', 'muttom beach', 'sothavilai beach', 'colachel beach',
        'pechiparai dam', 'kalikesam dam', 'mathur aqueduct', 'ulakkai aruvi waterfalls',
        'keeriparai', 'marunthuvazh malai', 'nagercoil', 'padmanabhapuram',
      ];
    }
    
    // Dwarka - Sacred City
    if (key.contains('dwarka')) {
      return [
        'dwarkadhish temple', 'rukmini temple', 'bet dwarka', 'nageshwar jyotirlinga',
        'gomti ghat', 'sudama setu', 'dwarka beach', 'dwarka lighthouse', 'dwarka museum',
        'beyt dwarka island', 'gopi talav', 'dwarka archaeological museum', 'dwarka fort',
      ];
    }
    
    // Bodh Gaya - Sacred Buddhist Site
    if (key.contains('bodh gaya') || key.contains('bodhgaya')) {
      return [
        'mahabodhi temple', 'bodhi tree', 'thai monastery', 'japanese monastery',
        'tibetan monastery', 'chinese monastery', 'archaeological museum', 'great buddha statue',
        'muchalinda lake', 'rajayatna tree', 'animeshlochan chaitya', 'ratnagarh',
        'indosan nipponji temple', 'royal bhutan monastery', 'dungeshwari caves',
      ];
    }
    
    // Gangtok - Sikkim Capital
    if (key.contains('gangtok') || key.contains('sikkim')) {
      return [
        'tsomgo lake', 'baba harbhajan singh temple', 'nathula pass', 'hanuman tok',
        'ganesh tok', 'tashi viewpoint', 'enchey monastery', 'rumtek monastery',
        'do drul chorten', 'namgyal institute of tibetology', 'flower exhibition centre',
        'ban jhakri falls', 'seven sisters waterfall', 'tashi viewpoint', 'mg marg',
        'pemayangtse monastery', 'rabdentse ruins', 'khecheopalri lake', 'yumthang valley',
      ];
    }
    
    // Shillong - Scotland of East
    if (key.contains('shillong') || key.contains('meghalaya')) {
      return [
        'elephant falls', 'shillong peak', 'umiam lake', 'lady hydari park',
        'don bosco museum', 'ward lake', 'sweet falls', 'crater lake',
        'cherrapunji', 'mawlynnong', 'dawki', 'living root bridge', 'nohkalikai falls',
        'seven sisters falls', 'mawsmai cave', 'dainthlen falls', 'krem phyllut cave',
      ];
    }
    
    // Karnataka - Mysore - City of Palaces
    if (key.contains('mysore') || key.contains('mysuru')) {
      return [
        // Palaces & Heritage
        'mysore palace', 'jaganmohan palace', 'lalitha mahal palace', 'jayalakshmi vilas mansion',
        'chamundi hills', 'chamundi temple', 'brindavan gardens', 'srirangapatna',
        'daria daulat bagh', 'gumbaz', 'rani lakshmi bai memorial', 'tipu sultan summer palace',
        // Viewpoints & Scenic Spots
        'chamundi hill viewpoint', 'karanji lake', 'kukkarahalli lake', 'lingambudhi lake',
        'hebbal lake', 'balmuri falls', 'gaganachukki falls', 'barachukki falls',
        // Museums & Culture
        'mysore zoo', 'rail museum', 'folklore museum', 'regional museum of natural history',
        'wax museum', 'sand museum', 'oriental research institute', 'government museum',
        // Temples & Religious Sites
        'st philomena cathedral', 'trinidad cathedral', 'somnathpur temple', 'talakadu',
        'belur halebidu', 'shravanabelagola', 'melkote', 'srirangapatna temple',
        // Nature & Wildlife
        'bandipur national park', 'nagarhole national park', 'madhugiri', 'shivanasamudra falls',
        'coorg', 'ooty', 'nandi hills', 'skandagiri hills',
      ];
    }
    
    // West Bengal
    if (key.contains('kolkata') || key.contains('calcutta')) {
      return [
        'victoria memorial', 'howrah bridge', 'princep ghat', 'eden gardens', 'salt lake stadium',
        'indian museum', 'marble palace', 'birla planetarium', 'kalighat temple',
        'belur math', 'dakshineswar temple', 'rabindra sarovar', 'eco park',
        'nicco park', 'science city', 'alipore zoo', 'botanical garden',
        'new market', 'park street', 'chowringhee', 'bara bazaar', 'burra bazaar',
        'sunderbans national park', 'darjeeling', 'kalimpong', 'mirik',
      ];
    }
    if (key.contains('darjeeling')) {
      return [
        'tiger hill', 'batasia loop', 'peace pagoda', 'padmaja naidu himalayan zoological park',
        'himalayan mountaineering institute', 'ropeway', 'tea garden', 'rock garden',
        'ganga maya park', 'observatory hill', 'st andrew church', 'lloyd botanical garden',
        'toy train', 'darjeeling himalayan railway', 'ghoom', 'kalimpong', 'mirik',
        'sandakphu', 'singalila national park', 'phalut', 'kanchenjunga national park',
      ];
    }
    
    // Gujarat
    if (key.contains('ahmedabad') || key.contains('gujarat')) {
      return [
        'sabarmati ashram', 'adalaj stepwell', 'sidi saiyed mosque', 'jama masjid',
        'bhadra fort', 'kankaria lake', 'science city', 'auto world vintage car museum',
        'calico museum of textiles', 'sanskar kendra', 'law garden', 'riverfront',
        'gandhi ashram', 'swaminarayan temple', 'akshardham temple', 'hathee singh temple',
        'sarkhej roza', 'dada hari ni vav', 'rani ki vav', 'modhera sun temple',
        'dwarka', 'somnath temple', 'gir national park', 'rann of kutch',
      ];
    }
    
    // Punjab
    if (key.contains('amritsar') || key.contains('punjab')) {
      return [
        'golden temple', 'harmandir sahib', 'jallianwala bagh', 'wagah border',
        'akal takht', 'guru ka langar', 'ram bagh', 'durgiana temple',
        'mata lal devi temple', 'khalsa college', 'partition museum',
        'maharaja ranjit singh museum', 'gobindgarh fort', 'tarn taran',
        'baba atal rai tower', 'gurdwara baba deep singh', 'gurdwara shaheed baba',
        'chandigarh', 'rock garden', 'sukhna lake', 'rose garden',
      ];
    }
    
    // Jammu & Kashmir
    if (key.contains('srinagar') || key.contains('kashmir')) {
      return [
        'dal lake', 'nagin lake', 'shalimar bagh', 'nishat bagh', 'chashme shahi',
        'pari mahal', 'shankaracharya temple', 'hazratbal shrine', 'jamia masjid',
        'khanqah of shah hamdan', 'makhdoom sahib', 'charar e sharif', 'sonmarg',
        'gulmarg', 'pahalgam', 'yusmarg', 'aharbal falls', 'verinag', 'betaab valley',
        'aaru valley', 'chandanwari', 'sheshnag lake', 'amarnath cave', 'vaishno devi',
      ];
    }
    
    // Odisha
    if (key.contains('bhubaneswar') || key.contains('odisha')) {
      return [
        'lingaraj temple', 'mukteshwar temple', 'rajarani temple', 'parasurameswar temple',
        'khandagiri caves', 'udayagiri caves', 'dhauli hills', 'nandankanan zoological park',
        'ekamra kanan', 'buddhist monuments', 'konark sun temple', 'jagannath temple',
        'chilika lake', 'simlipal national park', 'bhitarkanika national park',
        'gopalpur beach', 'purushottampur beach', 'chandrabhaga beach', 'ramchandi beach',
        'pipli', 'ragurajpur', 'dhauli', 'ratnagiri', 'lalitgiri', 'uddiyan',
      ];
    }
    
    // Assam
    if (key.contains('guwahati') || key.contains('assam')) {
      return [
        'kamakhya temple', 'uma nanda temple', 'navagraha temple', 'basistha temple',
        'balaji temple', 'sukreswar temple', 'assam state museum', 'assam state zoo',
        'kaziranga national park', 'manas national park', 'dibru saikhowa national park',
        'nameri national park', 'orang national park', 'pobitora wildlife sanctuary',
        'majuli island', 'sualkuchi', 'hajo', 'peacock island', 'umananda island',
        'bharalumukh', 'saraighat bridge', 'science museum', 'planetarium',
      ];
    }
    
    // Madhya Pradesh
    if (key.contains('bhopal') || key.contains('madhya pradesh')) {
      return [
        'upper lake', 'lower lake', 'taj ul masajid', 'gohar mahal', 'shaukat mahal',
        'sadhna mahal', 'birla museum', 'state museum', 'tribal museum', 'regional museum',
        'sanchi stupa', 'bhimbetka caves', 'khajuraho', 'kanha national park',
        'bandhavgarh national park', 'panna national park', 'pench national park',
        'satpura national park', 'orchha', 'gwalior fort', 'jai vilas palace',
        'mandu', 'omkareshwar', 'maheshwar', 'ujjain', 'mahakaleshwar temple',
      ];
    }
    
    // Andhra Pradesh & Telangana
    if (key.contains('hyderabad') || key.contains('telangana')) {
      return [
        'charminar', 'golconda fort', 'qutub shahi tombs', 'salar jung museum',
        'birla mandir', 'mecca masjid', 'hussain sagar lake', 'necklace road',
        'ramoji film city', 'snow world', 'ocean park', 'nehru zoological park',
        'kbr national park', 'shilparamam', 'hi tech city', 'cyberabad',
        'warangal fort', 'thousand pillar temple', 'ramappa temple', 'bhongir fort',
        'nagarjuna sagar', 'eturnagaram wildlife sanctuary', 'kawal wildlife sanctuary',
      ];
    }
    if (key.contains('visakhapatnam') || key.contains('vizag')) {
      return [
        'araku valley', 'borra caves', 'katiki waterfalls', 'tadimada waterfalls',
        'rushikonda beach', 'ramakrishna beach', 'yarada beach', 'bheemili beach',
        'submarine museum', 'vuda park', 'kailasagiri', 'simhachalam temple',
        'sri varaha lakshmi narasimha temple', 'thotlakonda', 'bavikonda', 'sankaram',
        'indira gandhi zoological park', 'kambalakonda wildlife sanctuary',
        'matsyagandhi beach', 'gangavaram beach', 'dolphin nose', 'kailasagiri hills',
      ];
    }
    
    // Bihar
    if (key.contains('patna') || key.contains('bihar')) {
      return [
        'mahavir mandir', 'patna sahib', 'gurudwara patna sahib', 'patna museum',
        'golghar', 'patna planetarium', 'buddha smriti park', 'eco park',
        'sanjay gandhi jaivik udyan', 'rajgir', 'nalanda', 'bodh gaya',
        'vaishali', 'kesaria stupa', 'vikramshila', 'sher shah suri tomb',
        'barabar caves', 'rohtasgarh fort', 'sasaram', 'gaya', 'mahabodhi temple',
        'dungeshwari caves', 'thai monastery', 'japanese monastery', 'tibetan monastery',
      ];
    }
    
    // Jharkhand
    if (key.contains('ranchi') || key.contains('jharkhand')) {
      return [
        'ranchi hill', 'tagore hill', 'rock garden', 'ranchi lake', 'kanke dam',
        'birsa zoological park', 'ranchi science centre', 'state museum',
        'jagannath temple', 'sun temple', 'angrabadi temple', 'pahari mandir',
        'betla national park', 'hazaribagh national park', 'dalma wildlife sanctuary',
        'netarhat', 'patratu', 'jonha falls', 'hudru falls', 'dassam falls',
        'panchghagh falls', 'sita falls', 'lodh falls', 'rajrappa temple',
      ];
    }
    
    // Chhattisgarh
    if (key.contains('raipur') || key.contains('chhattisgarh')) {
      return [
        'mahant ghasidas memorial museum', 'budha talab', 'nandan van zoo',
        'guru teg bahadur memorial', 'dudhadhari temple', 'hatkeshwar mahadev temple',
        'bambleshwari temple', 'chitrakote falls', 'tirathgarh falls', 'kanger valley national park',
        'indravati national park', 'guru ghasi das national park', 'barnawapara wildlife sanctuary',
        'sitanadi wildlife sanctuary', 'udanti wildlife sanctuary', 'bhoramdeo temple',
        'rajim', 'sirpur', 'malhar', 'tala', 'kutumsar caves', 'kailash caves',
      ];
    }
    
    // Uttarakhand
    if (key.contains('rishikesh') || key.contains('haridwar') || key.contains('uttarakhand')) {
      return [
        'lakshman jhula', 'ram jhula', 'triveni ghat', 'geeta bhawan', 'swarg ashram',
        'neelkanth mahadev temple', 'bharat mandir', 'trimbakeshwar temple',
        'har ki pauri', 'maya devi temple', 'chandi devi temple', 'mansa devi temple',
        'rajaji national park', 'corbett national park', 'valley of flowers',
        'hemkund sahib', 'badrinath', 'kedarnath', 'gangotri', 'yamunotri',
        'auli', 'mussourie', 'nainital', 'ranikhet', 'almora', 'kausani',
      ];
    }
    
    // Haryana
    if (key.contains('gurgaon') || key.contains('gurugram') || key.contains('haryana')) {
      return [
        'cyber city', 'mg road', 'sultanpur national park', 'damdama lake',
        'kingdom of dreams', 'appu ghar', 'leisure valley park', 'cyber hub',
        'ambience mall', 'select city walk', 'dlf mall', 'worldmark gurgaon',
        'kurukshetra', 'panipat', 'karnal', 'faridabad', 'rohtak', 'hisar',
        'surajkund', 'badkhal lake', 'tilyar lake', 'blue jay lake',
      ];
    }
    
    // Return empty list for unknown destinations
    return [];
  }

  // Score attractions by tags and curated relevance
  int _scorePlace(PlaceDetails place, List<String> curatedKeywords) {
    int score = 0;

    // Strong signals for attractions
    const attractionTypes = {
      'attraction','museum','gallery','zoo','theme_park','monument','memorial','artwork','viewpoint','information'
    };
    if (place.tourismType != null && attractionTypes.contains(place.tourismType)) {
      score += 30;
    }

    // Enhanced natural/heritage boosts for diverse attractions
    final natural = place.additionalTags['natural'];
    final heritage = place.additionalTags['heritage'];
    final historic = place.additionalTags['historic'];
    final leisure = place.additionalTags['leisure'];
    final water = place.additionalTags['water'];
    final manMade = place.additionalTags['man_made'];
    
    // Beaches and water bodies - HIGH PRIORITY for tourists
    if (natural == 'beach' || place.additionalTags['place'] == 'beach') score += 50; // Increased from 40
    if (natural == 'waterfall' || water == 'waterfall') score += 45; // Increased from 35
    if (natural == 'lake' || natural == 'river' || natural == 'coastline') score += 30; // Increased from 25
    
    // Viewpoints - VERY HIGH PRIORITY for tourists
    if (place.tourismType == 'viewpoint' || place.name.toLowerCase().contains('viewpoint') || 
        place.name.toLowerCase().contains('view point') || place.name.toLowerCase().contains('point')) {
      score += 50; // Very high priority for viewpoints
    }
    
    // Hills and mountains
    if (natural == 'peak' || natural == 'hill' || natural == 'ridge') score += 35; // Increased from 30
    if (natural == 'volcano' || natural == 'cliff') score += 30; // Increased from 25
    
    // Parks and gardens
    if (leisure == 'park' || leisure == 'garden' || leisure == 'nature_reserve') score += 25;
    if (leisure == 'golf_course' || leisure == 'sports_centre') score += 20;
    
    // Heritage and historic sites
    if (heritage != null) score += 30;
    if (historic == 'ruins' || historic == 'castle' || historic == 'fort') score += 35;
    if (historic == 'monument' || historic == 'memorial') score += 25;
    if (historic == 'tomb' || historic == 'palace') score += 30;
    
    // Religious and cultural sites
    if (place.amenityType == 'place_of_worship') score += 25;
    if (place.amenityType == 'monastery') score += 30;
    
    // Adventure and outdoor activities
    if (leisure == 'sports_centre' || leisure == 'stadium') score += 20;
    if (manMade == 'bridge' || manMade == 'tower') score += 20;
    
    // Wildlife and nature reserves
    if (natural == 'forest' || natural == 'woodland') score += 25;
    if (place.additionalTags.containsKey('boundary') && 
        place.additionalTags['boundary'] == 'national_park') score += 40;

    // Presence on Wikipedia/Wikidata => popular
    if (place.additionalTags.containsKey('wikidata')) score += 20;
    if (place.additionalTags.containsKey('wikipedia')) score += 20;

    // Known rating stars
    if (place.rating != null) {
      score += (place.rating!.round() * 3);
    }

    // Curated name matching - BIGGEST BOOST
    final name = place.name.toLowerCase();
    for (final kw in curatedKeywords) {
      if (name.contains(kw)) {
        score += 100; // HUGE boost for famous places
        break;
      }
    }

    // Enhanced boost for famous place keywords - PRIORITIZE TOURIST ATTRACTIONS
    if (name.contains('beach')) score += 30; // Highest priority for beaches
    if (name.contains('waterfall') || name.contains('falls')) score += 30; // Highest priority for waterfalls
    if (name.contains('viewpoint') || name.contains('view point') || name.contains('point')) score += 30; // Highest priority for viewpoints
    if (name.contains('fort') || name.contains('palace')) score += 25; // High priority for forts/palaces
    if (name.contains('temple') || name.contains('church') || name.contains('mosque')) score += 20;
    if (name.contains('hill') || name.contains('mountain') || name.contains('peak')) score += 25;
    if (name.contains('museum') || name.contains('gallery')) score += 20;
    if (name.contains('park') || name.contains('garden')) score += 20;
    if (name.contains('lake') || name.contains('river') || name.contains('dam')) score += 25;
    if (name.contains('valley')) score += 25;
    if (name.contains('national park') || name.contains('wildlife') || name.contains('sanctuary')) score += 30;
    if (name.contains('cave')) score += 25;
    if (name.contains('island')) score += 25;
    if (name.contains('zoo') || name.contains('aquarium') || name.contains('botanical')) score += 20;
    if (name.contains('heritage') || name.contains('monument') || name.contains('memorial')) score += 20;

    // Boost for adventure and outdoor activity keywords
    if (name.contains('adventure') || name.contains('trekking') || name.contains('camping') ||
        name.contains('safari') || name.contains('rafting') || name.contains('climbing') ||
        name.contains('hiking') || name.contains('cycling') || name.contains('boating')) {
      score += 25;
    }

    // Boost for cultural and spiritual keywords
    if (name.contains('ashram') || name.contains('monastery') || name.contains('gurudwara') ||
        name.contains('mosque') || name.contains('church') || name.contains('cathedral') ||
        name.contains('basilica') || name.contains('dargah') || name.contains('shrine')) {
      score += 25;
    }

    // Penalize non-attraction amenities
    const nonAttractionAmenities = {'supermarket','convenience','bank','atm','pharmacy','fuel','parking','post_office','police','fire_station'};
    final amenity = place.amenityType;
    if (amenity != null && nonAttractionAmenities.contains(amenity)) {
      score -= 50;
    }

    // Boost for places with good descriptions
    if (place.description != null && place.description!.length > 20) {
      score += 10;
    }

    // Boost for places with opening hours (indicates they're tourist-friendly)
    if (place.additionalTags.containsKey('opening_hours')) {
      score += 15;
    }

    // Boost for places with contact information (indicates they're established)
    if (place.additionalTags.containsKey('phone') || place.additionalTags.containsKey('website')) {
      score += 10;
    }

    return score;
  }

  List<PlaceDetails> _rankAttractions(String destination, Map<String, List<PlaceDetails>> categorizedPlaces) {
    final curated = _getCuratedKeywords(destination);
    final attractions = List<PlaceDetails>.from(categorizedPlaces['attractions'] ?? []);
    attractions.sort((a, b) => _scorePlace(b, curated).compareTo(_scorePlace(a, curated)));
    return attractions;
  }

  List<DayPlan> _generateSmartItinerary(
    Map<String, List<PlaceDetails>> categorizedPlaces,
    int durationInDays,
    List<String> interests,
    int travelers,
    double? budgetAmount,
    String? transportation,
    String destination,
    BudgetLevel budgetLevel,
  ) {
    final dayPlans = <DayPlan>[];
    final usedPlaces = <String>{}; // Track used places to prevent duplicates
    // Pre-rank attractions for the destination so we can pick the best first
    final rankedAttractions = _rankAttractions(destination, categorizedPlaces);

    for (int day = 0; day < durationInDays; day++) {
      final activities = <Activity>[];
      final timeSlots = _generateTimeSlots();

      // Morning activity (9:00 AM - 12:00 PM) - PRIORITIZE ATTRACTIONS
      final morningActivity = _selectActivity(
        categorizedPlaces,
        interests,
        'morning',
        day,
        budgetAmount,
        travelers,
        durationInDays,
        transportation,
        usedPlaces,
        budgetLevel,
        destination,
        rankedAttractions,
      );
      if (morningActivity != null) {
        final attractionCost = _getBudgetAppropriateAttractionCost(budgetLevel, morningActivity.tourismType ?? 'attraction');
        activities.add(Activity.fromPlaceDetails(
          morningActivity,
          timeSlots['morning']!,
          customCost: attractionCost,
        ));
        usedPlaces.add(_getPlaceKey(morningActivity));
      }

      // Late morning activity (11:00 AM - 12:00 PM) - Additional attraction (moved before afternoon)
      if (dayPlans.length < durationInDays || day == 0) {
        final lateMorningActivity = _selectActivity(
          categorizedPlaces,
          interests,
          'morning',
          day,
          budgetAmount,
          travelers,
          durationInDays,
          transportation,
          usedPlaces,
          budgetLevel,
          destination,
          rankedAttractions,
        );
        if (lateMorningActivity != null) {
          final attractionCost = _getBudgetAppropriateAttractionCost(budgetLevel, lateMorningActivity.tourismType ?? 'attraction');
          activities.add(Activity.fromPlaceDetails(
            lateMorningActivity,
            '11:00 AM',
            customCost: attractionCost,
          ));
          usedPlaces.add(_getPlaceKey(lateMorningActivity));
        }
      }

      // Afternoon activity (2:00 PM - 5:00 PM) - PRIORITIZE ATTRACTIONS
      final afternoonActivity = _selectActivity(
        categorizedPlaces,
        interests,
        'afternoon',
        day,
        budgetAmount,
        travelers,
        durationInDays,
        transportation,
        usedPlaces,
        budgetLevel,
        destination,
        rankedAttractions,
      );
      if (afternoonActivity != null) {
        final attractionCost = _getBudgetAppropriateAttractionCost(budgetLevel, afternoonActivity.tourismType ?? 'attraction');
        activities.add(Activity.fromPlaceDetails(
          afternoonActivity,
          timeSlots['afternoon']!,
          customCost: attractionCost,
        ));
        usedPlaces.add(_getPlaceKey(afternoonActivity));
      }

      // Evening activity (5:00 PM - 8:00 PM) - PRIORITIZE ATTRACTIONS
      final eveningActivity = _selectActivity(
        categorizedPlaces,
        interests,
        'evening',
        day,
        budgetAmount,
        travelers,
        durationInDays,
        transportation,
        usedPlaces,
        budgetLevel,
        destination,
        rankedAttractions,
      );
      if (eveningActivity != null) {
        final attractionCost = _getBudgetAppropriateAttractionCost(budgetLevel, eveningActivity.tourismType ?? 'attraction');
        activities.add(Activity.fromPlaceDetails(
          eveningActivity,
          timeSlots['evening']!,
          customCost: attractionCost,
        ));
        usedPlaces.add(_getPlaceKey(eveningActivity));
      }

      // Add ONLY ONE food activity per day (alternate between lunch and dinner)
      final shouldAddLunch = day % 2 == 0; // Even days get lunch, odd days get dinner
      
      if (shouldAddLunch) {
        // Lunch (12:00 PM - 2:00 PM)
        final lunchPlace = _selectRestaurant(categorizedPlaces, day, usedPlaces: usedPlaces, budgetLevel: budgetLevel);
        if (lunchPlace != null) {
          final restaurantCost = _getBudgetAppropriateRestaurantCost(budgetLevel, false);
          activities.add(Activity.fromPlaceDetails(
            lunchPlace, 
            timeSlots['lunch']!,
            customCost: restaurantCost,
          ));
          usedPlaces.add(_getPlaceKey(lunchPlace));
        }
      } else {
        // Dinner (8:00 PM - 10:00 PM)
        final dinnerPlace = _selectRestaurant(categorizedPlaces, day, usedPlaces: usedPlaces, isDinner: true, budgetLevel: budgetLevel);
        if (dinnerPlace != null) {
          final restaurantCost = _getBudgetAppropriateRestaurantCost(budgetLevel, true);
          activities.add(Activity.fromPlaceDetails(
            dinnerPlace, 
            timeSlots['dinner']!,
            customCost: restaurantCost,
          ));
          usedPlaces.add(_getPlaceKey(dinnerPlace));
        }
      }

      if (activities.isNotEmpty) {
        // Add transportation activities
        final transportActivities = _generateTransportationActivities(transportation, travelers, day + 1, budgetLevel);
        activities.addAll(transportActivities);
        
        // Sort activities by time to ensure chronological order
        activities.sort((a, b) => _compareTime(a.time, b.time));
        
        // Use dynamic budget calculation if user provided budget, otherwise use budget level
        final dayCost = budgetAmount != null 
            ? _calculateDynamicBudgetDayCost(activities, travelers, budgetAmount, durationInDays)
            : _calculateBudgetAwareDayCost(activities, travelers, budgetLevel);
        dayPlans.add(DayPlan(
          dayTitle: 'Day ${day + 1}',
          description: _generateDayDescription(day + 1, activities),
          activities: activities,
          totalEstimatedCost: dayCost,
        ));
      }
    }

    return dayPlans;
  }

  // Helper method to create a unique key for a place
  String _getPlaceKey(PlaceDetails place) {
    // Use coordinates and name to create a unique key
    return '${place.name}_${place.lat.toStringAsFixed(6)}_${place.lon.toStringAsFixed(6)}';
  }

  // Check if two places are similar (same location or very similar names)
  bool _arePlacesSimilar(PlaceDetails place1, PlaceDetails place2) {
    // Check if coordinates are very close (within ~100 meters)
    final latDiff = (place1.lat - place2.lat).abs();
    final lonDiff = (place1.lon - place2.lon).abs();
    if (latDiff < 0.001 && lonDiff < 0.001) {
      return true;
    }
    
    // Check if names are very similar (case-insensitive)
    final name1 = place1.name.toLowerCase().trim();
    final name2 = place2.name.toLowerCase().trim();
    
    // Exact match
    if (name1 == name2) return true;
    
    // One name contains the other
    if (name1.contains(name2) || name2.contains(name1)) return true;
    
    // Check for common variations
    final variations1 = _getCommonVariations(name1);
    final variations2 = _getCommonVariations(name2);
    
    for (final var1 in variations1) {
      for (final var2 in variations2) {
        if (var1 == var2) return true;
      }
    }
    
    return false;
  }

  // Get common variations of a place name
  List<String> _getCommonVariations(String name) {
    final variations = <String>[name];
    
    // Remove common prefixes/suffixes
    final cleanName = name
        .replaceAll(RegExp(r'\b(the|a|an)\b'), '')
        .replaceAll(RegExp(r'\b(temple|fort|palace|beach|park|garden|lake|hill|mountain)\b'), '')
        .trim();
    
    if (cleanName != name && cleanName.isNotEmpty) {
      variations.add(cleanName);
    }
    
    // Add abbreviated versions
    final words = name.split(' ');
    if (words.length > 1) {
      final abbreviated = words.map((word) => word.length > 3 ? word.substring(0, 3) : word).join(' ');
      variations.add(abbreviated);
    }
    
    return variations;
  }

  // Check if one name is better English than another
  bool _isBetterEnglishName(String name1, String name2) {
    // Prefer names that look more like English
    final isEnglish1 = _isEnglishText(name1);
    final isEnglish2 = _isEnglishText(name2);
    
    if (isEnglish1 && !isEnglish2) return true;
    if (!isEnglish1 && isEnglish2) return false;
    
    // If both are English or both are not, prefer shorter names
    return name1.length < name2.length;
  }

  // Check if text appears to be in English (reused from PlaceDetails)
  bool _isEnglishText(String text) {
    // Remove common punctuation and check if remaining characters are mostly English
    final cleanText = text.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (cleanText.isEmpty) return false;
    
    // Check if text contains mostly English characters (a-z, A-Z, spaces)
    final englishPattern = RegExp(r'^[a-zA-Z\s]+$');
    if (englishPattern.hasMatch(cleanText)) {
      return true;
    }
    
    // Check if text contains common English words or patterns
    final commonEnglishWords = [
      'beach', 'fort', 'palace', 'temple', 'church', 'mosque', 'museum', 'park', 'garden',
      'lake', 'hill', 'mountain', 'falls', 'waterfall', 'valley', 'river', 'bridge',
      'market', 'mall', 'restaurant', 'hotel', 'station', 'airport', 'hospital', 'school',
      'university', 'college', 'library', 'theater', 'cinema', 'stadium', 'zoo', 'aquarium',
      'national', 'international', 'central', 'north', 'south', 'east', 'west', 'old', 'new'
    ];
    
    final lowerText = cleanText.toLowerCase();
    for (final word in commonEnglishWords) {
      if (lowerText.contains(word)) {
        return true;
      }
    }
    
    return false;
  }

  Map<String, String> _generateTimeSlots() {
    return {
      'morning': '9:00 AM',
      'lunch': '12:30 PM',
      'afternoon': '2:30 PM',
      'evening': '5:30 PM',
      'dinner': '8:00 PM',
    };
  }

  /// Compare two time strings (e.g., "9:00 AM", "2:30 PM") and return comparison result
  int _compareTime(String time1, String time2) {
    final time1Minutes = _timeToMinutes(time1);
    final time2Minutes = _timeToMinutes(time2);
    return time1Minutes.compareTo(time2Minutes);
  }

  /// Convert time string (e.g., "9:00 AM", "2:30 PM") to minutes since midnight
  int _timeToMinutes(String time) {
    try {
      // Remove spaces and convert to uppercase
      final cleanTime = time.trim().toUpperCase();
      
      // Check if AM or PM
      final isPM = cleanTime.contains('PM');
      final isAM = cleanTime.contains('AM');
      
      // Extract hour and minute
      final timePart = cleanTime.replaceAll(RegExp(r'[APM\s]'), '');
      final parts = timePart.split(':');
      
      if (parts.length < 2) return 0;
      
      int hour = int.tryParse(parts[0]) ?? 0;
      int minute = int.tryParse(parts[1]) ?? 0;
      
      // Convert to 24-hour format
      if (isPM && hour != 12) {
        hour += 12;
      } else if (isAM && hour == 12) {
        hour = 0;
      }
      
      return hour * 60 + minute;
    } catch (e) {
      // If parsing fails, return 0 (midnight) as default
      return 0;
    }
  }

  PlaceDetails? _selectActivity(
    Map<String, List<PlaceDetails>> categorizedPlaces,
    List<String> interests,
    String timeOfDay,
    int day,
    double? budgetAmount,
    int travelers,
    int durationInDays,
    String? transportation,
    Set<String> usedPlaces,
    BudgetLevel budgetLevel,
    String destination,
    List<PlaceDetails> rankedAttractions,
  ) {
    final random = Random();

    bool isTimeAppropriate(PlaceDetails place) {
      switch (timeOfDay) {
        case 'morning':
          return place.tourismType != 'nightclub' && place.amenityType != 'nightclub';
        case 'afternoon':
          return true;
        case 'evening':
          return place.tourismType != 'museum' && place.amenityType != 'cafe';
        default:
          return true;
      }
    }

    double? availableBudget;
    if (budgetAmount != null) {
      final dailyBudget = budgetAmount / durationInDays; // Approximate daily budget
      final transportCost = _getTransportationCost(transportation, travelers);
      availableBudget = dailyBudget - transportCost; // Reserve budget for transport
    }

    // Try to pick the next best-ranked attraction first (destination-specific, curated)
    PlaceDetails? _takeNextRankedAttraction() {
      while (rankedAttractions.isNotEmpty) {
        final candidate = rankedAttractions.removeAt(0);
        if (usedPlaces.contains(_getPlaceKey(candidate))) continue;
        if (!isTimeAppropriate(candidate)) continue;
        if (availableBudget != null && _getPlaceCost(candidate) > availableBudget) continue;
        return candidate;
      }
      return null;
    }

    final rankedPick = _takeNextRankedAttraction();
    if (rankedPick != null) {
      return rankedPick;
    }

    List<PlaceDetails> candidates = [];

    // PRIORITIZE ATTRACTIONS - Always add attractions first
    candidates.addAll(categorizedPlaces['attractions'] ?? []);
    
    // Add parks and entertainment as secondary options
    candidates.addAll(categorizedPlaces['parks'] ?? []);
    candidates.addAll(categorizedPlaces['entertainment'] ?? []);
    
    // Add religious sites for cultural experiences
    candidates.addAll(categorizedPlaces['religious'] ?? []);

    // Only add food-related places if Food is explicitly in interests
    if (interests.contains('Food')) {
      candidates.addAll(categorizedPlaces['cafes'] ?? []);
    }
    
    // Add shopping only if Shopping is in interests
    if (interests.contains('Shopping')) {
      candidates.addAll(categorizedPlaces['shopping'] ?? []);
    }

    // Filter by time of day appropriateness and remove used places
    candidates = candidates.where((place) {
      // Skip if already used
      if (usedPlaces.contains(_getPlaceKey(place))) {
        return false;
      }
      
      switch (timeOfDay) {
        case 'morning':
          // Morning is perfect for attractions, parks, religious sites
          return place.tourismType != 'nightclub' && place.amenityType != 'nightclub';
        case 'afternoon':
          // Afternoon is good for most attractions and some entertainment
          return true;
        case 'evening':
          // Evening is good for viewpoints, entertainment, but not museums
          return place.tourismType != 'museum' && place.amenityType != 'cafe';
        default:
          return true;
      }
    }).toList();

    // Filter by budget if provided
    if (availableBudget != null) {
      candidates = candidates.where((place) => _getPlaceCost(place) <= availableBudget!).toList();
    }

    if (candidates.isEmpty) return null;

    // Get curated keywords for better scoring (famous places)
    final curatedKeywords = _getCuratedKeywords(destination);
    
    // Sort candidates by score (famous places get higher scores)
    candidates.sort((a, b) {
      // Prioritize attractions over other types
      final aIsAttraction = a.tourismType != null || 
                           a.additionalTags.containsKey('natural') ||
                           a.additionalTags.containsKey('historic') ||
                           a.additionalTags.containsKey('heritage');
      final bIsAttraction = b.tourismType != null || 
                           b.additionalTags.containsKey('natural') ||
                           b.additionalTags.containsKey('historic') ||
                           b.additionalTags.containsKey('heritage');
      
      if (aIsAttraction && !bIsAttraction) return -1;
      if (!aIsAttraction && bIsAttraction) return 1;
      
      // If both are attractions, score them by fame/popularity
      if (aIsAttraction && bIsAttraction) {
        final scoreA = _scorePlace(a, curatedKeywords);
        final scoreB = _scorePlace(b, curatedKeywords);
        return scoreB.compareTo(scoreA); // Higher score first
      }
      
      // For non-attractions, prefer those with ratings
      if (a.rating != null && b.rating == null) return -1;
      if (a.rating == null && b.rating != null) return 1;
      if (a.rating != null && b.rating != null) {
        return b.rating!.compareTo(a.rating!);
      }
      
      return 0;
    });

    // Select from top candidates (prioritize highest-scored famous attractions)
    // Take top 10 instead of 5, but prefer top 3 (more likely to be famous)
    final topCandidates = candidates.take(10).toList();
    if (topCandidates.length <= 3) {
      return topCandidates[random.nextInt(topCandidates.length)];
    }
    // 70% chance to pick from top 3 (most famous), 30% from rest
    if (random.nextDouble() < 0.7) {
      return topCandidates[random.nextInt(3)];
    } else {
      return topCandidates[3 + random.nextInt(topCandidates.length - 3)];
    }
  }

  PlaceDetails? _selectRestaurant(
    Map<String, List<PlaceDetails>> categorizedPlaces,
    int day, {
    bool isDinner = false,
    Set<String>? usedPlaces,
    BudgetLevel budgetLevel = BudgetLevel.moderate,
  }) {
    final restaurants = categorizedPlaces['restaurants'] ?? [];
    final cafes = categorizedPlaces['cafes'] ?? [];
    final bars = categorizedPlaces['bars'] ?? [];

    List<PlaceDetails> candidates = [];
    
    if (isDinner) {
      candidates.addAll(restaurants);
      candidates.addAll(bars);
    } else {
      candidates.addAll(restaurants);
      candidates.addAll(cafes);
    }

    // Filter out used places
    if (usedPlaces != null) {
      candidates = candidates.where((place) => !usedPlaces.contains(_getPlaceKey(place))).toList();
    }

    if (candidates.isEmpty) return null;

    final random = Random();
    final selected = candidates[random.nextInt(candidates.length)];
    
    return selected;
  }

  String _generateDayDescription(int day, List<Activity> activities) {
    final activityTypes = activities.map((a) => a.placeDetails?.category).toSet();
    final types = activityTypes.join(', ');
    return 'Day $day features a mix of $types, carefully selected to give you the best experience of the local culture and attractions.';
  }

  String _generateSummary(String destination, int duration, List<String> interests) {
    final interestText = interests.isEmpty ? 'diverse experiences' : interests.join(', ');
    return 'A $duration-day adventure in $destination featuring $interestText. This itinerary includes carefully selected attractions, dining experiences, and activities to make your trip memorable.';
  }

  double _calculateDayCost(List<Activity> activities) {
    double total = 0;
    for (final activity in activities) {
      if (activity.cost != null && activity.cost != 'Free') {
        // Extract numeric value from cost string (e.g., "₹500-1500 per person" -> 1000)
        final costText = activity.cost!.replaceAll(RegExp(r'[^\d-]'), '');
        final parts = costText.split('-');
        if (parts.length == 2) {
          final min = double.tryParse(parts[0]) ?? 0;
          final max = double.tryParse(parts[1]) ?? 0;
          total += (min + max) / 2; // Average cost
        } else if (parts.length == 1) {
          total += double.tryParse(parts[0]) ?? 0;
        }
      }
    }
    return total;
  }

  // Enhanced cost calculation with more realistic pricing
  double _calculateRealisticCost(List<Activity> activities, int travelers) {
    double total = 0;
    for (final activity in activities) {
      if (activity.cost != null && activity.cost != 'Free') {
        // Extract numeric value from cost string
        final costText = activity.cost!.replaceAll(RegExp(r'[^\d-]'), '');
        final parts = costText.split('-');
        if (parts.length == 2) {
          final min = double.tryParse(parts[0]) ?? 0;
          final max = double.tryParse(parts[1]) ?? 0;
          final avgCost = (min + max) / 2;
          total += avgCost * travelers; // Multiply by number of travelers
        } else if (parts.length == 1) {
          final cost = double.tryParse(parts[0]) ?? 0;
          total += cost * travelers;
        }
      }
    }
    return total;
  }

  // Get cost for a single place
  double _getPlaceCost(PlaceDetails place) {
    final costString = _estimatePlaceCost(place);
    if (costString == 'Free') return 0;
    
    final costText = costString.replaceAll(RegExp(r'[^\d-]'), '');
    final parts = costText.split('-');
    if (parts.length == 2) {
      final min = double.tryParse(parts[0]) ?? 0;
      final max = double.tryParse(parts[1]) ?? 0;
      return (min + max) / 2; // Average cost
    } else if (parts.length == 1) {
      return double.tryParse(parts[0]) ?? 0;
    }
    return 0;
  }

  // Estimate cost for a place (copied from Activity class)
  String _estimatePlaceCost(PlaceDetails place) {
    // Check for tourism type first (attractions)
    switch (place.tourismType) {
      case 'museum':
        return '₹50-200 per person';
      case 'gallery':
        return '₹30-150 per person';
      case 'zoo':
        return '₹100-300 per person';
      case 'theme_park':
        return '₹500-2000 per person';
      case 'attraction':
        return _estimateAttractionCost(place);
      case 'monument':
        return '₹20-100 per person';
      case 'memorial':
        return 'Free';
      case 'artwork':
        return 'Free';
      case 'viewpoint':
        return 'Free';
      case 'information':
        return 'Free';
      default:
        break;
    }

    // Check for amenity type
    switch (place.amenityType) {
      case 'restaurant':
        return '₹500-1500 per person';
      case 'cafe':
        return '₹200-500 per person';
      case 'bar':
        return '₹300-800 per person';
      case 'fast_food':
        return '₹100-300 per person';
      case 'hotel':
        return '₹2000-8000 per night';
      case 'hostel':
        return '₹500-2000 per night';
      case 'guest_house':
        return '₹1000-4000 per night';
      default:
        return 'Free';
    }
  }

  String _estimateAttractionCost(PlaceDetails place) {
    final name = place.name.toLowerCase();
    
    // Famous attractions with known entry fees
    if (name.contains('fort') || name.contains('palace') || name.contains('castle')) {
      return '₹50-200 per person';
    }
    if (name.contains('temple') || name.contains('church') || name.contains('mosque')) {
      return 'Free';
    }
    if (name.contains('beach')) {
      return 'Free';
    }
    if (name.contains('park') || name.contains('garden')) {
      return '₹20-50 per person';
    }
    if (name.contains('falls') || name.contains('waterfall')) {
      return '₹30-100 per person';
    }
    if (name.contains('hill') || name.contains('mountain') || name.contains('peak')) {
      return '₹50-150 per person';
    }
    if (name.contains('lake') || name.contains('river')) {
      return 'Free';
    }
    
    // Default for attractions
    return '₹50-200 per person';
  }

  // Generate transportation activities for the day
  List<Activity> _generateTransportationActivities(String? transportation, int travelers, int day, BudgetLevel budgetLevel) {
    final activities = <Activity>[];
    
    if (transportation == null) return activities;
    
    switch (transportation.toLowerCase()) {
      case 'public transport':
        final transportCost = _getBudgetAppropriateTransportCost(budgetLevel, transportation);
        activities.add(Activity(
          time: 'Throughout the day',
          title: 'Public Transport',
          description: 'Use local buses, metro, and auto-rickshaws for getting around the city',
          icon: Icons.directions_bus,
          estimatedDuration: 'As needed',
          cost: transportCost,
        ));
        break;
        
      case 'rental car':
        final transportCost = _getBudgetAppropriateTransportCost(budgetLevel, transportation);
        activities.add(Activity(
          time: 'Throughout the day',
          title: 'Rental Car',
          description: 'Self-drive rental car for convenient city exploration',
          icon: Icons.directions_car,
          estimatedDuration: 'Full day',
          cost: transportCost,
        ));
        break;
        
      case 'bike sharing':
        final transportCost = _getBudgetAppropriateTransportCost(budgetLevel, transportation);
        activities.add(Activity(
          time: 'Throughout the day',
          title: 'Bike Sharing',
          description: 'Use bike sharing services for eco-friendly city exploration',
          icon: Icons.pedal_bike,
          estimatedDuration: 'As needed',
          cost: transportCost,
        ));
        break;
        
      default:
        // Default to public transport
        final transportCost = _getBudgetAppropriateTransportCost(budgetLevel, transportation);
        activities.add(Activity(
          time: 'Throughout the day',
          title: 'Local Transport',
          description: 'Use local transportation options for city travel',
          icon: Icons.directions_transit,
          estimatedDuration: 'As needed',
          cost: transportCost,
        ));
    }
    
    return activities;
  }

  // Calculate transportation cost for budget filtering
  double _getTransportationCost(String? transportation, int travelers) {
    if (transportation == null) return 0;
    
    switch (transportation.toLowerCase()) {
      case 'public transport':
        return 300.0 * travelers; // Average daily cost per person
      case 'rental car':
        return 2000.0; // Daily rental cost (not per person)
      case 'bike sharing':
        return 200.0; // Daily bike sharing cost (not per person)
      default:
        return 350.0 * travelers; // Default transport cost per person
    }
  }

  double? _calculateTotalCost(List<DayPlan> dayPlans) {
    double total = 0;
    for (final day in dayPlans) {
      if (day.totalEstimatedCost != null) {
        total += day.totalEstimatedCost!;
      }
    }
    return total > 0 ? total : null;
  }

  // Calculate budget-aware day cost based on user's budget level
  double _calculateBudgetAwareDayCost(List<Activity> activities, int travelers, BudgetLevel budgetLevel) {
    double dayCost = 0;
    
    for (final activity in activities) {
      if (activity.cost != null) {
        // Parse cost from string (e.g., "₹200-400 per person")
        final costMatch = RegExp(r'₹(\d+)-(\d+)').firstMatch(activity.cost!);
        if (costMatch != null) {
          final minCost = double.parse(costMatch.group(1)!);
          final maxCost = double.parse(costMatch.group(2)!);
          
          // Use budget-appropriate cost
          double activityCost;
          switch (budgetLevel) {
            case BudgetLevel.budget:
              activityCost = minCost; // Use minimum cost for budget travelers
              break;
            case BudgetLevel.moderate:
              activityCost = (minCost + maxCost) / 2; // Use average cost
              break;
            case BudgetLevel.luxury:
              activityCost = maxCost; // Use maximum cost for luxury travelers
              break;
          }
          
          dayCost += activityCost * travelers;
        }
      }
    }
    
    return dayCost;
  }

  // Calculate dynamic budget-aware day cost that scales to user's budget
  double _calculateDynamicBudgetDayCost(List<Activity> activities, int travelers, double userBudget, int totalDays) {
    // Calculate target daily budget
    final targetDailyBudget = userBudget / totalDays;
    
    // Calculate base cost from activities
    double baseDayCost = 0;
    for (final activity in activities) {
      if (activity.cost != null) {
        final costMatch = RegExp(r'₹(\d+)-(\d+)').firstMatch(activity.cost!);
        if (costMatch != null) {
          final minCost = double.parse(costMatch.group(1)!);
          final maxCost = double.parse(costMatch.group(2)!);
          final avgCost = (minCost + maxCost) / 2;
          baseDayCost += avgCost * travelers;
        }
      }
    }
    
    // If no base cost, use a reasonable default
    if (baseDayCost == 0) {
      baseDayCost = 2000.0 * travelers; // Default ₹2000 per person per day
    }
    
    // Add some variation to make each day different (±20% variation)
    final random = Random();
    final variation = 0.8 + (random.nextDouble() * 0.4); // 0.8 to 1.2 multiplier
    final variedBaseCost = baseDayCost * variation;
    
    // Scale the cost to match user's budget
    final scaleFactor = targetDailyBudget / baseDayCost;
    final scaledDayCost = variedBaseCost * scaleFactor;
    
    // Ensure minimum reasonable cost
    final minDailyCost = 500.0 * travelers; // Minimum ₹500 per person per day
    return scaledDayCost > minDailyCost ? scaledDayCost : minDailyCost;
  }

  // Calculate budget-aware total cost based on user's budget level
  double? _calculateBudgetAwareTotalCost(List<DayPlan> dayPlans, int travelers, BudgetLevel budgetLevel) {
    double totalCost = 0;
    
    for (final dayPlan in dayPlans) {
      totalCost += dayPlan.totalEstimatedCost ?? 0;
    }
    
    return totalCost > 0 ? totalCost : null;
  }

  // Ensure total cost matches user budget exactly
  void _adjustDayCostsToMatchBudget(List<DayPlan> dayPlans, double userBudget) {
    if (dayPlans.isEmpty) return;
    
    // Calculate current total
    double currentTotal = 0;
    for (final dayPlan in dayPlans) {
      currentTotal += dayPlan.totalEstimatedCost ?? 0;
    }
    
    if (currentTotal == 0) return;
    
    // Calculate adjustment factor
    final adjustmentFactor = userBudget / currentTotal;
    
    // Create new DayPlan objects with adjusted costs
    for (int i = 0; i < dayPlans.length; i++) {
      final dayPlan = dayPlans[i];
      final adjustedCost = (dayPlan.totalEstimatedCost ?? 0) * adjustmentFactor;
      
      // Create new DayPlan with adjusted cost
      dayPlans[i] = DayPlan(
        dayTitle: dayPlan.dayTitle,
        description: dayPlan.description,
        activities: dayPlan.activities,
        totalEstimatedCost: adjustedCost,
      );
    }
  }

  // Fallback itinerary when external APIs fail
  Itinerary _generateFallbackItinerary(String destination, int durationInDays, List<String> interests, int travelers, {DateTime? startDate, DateTime? endDate}) {
    print('Generating fallback itinerary for $destination');
    
    final dayPlans = <DayPlan>[];
    
    for (int day = 1; day <= durationInDays; day++) {
      final activities = <Activity>[];
      
      // Morning activity
      activities.add(Activity(
        time: '9:00 AM',
        title: 'Explore Local Attractions',
        description: 'Visit popular landmarks and cultural sites in $destination',
        icon: Icons.place_outlined,
        estimatedDuration: '2-3 hours',
        cost: 'Free',
      ));
      
      // Lunch
      activities.add(Activity(
        time: '12:30 PM',
        title: 'Local Cuisine Experience',
        description: 'Enjoy authentic local food and flavors',
        icon: Icons.restaurant_outlined,
        estimatedDuration: '1-2 hours',
        cost: '₹300-800 per person',
      ));
      
      // Afternoon activity
      activities.add(Activity(
        time: '2:30 PM',
        title: 'Cultural Exploration',
        description: 'Discover museums, galleries, or historical sites',
        icon: Icons.museum_outlined,
        estimatedDuration: '2-3 hours',
        cost: '₹100-500 per person',
      ));
      
      // Evening activity
      activities.add(Activity(
        time: '5:30 PM',
        title: 'Scenic Views & Relaxation',
        description: 'Visit viewpoints, parks, or waterfront areas',
        icon: Icons.visibility_outlined,
        estimatedDuration: '1-2 hours',
        cost: 'Free',
      ));
      
      // Dinner
      activities.add(Activity(
        time: '8:00 PM',
        title: 'Evening Dining',
        description: 'Experience local restaurants and nightlife',
        icon: Icons.local_dining_outlined,
        estimatedDuration: '1-2 hours',
        cost: '₹500-1500 per person',
      ));
      
      dayPlans.add(DayPlan(
        dayTitle: 'Day $day',
        description: 'A day filled with cultural experiences and local attractions in $destination',
        activities: activities,
        totalEstimatedCost: 2000.0, // Estimated daily cost
      ));
    }
    
    return Itinerary(
      destination: destination,
      title: 'Your Adventure in $destination',
      dayPlans: dayPlans,
      summary: 'A $durationInDays-day adventure in $destination featuring ${interests.isEmpty ? 'diverse experiences' : interests.join(', ')}. This itinerary includes carefully selected attractions, dining experiences, and activities to make your trip memorable.',
      totalEstimatedCost: 2000.0 * durationInDays,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
