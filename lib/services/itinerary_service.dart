
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
    try {
      print('Starting itinerary generation for: $destination');
      
      // Step 1: Geocode the destination
      final geocodeData = await _geocodeDestination(destination);
      if (geocodeData == null) {
        print('No geocoding data found, trying fallback...');
        return _generateFallbackItinerary(destination, durationInDays, interests, travelers);
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
        return _generateFallbackItinerary(destination, durationInDays, interests, travelers);
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
        return _generateFallbackItinerary(destination, durationInDays, interests, travelers);
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
          return _generateFallbackItinerary(destination, durationInDays, interests, travelers);
        } catch (fallbackError) {
          print('Fallback also failed: $fallbackError');
          throw Exception('Network connection error. Please check your internet connection and try again.');
        }
      } else {
        throw Exception('Failed to generate itinerary: ${e.toString()}');
      }
    }
  }

  /// Public method to get destination coordinates
  Future<Map<String, double>?> getDestinationCoordinates(String destination) async {
    try {
      final geocodeData = await _geocodeDestination(destination);
      if (geocodeData == null) return null;
      
      final lat = double.tryParse(geocodeData['lat']?.toString() ?? '');
      final lon = double.tryParse(geocodeData['lon']?.toString() ?? '');
      
      if (lat == null || lon == null) return null;
      
      return {'lat': lat, 'lon': lon};
    } catch (e) {
      print('Error getting coordinates: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _geocodeDestination(String destination) async {
    try {
      final geocodeUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(destination)}&format=json&limit=1&addressdetails=1&accept-language=en'
      );
      
      print('Geocoding request for: $destination');
      print('URL: $geocodeUrl');
      
      final response = await http.get(geocodeUrl, headers: {'User-Agent': _userAgent}).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Geocoding timeout - please try again');
        },
      );

      print('Geocoding response status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('Geocoding failed with status: ${response.statusCode}');
        print('Response body: ${response.body}');
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
      print('Geocoding error: $e');
      rethrow; // Re-throw to get more specific error info
    }
  }

  Future<List<PlaceDetails>> _fetchPlaces(String bbox, List<String> interests) async {
    try {
      // Optimized Overpass query - reduced complexity for better performance
      final overpassQuery = r'''
        [out:json][timeout:15];
        (
          // Tourism attractions (most important)
          node["tourism"]["name"]($bbox);
          way["tourism"]["name"]($bbox);
          
          // Natural attractions
          node["natural"~"^(beach|waterfall|peak|hill)$"]["name"]($bbox);
          way["natural"~"^(beach|waterfall|peak|hill)$"]["name"]($bbox);
          
          // Parks and gardens
          node["leisure"~"^(park|garden)$"]["name"]($bbox);
          way["leisure"~"^(park|garden)$"]["name"]($bbox);
          
          // Places of worship
          node["amenity"="place_of_worship"]["name"]($bbox);
          way["amenity"="place_of_worship"]["name"]($bbox);
          
          // Food & drink (limited to essential types)
          node["amenity"~"^(restaurant|cafe|bar)$"]["name"]($bbox);
          way["amenity"~"^(restaurant|cafe|bar)$"]["name"]($bbox);
          
          // Entertainment (limited)
          node["amenity"~"^(cinema|theatre|arts_centre)$"]["name"]($bbox);
          way["amenity"~"^(cinema|theatre|arts_centre)$"]["name"]($bbox);
        );
        out center meta;
      ''';

      // Replace $bbox placeholder with actual bbox value
      final finalQuery = overpassQuery.replaceAll(r'$bbox', bbox);
      
      print('Fetching places for bbox: $bbox');
      
      final overpassUrl = Uri.parse('https://overpass-api.de/api/interpreter');
      final response = await http.post(
        overpassUrl, 
        body: {'data': finalQuery},
        headers: {'User-Agent': _userAgent}
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw Exception('Request timeout - please try again');
        },
      );

      print('Overpass API response status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('Overpass API failed with status: ${response.statusCode}');
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
      print('Error fetching places: $e');
      rethrow; // Re-throw to get more specific error info
    }
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

      // Natural sights and heritage – treat as attractions
      final isBeach = natural == 'beach';
      final isWaterfall = natural == 'waterfall' || (water == 'waterfall');
      final isFort = (historic == 'ruins' || historic == 'castle' || manMade == 'fortification');
      final isHeritage = heritage != null;
      if (isBeach || isWaterfall || isFort || isHeritage) {
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
    
    // Goa
    if (key.contains('goa')) {
      return [
        'baga beach', 'calangute beach', 'anjuna beach', 'candolim beach', 'palolem beach',
        'miramar beach', 'arambol beach', 'vagator beach', 'benaulim beach', 'colva beach',
        'chapora fort', 'aguada fort', 'reis magos fort', 'terekhol fort', 'corjuem fort',
        'dudhsagar falls', 'basilica of bom jesus', 'se cathedral', 'shri mangeshi temple',
        'divar island', 'old goa', 'spice plantation', 'dona paula', 'butterfly beach',
        'grand island', 'bondla wildlife sanctuary', 'mollem national park', 'anjuna flea market',
        'mapusa market', 'panjim church', 'santa monica church', 'shri shantadurga temple',
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
    
    // Karnataka
    if (key.contains('mysore') || key.contains('mysuru')) {
      return [
        'mysore palace', 'chamundi hills', 'chamundi temple', 'brindavan gardens',
        'srirangapatna', 'daria daulat bagh', 'gumbaz', 'rani lakshmi bai memorial',
        'mysore zoo', 'rail museum', 'folklore museum', 'regional museum of natural history',
        'st philomena cathedral', 'jaganmohan palace', 'karanji lake', 'kukkarahalli lake',
        'bandipur national park', 'nagarhole national park', 'coorg', 'ooty',
        'shivanasamudra falls', 'talakadu', 'somnathpur temple', 'belur halebidu',
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
    
    // Beaches and water bodies
    if (natural == 'beach' || place.additionalTags['place'] == 'beach') score += 40;
    if (natural == 'waterfall' || water == 'waterfall') score += 35;
    if (natural == 'lake' || natural == 'river' || natural == 'coastline') score += 25;
    
    // Hills and mountains
    if (natural == 'peak' || natural == 'hill' || natural == 'ridge') score += 30;
    if (natural == 'volcano' || natural == 'cliff') score += 25;
    
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

    // Enhanced boost for famous place keywords
    if (name.contains('fort') || name.contains('palace') || name.contains('temple') || 
        name.contains('beach') || name.contains('falls') || name.contains('hill') ||
        name.contains('museum') || name.contains('gallery') || name.contains('park') ||
        name.contains('lake') || name.contains('garden') || name.contains('valley') ||
        name.contains('national park') || name.contains('wildlife') || name.contains('sanctuary') ||
        name.contains('cave') || name.contains('mountain') || name.contains('peak') ||
        name.contains('island') || name.contains('river') || name.contains('dam') ||
        name.contains('zoo') || name.contains('aquarium') || name.contains('botanical') ||
        name.contains('heritage') || name.contains('monument') || name.contains('memorial')) {
      score += 20; // Increased from 15
    }

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
  ) {
    final random = Random();
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
    if (budgetAmount != null) {
      final dailyBudget = budgetAmount / durationInDays; // Approximate daily budget
      final transportCost = _getTransportationCost(transportation, travelers);
      final availableBudget = dailyBudget - transportCost; // Reserve budget for transport
      
      candidates = candidates.where((place) {
        final cost = _getPlaceCost(place);
        return cost <= availableBudget;
      }).toList();
    }

    if (candidates.isEmpty) return null;

    // Sort candidates by priority (attractions first, then others)
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
      
      // If both are attractions or both are not, maintain original order
      return 0;
    });

    // Select from top candidates (prioritize attractions)
    final topCandidates = candidates.take(5).toList(); // Take top 5 candidates
    final selected = topCandidates[random.nextInt(topCandidates.length)];
    
    return selected;
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
  Itinerary _generateFallbackItinerary(String destination, int durationInDays, List<String> interests, int travelers) {
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
    );
  }
}
