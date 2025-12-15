import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/hotel_transport_model.dart';

class HotelTransportService {
  static const String _userAgent = 'TripGenie/1.0 (Flutter App)';
  static const int _maxResults = 100; // Increased from 50 to 100

  /// Fetch hotels/accommodations near a destination
  Future<List<HotelSuggestion>> fetchHotels({
    required String destination,
    required double centerLat,
    required double centerLon,
    HotelTransportFilters? filters,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Create bounding box (approximately 30km radius for more results)
      const double radius = 0.27; // ~30km in degrees
      final bbox = '${centerLat - radius},${centerLon - radius},${centerLat + radius},${centerLon + radius}';

      final overpassQuery = r'''
        [out:json][timeout:25];
        (
          // Tourism-tagged accommodations (expanded list)
          node["tourism"~"^(hotel|hostel|guest_house|resort|apartment|motel|bed_and_breakfast|chalet|camp_site|caravan_site)$"]["name"]($bbox);
          way["tourism"~"^(hotel|hostel|guest_house|resort|apartment|motel|bed_and_breakfast|chalet|camp_site|caravan_site)$"]["name"]($bbox);
          relation["tourism"~"^(hotel|hostel|guest_house|resort|apartment|motel|bed_and_breakfast|chalet|camp_site|caravan_site)$"]["name"]($bbox);
          
          // Amenity-tagged accommodations (some POIs only use amenity)
          node["amenity"~"^(hotel|guest_house|hostel)$"]["name"]($bbox);
          way["amenity"~"^(hotel|guest_house|hostel)$"]["name"]($bbox);
          relation["amenity"~"^(hotel|guest_house|hostel)$"]["name"]($bbox);
          
          // Also include places with tourism tag even without name (we'll use fallback names)
          node["tourism"~"^(hotel|hostel|guest_house|resort|apartment|motel|bed_and_breakfast)$"]($bbox);
          way["tourism"~"^(hotel|hostel|guest_house|resort|apartment|motel|bed_and_breakfast)$"]($bbox);
        );
        out center meta;
      '''.replaceAll(r'$bbox', bbox);

      final overpassUrl = Uri.parse('https://overpass-api.de/api/interpreter');
      final response = await http.post(
        overpassUrl,
        body: {'data': overpassQuery},
        headers: {'User-Agent': _userAgent},
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw Exception('Request timeout - please try again');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch hotels. Status: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final elements = data['elements'] as List;

      // Convert to HotelSuggestion objects
      final hotels = elements
          .map((element) {
            final hotel = HotelSuggestion.fromOsmElement(element, centerLat, centerLon);
            // Check availability based on dates if provided
            bool isAvailable = hotel.isAvailable;
            if (startDate != null && endDate != null) {
              isAvailable = _checkHotelAvailability(hotel, startDate, endDate);
            }
            
            // If unnamed, try to create a meaningful name from tags
            if (hotel.name == 'Unnamed Hotel') {
              final tags = element['tags'] as Map<String, dynamic>? ?? {};
              final tourismType = tags['tourism']?.toString() ?? tags['amenity']?.toString() ?? 'hotel';
              final hotelType = tourismType.replaceAll('_', ' ').split(' ').map((w) => 
                w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1)
              ).join(' ');
              return HotelSuggestion(
                id: hotel.id,
                name: '$hotelType ${hotel.id.substring(0, 6)}',
                description: hotel.description,
                address: hotel.address,
                phone: hotel.phone,
                website: hotel.website,
                lat: hotel.lat,
                lon: hotel.lon,
                rating: hotel.rating,
                pricePerNight: hotel.pricePerNight,
                hotelType: hotel.hotelType,
                imageUrl: hotel.imageUrl,
                distanceFromCenter: hotel.distanceFromCenter,
                facilities: hotel.facilities,
                isAvailable: isAvailable,
                additionalInfo: hotel.additionalInfo,
              );
            }
            // Update availability for named hotels
            return HotelSuggestion(
              id: hotel.id,
              name: hotel.name,
              description: hotel.description,
              address: hotel.address,
              phone: hotel.phone,
              website: hotel.website,
              lat: hotel.lat,
              lon: hotel.lon,
              rating: hotel.rating,
              pricePerNight: hotel.pricePerNight,
              hotelType: hotel.hotelType,
              imageUrl: hotel.imageUrl,
              distanceFromCenter: hotel.distanceFromCenter,
              facilities: hotel.facilities,
              isAvailable: isAvailable,
              additionalInfo: hotel.additionalInfo,
            );
          })
          .toList();

      // Deduplicate by name + coordinates (rounded)
      final hotelsDeduped = _dedupeHotels(hotels);

      // Apply filters
      var filteredHotels = hotelsDeduped;
      if (filters != null) {
        filteredHotels = _filterHotels(hotelsDeduped, filters);
      }

      // Sort by rating (if available) or distance
      filteredHotels.sort((a, b) {
        // Prioritize hotels with ratings
        if (a.rating != null && b.rating == null) return -1;
        if (a.rating == null && b.rating != null) return 1;
        if (a.rating != null && b.rating != null) {
          final ratingDiff = b.rating!.compareTo(a.rating!);
          if (ratingDiff != 0) return ratingDiff;
        }
        // Then by distance
        if (a.distanceFromCenter != null && b.distanceFromCenter != null) {
          return a.distanceFromCenter!.compareTo(b.distanceFromCenter!);
        }
        return 0;
      });

      return filteredHotels.take(_maxResults).toList();
    } catch (e) {
      print('Error fetching hotels: $e');
      // Return fallback hotels if API fails
      return _generateFallbackHotels(destination, centerLat, centerLon, startDate, endDate);
    }
  }

  /// Fetch transport options near a destination
  Future<List<TransportSuggestion>> fetchTransportOptions({
    required String destination,
    required double centerLat,
    required double centerLon,
    HotelTransportFilters? filters,
  }) async {
    try {
      // Create bounding box (30km radius)
      const double radius = 0.27; // ~30km in degrees
      final bbox = '${centerLat - radius},${centerLon - radius},${centerLat + radius},${centerLon + radius}';

      final overpassQuery = r'''
        [out:json][timeout:25];
        (
          // Bus, taxi, car rental
          node["amenity"~"^(bus_station|taxi|car_rental)$"]["name"]($bbox);
          way["amenity"~"^(bus_station|taxi|car_rental)$"]["name"]($bbox);
          relation["amenity"~"^(bus_station|taxi|car_rental)$"]["name"]($bbox);
          
          // Public transport hubs
          node["public_transport"]["name"]($bbox);
          way["public_transport"]["name"]($bbox);
          relation["public_transport"]["name"]($bbox);
          
          // Train / metro
          node["railway"="station"]["name"]($bbox);
          way["railway"="station"]["name"]($bbox);
          relation["railway"="station"]["name"]($bbox);
          
          // Airports and ferry terminals
          node["aeroway"="aerodrome"]["name"]($bbox);
          way["aeroway"="aerodrome"]["name"]($bbox);
          relation["aeroway"="aerodrome"]["name"]($bbox);
          
          node["amenity"="ferry_terminal"]["name"]($bbox);
          way["amenity"="ferry_terminal"]["name"]($bbox);
          relation["amenity"="ferry_terminal"]["name"]($bbox);
        );
        out center meta;
      '''.replaceAll(r'$bbox', bbox);

      final overpassUrl = Uri.parse('https://overpass-api.de/api/interpreter');
      final response = await http.post(
        overpassUrl,
        body: {'data': overpassQuery},
        headers: {'User-Agent': _userAgent},
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw Exception('Request timeout - please try again');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch transport options. Status: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final elements = data['elements'] as List;

      // Convert to TransportSuggestion objects and estimate costs
      final transportOptionsRaw = elements
          .map((element) {
            final transport = TransportSuggestion.fromOsmElement(element, centerLat, centerLon);
            // Create meaningful name if unnamed
            String finalName = transport.name;
            if (finalName == 'Unnamed Place' || finalName.isEmpty) {
              final tags = element['tags'] as Map<String, dynamic>? ?? {};
              final type = tags['amenity'] ?? tags['public_transport'] ?? tags['railway'] ?? tags['aeroway'] ?? 'transport';
              final typeStr = type.toString().replaceAll('_', ' ').split(' ').map((w) => 
                w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1)
              ).join(' ');
              finalName = '$typeStr Station';
            }
            // Create new transport with estimated cost
            final estimatedCost = _estimateTransportCost(transport.type);
            return TransportSuggestion(
              id: transport.id,
              name: finalName,
              type: transport.type,
              description: transport.description,
              address: transport.address,
              phone: transport.phone,
              website: transport.website,
              lat: transport.lat,
              lon: transport.lon,
              estimatedCost: estimatedCost,
              distanceFromCenter: transport.distanceFromCenter,
              operatingHours: transport.operatingHours,
              facilities: transport.facilities,
              routeInfo: transport.routeInfo,
              isAvailable: transport.isAvailable,
              additionalInfo: transport.additionalInfo,
            );
          })
          .whereType<TransportSuggestion>()
          .toList();

      // Deduplicate transport entries by name + coordinates (rounded)
      final transportOptions = _dedupeTransport(transportOptionsRaw);

      // Apply filters
      var filteredTransport = transportOptions;
      if (filters != null) {
        filteredTransport = _filterTransport(transportOptions, filters);
      }

      // Sort by distance first, then cost
      filteredTransport.sort((a, b) {
        if (a.distanceFromCenter != null && b.distanceFromCenter != null) {
          return a.distanceFromCenter!.compareTo(b.distanceFromCenter!);
        }
        if (a.distanceFromCenter != null) return -1;
        if (b.distanceFromCenter != null) return 1;
        if (a.estimatedCost != null && b.estimatedCost != null) {
          return a.estimatedCost!.compareTo(b.estimatedCost!);
        }
        return 0;
      });

      return filteredTransport.take(_maxResults).toList();
    } catch (e) {
      print('Error fetching transport options: $e');
      // Return fallback transport options if API fails
      return _generateFallbackTransport(destination, centerLat, centerLon);
    }
  }

  List<HotelSuggestion> _dedupeHotels(List<HotelSuggestion> hotels) {
    final map = <String, HotelSuggestion>{};
    for (final h in hotels) {
      final key = _placeKey(h.name, h.lat, h.lon);
      map[key] = h;
    }
    return map.values.toList();
  }

  List<TransportSuggestion> _dedupeTransport(List<TransportSuggestion> transport) {
    // Aggressive deduplication: group by normalized name + type + rounded coords
    final map = <String, TransportSuggestion>{};

    for (final t in transport) {
      final normalizedName = t.name.toLowerCase().trim();
      final normalizedType = t.type.toLowerCase().trim();

      // If coordinates exist, round to ~100m to catch near-duplicates
      String key;
      if (t.lat != null && t.lon != null) {
        key =
            '${normalizedName}_${normalizedType}_${t.lat!.toStringAsFixed(3)}_${t.lon!.toStringAsFixed(3)}';
      } else {
        // No coordinates – fall back to name + type only
        key = '${normalizedName}_${normalizedType}_no_coords';
      }

      // Keep the option closer to center when duplicates collide
      if (map.containsKey(key)) {
        final existing = map[key]!;
        final existingDist = existing.distanceFromCenter ?? double.infinity;
        final newDist = t.distanceFromCenter ?? double.infinity;
        if (newDist < existingDist) {
          map[key] = t;
        }
      } else {
        map[key] = t;
      }
    }

    return map.values.toList();
  }

  String _placeKey(String name, double lat, double lon) {
    // More precise key for hotels (4 decimal places = ~11m precision)
    return '${name.toLowerCase().trim()}_${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}';
  }

  /// Filter hotels based on criteria
  List<HotelSuggestion> _filterHotels(List<HotelSuggestion> hotels, HotelTransportFilters filters) {
    return hotels.where((hotel) {
      // Budget filter
      if (filters.minBudget != null && hotel.pricePerNight != null) {
        if (hotel.pricePerNight! < filters.minBudget!) return false;
      }
      if (filters.maxBudget != null && hotel.pricePerNight != null) {
        if (hotel.pricePerNight! > filters.maxBudget!) return false;
      }

      // Rating filter
      if (filters.minRating != null && hotel.rating != null) {
        if (hotel.rating! < filters.minRating!) return false;
      }

      // Distance filter
      if (filters.maxDistance != null && hotel.distanceFromCenter != null) {
        if (hotel.distanceFromCenter! > filters.maxDistance!) return false;
      }

      // Type filter
      if (filters.hotelTypes != null && filters.hotelTypes!.isNotEmpty) {
        if (hotel.hotelType == null || !filters.hotelTypes!.contains(hotel.hotelType)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Filter transport options based on criteria
  List<TransportSuggestion> _filterTransport(List<TransportSuggestion> transport, HotelTransportFilters filters) {
    return transport.where((t) {
      // Budget filter
      if (filters.minBudget != null && t.estimatedCost != null) {
        if (t.estimatedCost! < filters.minBudget!) return false;
      }
      if (filters.maxBudget != null && t.estimatedCost != null) {
        if (t.estimatedCost! > filters.maxBudget!) return false;
      }

      // Distance filter
      if (filters.maxDistance != null && t.distanceFromCenter != null) {
        if (t.distanceFromCenter! > filters.maxDistance!) return false;
      }

      // Type filter
      if (filters.transportTypes != null && filters.transportTypes!.isNotEmpty) {
        if (!filters.transportTypes!.contains(t.type)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Estimate transport cost based on type
  double? _estimateTransportCost(String type) {
    switch (type.toLowerCase()) {
      case 'bus_station':
      case 'bus':
      case 'public_transport':
        return 50.0; // Average bus fare
      case 'train_station':
      case 'railway':
      case 'station':
        return 100.0; // Average train fare
      case 'taxi':
        return 200.0; // Average taxi fare
      case 'rental_car':
      case 'car_rental':
        return 1500.0; // Daily rental
      case 'bike_sharing':
      case 'bicycle_rental':
        return 100.0; // Daily rental
      case 'airport':
      case 'aerodrome':
        return 500.0; // Airport transfer
      case 'ferry_terminal':
      case 'ferry':
        return 150.0; // Ferry fare
      default:
        return 150.0; // Default estimate
    }
  }

  /// Check hotel availability based on selected dates
  /// Simulates availability checking (in real app, this would query booking API)
  bool _checkHotelAvailability(HotelSuggestion hotel, DateTime startDate, DateTime endDate) {
    // Calculate number of nights
    final nights = endDate.difference(startDate).inDays;
    
    // Use hotel ID as seed for consistent availability simulation
    final hash = hotel.id.hashCode.abs();
    final availabilitySeed = hash % 100;
    
    // Simulate availability logic:
    // - Higher rated hotels (4.5+) are more likely to be booked (70% available)
    // - Mid-range hotels (4.0-4.5) have good availability (85% available)
    // - Budget hotels have high availability (90% available)
    // - Longer stays reduce availability slightly
    // - Weekend dates reduce availability
    
    double availabilityChance = 0.9; // Default 90% available
    
    if (hotel.rating != null) {
      if (hotel.rating! >= 4.5) {
        availabilityChance = 0.70; // 70% available for luxury hotels
      } else if (hotel.rating! >= 4.0) {
        availabilityChance = 0.85; // 85% available for mid-range
      } else {
        availabilityChance = 0.90; // 90% available for budget
      }
    }
    
    // Reduce availability for longer stays
    if (nights > 5) {
      availabilityChance *= 0.9;
    }
    if (nights > 10) {
      availabilityChance *= 0.85;
    }
    
    // Check if dates include weekends (Friday, Saturday, Sunday)
    bool hasWeekend = false;
    for (var i = 0; i <= nights; i++) {
      final date = startDate.add(Duration(days: i));
      final weekday = date.weekday;
      if (weekday == 5 || weekday == 6 || weekday == 7) { // Fri, Sat, Sun
        hasWeekend = true;
        break;
      }
    }
    
    if (hasWeekend) {
      availabilityChance *= 0.85; // 15% reduction for weekend bookings
    }
    
    // Check if dates are in peak season (Dec-Feb, May-Jul in India)
    final month = startDate.month;
    bool isPeakSeason = (month >= 12 || month <= 2) || (month >= 5 && month <= 7);
    if (isPeakSeason) {
      availabilityChance *= 0.80; // 20% reduction during peak season
    }
    
    // Use hash to determine if this specific hotel is available
    final isAvailable = (availabilitySeed / 100.0) < availabilityChance;
    
    return isAvailable;
  }

  /// Generate fallback hotels when API fails
  List<HotelSuggestion> _generateFallbackHotels(String destination, double lat, double lon, DateTime? startDate, DateTime? endDate) {
    final fallbackHotels = [
      HotelSuggestion(
        id: 'fallback_1',
        name: 'Budget Hotel in $destination',
        description: 'Affordable accommodation option in the city center',
        address: '45 Main Street, City Center, $destination',
        phone: '+91-9876543210',
        lat: lat + 0.01,
        lon: lon + 0.01,
        rating: 3.5,
        pricePerNight: 1500,
        hotelType: 'hotel',
        distanceFromCenter: 1.2,
        facilities: ['WiFi', 'Parking', 'Air Conditioning', 'Breakfast', 'Laundry', 'Tour Desk'],
        isAvailable: true,
      ),
      HotelSuggestion(
        id: 'fallback_2',
        name: 'Mid-Range Hotel in $destination',
        description: 'Comfortable hotel with good amenities',
        address: '123 Downtown Avenue, Downtown, $destination',
        phone: '+91-8765432109',
        lat: lat + 0.015,
        lon: lon + 0.015,
        rating: 4.0,
        pricePerNight: 3500,
        hotelType: 'hotel',
        distanceFromCenter: 2.5,
        facilities: ['WiFi', 'Parking', 'Breakfast', 'Restaurant', 'Air Conditioning', 'Elevator', 'Room Service', 'Currency Exchange', 'Gym'],
        isAvailable: true,
      ),
      HotelSuggestion(
        id: 'fallback_3',
        name: 'Luxury Resort in $destination',
        description: 'Premium accommodation with excellent facilities',
        address: '500 Premium Road, Premium Area, $destination',
        phone: '+91-7654321098',
        lat: lat + 0.02,
        lon: lon + 0.02,
        rating: 4.5,
        pricePerNight: 8000,
        hotelType: 'resort',
        distanceFromCenter: 5.0,
        facilities: ['WiFi', 'Parking', 'Breakfast', 'Swimming Pool', 'Gym', 'Spa', 'Restaurant', 'Bar', 'Air Conditioning', 'Room Service', 'Concierge', 'Business Center', 'Airport Shuttle', 'Kids Play Area'],
        isAvailable: true,
      ),
      HotelSuggestion(
        id: 'fallback_4',
        name: 'Guest House in $destination',
        description: 'Cozy guest house with homely atmosphere',
        address: '78 Residential Lane, Residential Area, $destination',
        phone: '+91-6543210987',
        lat: lat - 0.012,
        lon: lon + 0.008,
        rating: 3.8,
        pricePerNight: 1200,
        hotelType: 'guest_house',
        distanceFromCenter: 1.8,
        facilities: ['WiFi', 'Parking', 'Breakfast', 'Garden', 'Terrace', 'Air Conditioning'],
        isAvailable: true,
      ),
      HotelSuggestion(
        id: 'fallback_5',
        name: 'Backpacker Hostel in $destination',
        description: 'Budget-friendly hostel for travelers',
        address: '12 Tourist Street, Tourist Area, $destination',
        phone: '+91-5432109876',
        lat: lat + 0.008,
        lon: lon - 0.01,
        rating: 3.2,
        pricePerNight: 800,
        hotelType: 'hostel',
        distanceFromCenter: 1.5,
        facilities: ['WiFi', 'Laundry', 'Tour Desk', 'Library', 'Common Kitchen', 'Air Conditioning'],
        isAvailable: true,
      ),
      HotelSuggestion(
        id: 'fallback_6',
        name: 'Business Hotel in $destination',
        description: 'Modern hotel ideal for business travelers',
        address: '200 Commercial Boulevard, Commercial District, $destination',
        phone: '+91-4321098765',
        lat: lat - 0.018,
        lon: lon - 0.015,
        rating: 4.2,
        pricePerNight: 4500,
        hotelType: 'hotel',
        distanceFromCenter: 3.2,
        facilities: ['WiFi', 'Parking', 'Breakfast', 'Restaurant', 'Business Center', 'Air Conditioning', 'Elevator', 'Room Service', 'Conference Room', '24/7 Reception'],
        isAvailable: true,
      ),
      HotelSuggestion(
        id: 'fallback_7',
        name: 'Boutique Hotel in $destination',
        description: 'Charming boutique hotel with unique character',
        address: '89 Heritage Road, Historic Area, $destination',
        phone: '+91-3210987654',
        lat: lat + 0.022,
        lon: lon + 0.018,
        rating: 4.3,
        pricePerNight: 5500,
        hotelType: 'hotel',
        distanceFromCenter: 4.5,
        facilities: ['WiFi', 'Parking', 'Breakfast', 'Restaurant', 'Bar', 'Air Conditioning', 'Concierge', 'Gift Shop', 'Terrace', 'Spa'],
        isAvailable: true,
      ),
      HotelSuggestion(
        id: 'fallback_8',
        name: 'Family Resort in $destination',
        description: 'Family-friendly resort with activities for all ages',
        address: '350 Resort Way, Outskirts, $destination',
        phone: '+91-2109876543',
        lat: lat - 0.025,
        lon: lon + 0.022,
        rating: 4.1,
        pricePerNight: 6000,
        hotelType: 'resort',
        distanceFromCenter: 6.0,
        facilities: ['WiFi', 'Parking', 'Breakfast', 'Swimming Pool', 'Gym', 'Restaurant', 'Bar', 'Air Conditioning', 'Pet Friendly', 'Kids Play Area', 'BBQ Facilities', 'Garden'],
        isAvailable: true,
      ),
    ];
    
    // Check availability for all fallback hotels if dates are provided
    if (startDate != null && endDate != null) {
      return fallbackHotels.map((hotel) {
        final isAvailable = _checkHotelAvailability(hotel, startDate, endDate);
        return HotelSuggestion(
          id: hotel.id,
          name: hotel.name,
          description: hotel.description,
          address: hotel.address,
          phone: hotel.phone,
          website: hotel.website,
          lat: hotel.lat,
          lon: hotel.lon,
          rating: hotel.rating,
          pricePerNight: hotel.pricePerNight,
          hotelType: hotel.hotelType,
          imageUrl: hotel.imageUrl,
          distanceFromCenter: hotel.distanceFromCenter,
          facilities: hotel.facilities,
          isAvailable: isAvailable,
          additionalInfo: hotel.additionalInfo,
        );
      }).toList();
    }
    
    return fallbackHotels;
  }

  /// Generate fallback transport options when API fails
  List<TransportSuggestion> _generateFallbackTransport(String destination, double lat, double lon) {
    return [
      TransportSuggestion(
        id: 'fallback_transport_1',
        name: 'Bus Station',
        type: 'bus_station',
        description: 'Main bus station for local and intercity travel',
        address: '45 Transport Road, City Center, $destination',
        phone: '+91-9876543210',
        lat: lat + 0.005,
        lon: lon + 0.005,
        estimatedCost: 50.0,
        distanceFromCenter: 0.5,
        operatingHours: 'Daily: 5:00 AM - 11:00 PM',
        facilities: ['Ticket Counter', 'WiFi', 'Air Conditioning', 'Waiting Room', 'Food Court', 'ATM'],
        routeInfo: 'Multiple routes to major cities',
        isAvailable: true,
      ),
      TransportSuggestion(
        id: 'fallback_transport_2',
        name: 'Train Station',
        type: 'train_station',
        description: 'Railway station for train travel',
        address: '123 Railway Road, Downtown, $destination',
        phone: '+91-8765432109',
        lat: lat + 0.01,
        lon: lon + 0.01,
        estimatedCost: 100.0,
        distanceFromCenter: 1.0,
        operatingHours: 'Daily: 5:00 AM - 11:00 PM',
        facilities: ['Ticket Counter', 'WiFi', 'Air Conditioning', 'Waiting Room', 'Food Court', 'Parking'],
        routeInfo: 'Connects to major cities across India',
        isAvailable: true,
      ),
      TransportSuggestion(
        id: 'fallback_transport_3',
        name: 'Car Rental Service',
        type: 'car_rental',
        description: 'Car rental for self-drive options',
        address: '78 Rental Street, City Center, $destination',
        phone: '+91-7654321098',
        lat: lat + 0.008,
        lon: lon + 0.008,
        estimatedCost: 1500.0,
        distanceFromCenter: 0.8,
        operatingHours: '24/7',
        facilities: ['24/7 Service', 'Online Booking', 'AC Vehicles', 'Multiple Car Options'],
        routeInfo: 'Self-drive & chauffeur options available',
        isAvailable: true,
      ),
      TransportSuggestion(
        id: 'fallback_transport_4',
        name: 'Taxi Service',
        type: 'taxi',
        description: 'Reliable taxi service for local and intercity travel',
        address: '12 Taxi Stand, City Center, $destination',
        phone: '+91-6543210987',
        lat: lat - 0.005,
        lon: lon + 0.003,
        estimatedCost: 200.0,
        distanceFromCenter: 0.6,
        operatingHours: '24/7',
        facilities: ['24/7 Service', 'Online Booking', 'AC Vehicles', 'Cash & Card Payment'],
        routeInfo: 'Local & intercity services',
        isAvailable: true,
      ),
      TransportSuggestion(
        id: 'fallback_transport_5',
        name: 'Airport',
        type: 'airport',
        description: 'International airport with domestic and international flights',
        address: 'Airport Road, Outskirts, $destination',
        phone: '+91-5432109876',
        lat: lat - 0.02,
        lon: lon + 0.015,
        estimatedCost: 500.0,
        distanceFromCenter: 8.0,
        operatingHours: '24/7',
        facilities: ['WiFi', 'Air Conditioning', 'Parking', 'Food Court', 'ATM', 'Lounge', 'Duty Free', 'Waiting Room'],
        routeInfo: 'Domestic & International flights',
        isAvailable: true,
      ),
    ];
  }
}

