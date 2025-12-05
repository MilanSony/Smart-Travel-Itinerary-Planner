import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/hotel_transport_model.dart';

class HotelTransportService {
  static const String _userAgent = 'TripGenie/1.0 (Flutter App)';
  static const int _maxResults = 50;

  /// Fetch hotels/accommodations near a destination
  Future<List<HotelSuggestion>> fetchHotels({
    required String destination,
    required double centerLat,
    required double centerLon,
    HotelTransportFilters? filters,
  }) async {
    try {
      // Create bounding box (approximately 20km radius)
      const double radius = 0.18; // ~20km in degrees
      final bbox = '${centerLat - radius},${centerLon - radius},${centerLat + radius},${centerLon + radius}';

      final overpassQuery = r'''
        [out:json][timeout:20];
        (
          // Tourism-tagged accommodations
          node["tourism"~"^(hotel|hostel|guest_house|resort|apartment)$"]["name"]($bbox);
          way["tourism"~"^(hotel|hostel|guest_house|resort|apartment)$"]["name"]($bbox);
          relation["tourism"~"^(hotel|hostel|guest_house|resort|apartment)$"]["name"]($bbox);
          
          // Amenity-tagged accommodations (some POIs only use amenity)
          node["amenity"~"^(hotel|guest_house)$"]["name"]($bbox);
          way["amenity"~"^(hotel|guest_house)$"]["name"]($bbox);
          relation["amenity"~"^(hotel|guest_house)$"]["name"]($bbox);
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
          .map((element) => HotelSuggestion.fromOsmElement(element, centerLat, centerLon))
          .where((hotel) => hotel.name != 'Unnamed Hotel')
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
      return _generateFallbackHotels(destination, centerLat, centerLon);
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
      // Create bounding box
      const double radius = 0.18; // ~20km in degrees
      final bbox = '${centerLat - radius},${centerLon - radius},${centerLat + radius},${centerLon + radius}';

      final overpassQuery = r'''
        [out:json][timeout:20];
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
            if (transport.name == 'Unnamed Place') return null;
            // Create new transport with estimated cost
            final estimatedCost = _estimateTransportCost(transport.type);
            return TransportSuggestion(
              id: transport.id,
              name: transport.name,
              type: transport.type,
              description: transport.description,
              address: transport.address,
              phone: transport.phone,
              website: transport.website,
              lat: transport.lat,
              lon: transport.lon,
              estimatedCost: estimatedCost,
              distanceFromCenter: transport.distanceFromCenter,
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
    final map = <String, TransportSuggestion>{};
    for (final t in transport) {
      final key = _placeKey(t.name, t.lat ?? 0, t.lon ?? 0);
      map[key] = t;
    }
    return map.values.toList();
  }

  String _placeKey(String name, double lat, double lon) {
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
        return 50.0; // Average bus fare
      case 'train_station':
      case 'railway':
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
        return 500.0; // Airport transfer
      default:
        return 150.0; // Default estimate
    }
  }

  /// Generate fallback hotels when API fails
  List<HotelSuggestion> _generateFallbackHotels(String destination, double lat, double lon) {
    return [
      HotelSuggestion(
        id: 'fallback_1',
        name: 'Budget Hotel in $destination',
        description: 'Affordable accommodation option in the city center',
        address: 'City Center, $destination',
        lat: lat + 0.01,
        lon: lon + 0.01,
        rating: 3.5,
        pricePerNight: 1500,
        hotelType: 'hotel',
        distanceFromCenter: 1.2,
      ),
      HotelSuggestion(
        id: 'fallback_2',
        name: 'Mid-Range Hotel in $destination',
        description: 'Comfortable hotel with good amenities',
        address: 'Downtown, $destination',
        lat: lat + 0.015,
        lon: lon + 0.015,
        rating: 4.0,
        pricePerNight: 3500,
        hotelType: 'hotel',
        distanceFromCenter: 2.5,
      ),
      HotelSuggestion(
        id: 'fallback_3',
        name: 'Luxury Resort in $destination',
        description: 'Premium accommodation with excellent facilities',
        address: 'Premium Area, $destination',
        lat: lat + 0.02,
        lon: lon + 0.02,
        rating: 4.5,
        pricePerNight: 8000,
        hotelType: 'resort',
        distanceFromCenter: 5.0,
      ),
    ];
  }

  /// Generate fallback transport options when API fails
  List<TransportSuggestion> _generateFallbackTransport(String destination, double lat, double lon) {
    return [
      TransportSuggestion(
        id: 'fallback_transport_1',
        name: 'Bus Station',
        type: 'bus_station',
        description: 'Main bus station for local and intercity travel',
        address: 'City Center, $destination',
        lat: lat + 0.005,
        lon: lon + 0.005,
        estimatedCost: 50.0,
        distanceFromCenter: 0.5,
      ),
      TransportSuggestion(
        id: 'fallback_transport_2',
        name: 'Train Station',
        type: 'train_station',
        description: 'Railway station for train travel',
        address: 'Downtown, $destination',
        lat: lat + 0.01,
        lon: lon + 0.01,
        estimatedCost: 100.0,
        distanceFromCenter: 1.0,
      ),
      TransportSuggestion(
        id: 'fallback_transport_3',
        name: 'Car Rental Service',
        type: 'car_rental',
        description: 'Car rental for self-drive options',
        address: 'City Center, $destination',
        lat: lat + 0.008,
        lon: lon + 0.008,
        estimatedCost: 1500.0,
        distanceFromCenter: 0.8,
      ),
    ];
  }
}

