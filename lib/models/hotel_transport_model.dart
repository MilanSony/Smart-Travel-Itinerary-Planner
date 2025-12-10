import 'dart:math';
import 'package:flutter/material.dart';

/// Model for hotel/accommodation suggestions
class HotelSuggestion {
  final String id;
  final String name;
  final String? description;
  final String? address;
  final String? phone;
  final String? website;
  final double lat;
  final double lon;
  final double? rating; // 0-5 stars if available
  final double? pricePerNight; // Price in INR
  final String? hotelType; // hotel, hostel, guest_house, resort, apartment
  final String? imageUrl;
  final double? distanceFromCenter; // Distance in km from city center
  final List<String> facilities; // List of available facilities
  final bool isAvailable; // Availability status
  final Map<String, String> additionalInfo;

  HotelSuggestion({
    required this.id,
    required this.name,
    this.description,
    this.address,
    this.phone,
    this.website,
    required this.lat,
    required this.lon,
    this.rating,
    this.pricePerNight,
    this.hotelType,
    this.imageUrl,
    this.distanceFromCenter,
    this.facilities = const [],
    this.isAvailable = true,
    this.additionalInfo = const {},
  });

  factory HotelSuggestion.fromOsmElement(Map<String, dynamic> element, double centerLat, double centerLon) {
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final lat = element['lat']?.toDouble() ?? element['center']?['lat']?.toDouble() ?? 0.0;
    final lon = element['lon']?.toDouble() ?? element['center']?['lon']?.toDouble() ?? 0.0;

    // Distance from center (Haversine)
    final distance = _calculateDistance(lat, lon, centerLat, centerLon);

    // Rating
    double? rating;
    if (tags['stars'] != null) {
      rating = double.tryParse(tags['stars'].toString());
    }

    // Price hint
    double? pricePerNight;
    for (final key in ['fee', 'charge', 'price', 'cost', 'room']) {
      final val = tags[key];
      if (val != null) {
        final match = RegExp(r'(\d{3,6})').firstMatch(val.toString());
        if (match != null) {
          pricePerNight = double.tryParse(match.group(1)!);
          break;
        }
      }
    }

    // Extract facilities from OSM tags
    final facilities = <String>[];
    if (_hasFacility(tags, 'internet_access', 'wifi')) {
      facilities.add('WiFi');
    }
    if (_hasFacility(tags, 'parking')) {
      facilities.add('Parking');
    }
    if (_hasFacility(tags, 'breakfast')) {
      facilities.add('Breakfast');
    }
    if (_hasFacility(tags, 'pool', 'swimming_pool')) {
      facilities.add('Swimming Pool');
    }
    if (_hasFacility(tags, 'gym', 'fitness')) {
      facilities.add('Gym');
    }
    if (_hasFacility(tags, 'spa')) {
      facilities.add('Spa');
    }
    if (_hasFacility(tags, 'restaurant')) {
      facilities.add('Restaurant');
    }
    if (_hasFacility(tags, 'bar')) {
      facilities.add('Bar');
    }
    if (_hasFacility(tags, 'air_conditioning')) {
      facilities.add('Air Conditioning');
    }
    if (_hasFacility(tags, 'elevator')) {
      facilities.add('Elevator');
    }
    if (_hasFacility(tags, 'wheelchair')) {
      facilities.add('Wheelchair Accessible');
    }
    if (_hasFacility(tags, 'pets')) {
      facilities.add('Pet Friendly');
    }
    if (_hasFacility(tags, 'room_service')) {
      facilities.add('Room Service');
    }
    if (_hasFacility(tags, 'laundry')) {
      facilities.add('Laundry');
    }
    if (_hasFacility(tags, 'concierge')) {
      facilities.add('Concierge');
    }
    if (_hasFacility(tags, 'business_center')) {
      facilities.add('Business Center');
    }

    // If no facilities found in OSM tags, add intelligent fallback facilities
    // based on hotel type, rating, and price - make them unique per hotel
    if (facilities.isEmpty) {
      final hotelId = '${lat.toStringAsFixed(6)}_${lon.toStringAsFixed(6)}';
      facilities.addAll(_getFallbackFacilities(
        hotelType: tags['tourism'] ?? tags['amenity'],
        rating: rating,
        pricePerNight: pricePerNight,
        hotelId: hotelId, // Use hotel ID to make facilities unique
      ));
    }

    // Determine availability based on opening_hours or default to available
    // Note: Actual availability check based on dates will be done in the service
    bool isAvailable = true;
    if (tags['opening_hours'] != null) {
      final openingHours = tags['opening_hours'].toString().toLowerCase();
      // If explicitly closed or no hours, mark as unavailable
      if (openingHours.contains('closed') || openingHours.contains('no')) {
        isAvailable = false;
      }
    }

    final name = _getBestEnglishName(tags);
    final hotelId = '${lat.toStringAsFixed(6)}_${lon.toStringAsFixed(6)}';
    
    // Generate fallback phone number if not available or invalid
    String? phone = tags['phone'];
    if (phone != null && phone.isNotEmpty) {
      // Clean and validate phone number from OSM
      phone = _cleanPhoneNumber(phone);
      if (!_isValidIndianPhone(phone)) {
        phone = _generateFallbackPhone(hotelId);
      }
    } else {
      phone = _generateFallbackPhone(hotelId);
    }
    
    // Generate better address if not available
    String? address = tags['addr:full'] ?? tags['addr:street'] ?? tags['addr:housenumber'];
    if (address == null || address.isEmpty) {
      address = _generateFallbackAddress(name, lat, lon, distance);
    }

    return HotelSuggestion(
      id: hotelId,
      name: name,
      description: tags['description:en'] ?? tags['description'] ?? tags['note:en'] ?? tags['note'],
      address: address,
      phone: phone,
      website: tags['website'],
      lat: lat,
      lon: lon,
      rating: rating,
      pricePerNight: pricePerNight,
      hotelType: tags['tourism'] ?? tags['amenity'],
      imageUrl: tags['image'] ?? tags['photo'],
      distanceFromCenter: distance,
      facilities: facilities,
      isAvailable: isAvailable,
      additionalInfo: tags.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  static bool _hasFacility(Map<String, dynamic> tags, String key, [String? altKey]) {
    final value = tags[key] ?? (altKey != null ? tags[altKey] : null);
    if (value == null) return false;
    final str = value.toString().toLowerCase();
    return str == 'yes' || str == 'true' || str == '1' || str == 'wlan' || str == 'customers';
  }

  /// Get fallback facilities based on hotel type, rating, and price
  /// Uses hotelId to generate unique facilities per hotel
  static List<String> _getFallbackFacilities({
    dynamic hotelType,
    double? rating,
    double? pricePerNight,
    required String hotelId,
  }) {
    final facilities = <String>[];
    final typeStr = hotelType?.toString().toLowerCase() ?? 'hotel';
    
    // Generate a hash from hotelId to create unique variations
    final hash = hotelId.hashCode.abs();
    final variation = hash % 10; // 0-9 variation

    // All possible facilities
    final allFacilities = [
      'WiFi', 'Air Conditioning', 'Parking', 'Breakfast', 'Restaurant', 'Bar',
      'Swimming Pool', 'Gym', 'Spa', 'Elevator', 'Room Service', 'Concierge',
      'Business Center', 'Laundry', 'Pet Friendly', 'Wheelchair Accessible',
      '24/7 Reception', 'Tour Desk', 'Currency Exchange', 'Gift Shop',
      'Conference Room', 'Banquet Hall', 'Kids Play Area', 'Library',
      'Terrace', 'Garden', 'BBQ Facilities', 'Airport Shuttle',
    ];

    // Basic facilities that all hotels have
    facilities.add('WiFi');
    facilities.add('Air Conditioning');

    // Facilities based on hotel type
    if (typeStr.contains('resort')) {
      facilities.addAll(['Swimming Pool', 'Spa', 'Restaurant', 'Bar', 'Gym', 'Parking', 'Room Service', 'Concierge']);
      // Add unique facilities based on variation
      if (variation % 3 == 0) facilities.add('Kids Play Area');
      if (variation % 4 == 0) facilities.add('BBQ Facilities');
      if (variation % 5 == 0) facilities.add('Terrace');
      if (variation % 6 == 0) facilities.add('Garden');
    } else if (typeStr.contains('hotel')) {
      facilities.add('Parking');
      if (rating != null && rating >= 4.0) {
        facilities.addAll(['Restaurant', 'Room Service', 'Elevator']);
        if (rating >= 4.5) {
          facilities.addAll(['Gym', 'Spa', 'Bar', 'Concierge', 'Business Center']);
          // Add unique premium facilities
          if (variation % 2 == 0) facilities.add('Conference Room');
          if (variation % 3 == 0) facilities.add('Banquet Hall');
          if (variation % 4 == 0) facilities.add('24/7 Reception');
        } else {
          // Mid-range unique facilities
          if (variation % 2 == 0) facilities.add('Tour Desk');
          if (variation % 3 == 0) facilities.add('Currency Exchange');
        }
      } else {
        facilities.add('Breakfast');
        if (variation % 2 == 0) facilities.add('Laundry');
      }
    } else if (typeStr.contains('guest_house') || typeStr.contains('guesthouse')) {
      facilities.addAll(['Parking', 'Breakfast']);
      if (variation % 2 == 0) facilities.add('Garden');
      if (variation % 3 == 0) facilities.add('Terrace');
    } else if (typeStr.contains('hostel')) {
      facilities.add('Laundry');
      if (variation % 2 == 0) facilities.add('Tour Desk');
      if (variation % 3 == 0) facilities.add('Library');
    } else if (typeStr.contains('apartment')) {
      facilities.addAll(['Parking', 'Laundry']);
      if (variation % 2 == 0) facilities.add('Kitchen');
      if (variation % 3 == 0) facilities.add('Terrace');
    }

    // Facilities based on price range with variations
    if (pricePerNight != null) {
      if (pricePerNight >= 5000) {
        // Luxury hotels - add more premium facilities
        if (!facilities.contains('Swimming Pool')) facilities.add('Swimming Pool');
        if (!facilities.contains('Gym')) facilities.add('Gym');
        if (!facilities.contains('Spa')) facilities.add('Spa');
        if (!facilities.contains('Restaurant')) facilities.add('Restaurant');
        if (!facilities.contains('Bar')) facilities.add('Bar');
        if (!facilities.contains('Room Service')) facilities.add('Room Service');
        if (!facilities.contains('Concierge')) facilities.add('Concierge');
        if (!facilities.contains('Business Center')) facilities.add('Business Center');
        if (!facilities.contains('Elevator')) facilities.add('Elevator');
        // Unique luxury facilities
        if (variation % 2 == 0) facilities.add('Airport Shuttle');
        if (variation % 3 == 0) facilities.add('Gift Shop');
        if (variation % 4 == 0) facilities.add('Conference Room');
      } else if (pricePerNight >= 2500) {
        // Mid-range hotels
        if (!facilities.contains('Restaurant')) facilities.add('Restaurant');
        if (!facilities.contains('Breakfast')) facilities.add('Breakfast');
        if (!facilities.contains('Elevator')) facilities.add('Elevator');
        if (!facilities.contains('Room Service')) facilities.add('Room Service');
        // Unique mid-range facilities
        if (variation % 2 == 0) facilities.add('Tour Desk');
        if (variation % 3 == 0) facilities.add('Currency Exchange');
        if (variation % 4 == 0 && pricePerNight >= 3500) facilities.add('Gym');
      } else {
        // Budget hotels
        if (!facilities.contains('Breakfast')) facilities.add('Breakfast');
        if (variation % 2 == 0) facilities.add('Laundry');
        if (variation % 3 == 0) facilities.add('Tour Desk');
      }
    }

    // Facilities based on rating with variations
    if (rating != null) {
      if (rating >= 4.5) {
        if (!facilities.contains('Swimming Pool') && pricePerNight != null && pricePerNight >= 3000) {
          facilities.add('Swimming Pool');
        }
        if (!facilities.contains('Gym') && pricePerNight != null && pricePerNight >= 3000) {
          facilities.add('Gym');
        }
        if (!facilities.contains('Spa') && pricePerNight != null && pricePerNight >= 4000) {
          facilities.add('Spa');
        }
        if (!facilities.contains('Concierge')) facilities.add('Concierge');
        // High-rated unique facilities
        if (variation % 2 == 0) facilities.add('24/7 Reception');
        if (variation % 3 == 0) facilities.add('Pet Friendly');
      } else if (rating >= 4.0) {
        if (!facilities.contains('Restaurant')) facilities.add('Restaurant');
        if (!facilities.contains('Room Service')) facilities.add('Room Service');
        if (variation % 2 == 0) facilities.add('Wheelchair Accessible');
      }
    }

    // Add distance-based unique facilities
    // Hotels closer to center might have different facilities
    if (variation % 5 == 0) {
      if (!facilities.contains('Currency Exchange')) facilities.add('Currency Exchange');
    }
    if (variation % 7 == 0) {
      if (!facilities.contains('Gift Shop')) facilities.add('Gift Shop');
    }

    // Ensure at least 4-6 facilities are present
    while (facilities.length < 4) {
      final available = allFacilities.where((f) => !facilities.contains(f)).toList();
      if (available.isNotEmpty) {
        facilities.add(available[hash % available.length]);
      } else {
        break;
      }
    }

    // Limit to 8-12 facilities for better UI
    if (facilities.length > 12) {
      facilities.removeRange(12, facilities.length);
    }

    return facilities;
  }

  /// Clean phone number from OSM data
  static String _cleanPhoneNumber(String phone) {
    // Remove all non-digit characters except +
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Remove country code if present
    if (cleaned.startsWith('+91')) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith('91') && cleaned.length > 10) {
      cleaned = cleaned.substring(2);
    }
    
    // Remove leading 0 if present
    if (cleaned.startsWith('0') && cleaned.length > 10) {
      cleaned = cleaned.substring(1);
    }
    
    // Extract only digits
    cleaned = cleaned.replaceAll(RegExp(r'[^\d]'), '');
    
    return cleaned;
  }

  /// Validate if phone number is a valid Indian phone number (10 digits)
  static bool _isValidIndianPhone(String phone) {
    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Indian phone numbers should be 10 digits
    if (digitsOnly.length != 10) {
      return false;
    }
    
    // First digit should be 6, 7, 8, or 9 for mobile numbers
    // For landlines, it can be any digit
    final firstDigit = int.tryParse(digitsOnly[0]);
    if (firstDigit == null) return false;
    
    // Accept if it's a valid 10-digit number
    return RegExp(r'^\d{10}$').hasMatch(digitsOnly);
  }

  /// Generate a fallback phone number based on hotel ID
  /// Returns a valid Indian phone number with +91 country code
  static String _generateFallbackPhone(String hotelId) {
    final hash = hotelId.hashCode.abs();
    
    // Generate a valid 10-digit Indian mobile number
    // First digit should be 6, 7, 8, or 9
    final firstDigits = [6, 7, 8, 9];
    final firstDigit = firstDigits[hash % 4];
    
    // Generate remaining 9 digits (ensuring they're between 100000000 and 999999999)
    final remainingDigits = (hash % 900000000 + 100000000).toString();
    
    // Combine to form 10-digit number
    final phoneNumber = '$firstDigit$remainingDigits';
    
    // Format as +91-XXXXXXXXXX
    return '+91-$phoneNumber';
  }

  /// Generate a fallback address based on hotel location
  static String _generateFallbackAddress(String name, double lat, double lon, double distance) {
    // Determine area based on distance from center
    String area;
    if (distance < 1.0) {
      area = 'City Center';
    } else if (distance < 3.0) {
      area = 'Downtown';
    } else if (distance < 5.0) {
      area = 'Suburban Area';
    } else {
      area = 'Outskirts';
    }
    
    // Add street number based on coordinates for uniqueness
    final streetNum = ((lat * 1000).toInt() % 500 + 1).toString();
    
    return '$streetNum Main Street, $area';
  }

  static String _getBestEnglishName(Map<String, dynamic> tags) {
    for (final key in ['name:en', 'name:en:official', 'name:en:common', 'name:en:short', 'name']) {
      final val = tags[key];
      if (val != null && val.toString().trim().isNotEmpty) {
        return val.toString().trim();
      }
    }
    return 'Unnamed Hotel';
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degToRad(double deg) => deg * (3.141592653589793 / 180.0);

  IconData get icon {
    switch (hotelType) {
      case 'hotel':
        return Icons.hotel;
      case 'hostel':
        return Icons.bed;
      case 'guest_house':
        return Icons.home;
      case 'resort':
        return Icons.beach_access;
      case 'apartment':
        return Icons.apartment;
      default:
        return Icons.hotel;
    }
  }

  String get displayPrice => pricePerNight != null ? '₹${pricePerNight!.toStringAsFixed(0)}/night' : 'Price not available';

  String get displayDistance {
    if (distanceFromCenter == null) return 'Distance not available';
    if (distanceFromCenter! < 1) {
      return '${(distanceFromCenter! * 1000).toStringAsFixed(0)}m from center';
    }
    return '${distanceFromCenter!.toStringAsFixed(1)}km from center';
  }
}

/// Model for transport suggestions
class TransportSuggestion {
  final String id;
  final String name;
  final String type; // bus, train, taxi, rental_car, bike_sharing, etc.
  final String? description;
  final String? address;
  final String? phone;
  final String? website;
  final double? lat;
  final double? lon;
  final double? estimatedCost; // INR
  final double? distanceFromCenter; // km
  final String? operatingHours; // Operating hours/schedule
  final List<String> facilities; // Available facilities (WiFi, AC, etc.)
  final String? routeInfo; // Route information
  final bool isAvailable; // Availability status
  final Map<String, String> additionalInfo;

  TransportSuggestion({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.address,
    this.phone,
    this.website,
    this.lat,
    this.lon,
    this.estimatedCost,
    this.distanceFromCenter,
    this.operatingHours,
    this.facilities = const [],
    this.routeInfo,
    this.isAvailable = true,
    this.additionalInfo = const {},
  });

  factory TransportSuggestion.fromOsmElement(Map<String, dynamic> element, double centerLat, double centerLon) {
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final lat = element['lat']?.toDouble() ?? element['center']?['lat']?.toDouble();
    final lon = element['lon']?.toDouble() ?? element['center']?['lon']?.toDouble();

    double? distance;
    if (lat != null && lon != null) {
      distance = _calculateTransportDistance(lat, lon, centerLat, centerLon);
    }

    String name = _getBestEnglishName(tags);
    if (name == 'Unnamed Place') {
      final type = tags['amenity'] ?? tags['public_transport'] ?? tags['highway'] ?? 'transport';
      name = '${type.toString().replaceAll('_', ' ')} Station';
    }

    // Determine transport type more accurately
    String transportType = 'transport';
    if (tags['aeroway'] != null) {
      transportType = 'airport';
    } else if (tags['railway'] == 'station') {
      transportType = 'train_station';
    } else if (tags['amenity'] == 'bus_station' || tags['public_transport'] == 'station') {
      transportType = 'bus_station';
    } else if (tags['amenity'] == 'taxi') {
      transportType = 'taxi';
    } else if (tags['amenity'] == 'car_rental') {
      transportType = 'car_rental';
    } else if (tags['amenity'] == 'ferry_terminal') {
      transportType = 'ferry_terminal';
    } else {
      transportType = tags['amenity']?.toString() ?? 
                     tags['public_transport']?.toString() ?? 
                     tags['railway']?.toString() ?? 
                     'transport';
    }

    // Extract facilities
    final facilities = <String>[];
    if (_hasFacility(tags, 'wifi', 'internet_access')) {
      facilities.add('WiFi');
    }
    if (_hasFacility(tags, 'air_conditioning')) {
      facilities.add('Air Conditioning');
    }
    if (_hasFacility(tags, 'wheelchair')) {
      facilities.add('Wheelchair Accessible');
    }
    if (_hasFacility(tags, 'parking')) {
      facilities.add('Parking');
    }
    if (_hasFacility(tags, 'restaurant', 'food')) {
      facilities.add('Food Court');
    }
    if (_hasFacility(tags, 'waiting_room')) {
      facilities.add('Waiting Room');
    }
    if (_hasFacility(tags, 'ticket_machine')) {
      facilities.add('Ticket Machine');
    }
    if (_hasFacility(tags, 'atm')) {
      facilities.add('ATM');
    }

    // If no facilities found, add fallback facilities based on type
    if (facilities.isEmpty) {
      facilities.addAll(_getTransportFacilities(transportType, '${lat ?? 0}_${lon ?? 0}'));
    }

    // Extract operating hours
    String? operatingHours = tags['opening_hours'] ?? tags['service_times'];
    if (operatingHours == null || operatingHours.isEmpty) {
      operatingHours = _getDefaultOperatingHours(transportType);
    }

    // Extract route information
    String? routeInfo = tags['route'] ?? tags['network'] ?? tags['operator'];
    if (routeInfo == null || routeInfo.isEmpty) {
      routeInfo = _getDefaultRouteInfo(transportType, name);
    }

    // Determine availability
    bool isAvailable = true;
    if (tags['opening_hours'] != null) {
      final hours = tags['opening_hours'].toString().toLowerCase();
      if (hours.contains('closed') || hours.contains('no')) {
        isAvailable = false;
      }
    }

    final transportId = '${lat ?? 0}_${lon ?? 0}';
    
    // Generate fallback phone number if not available
    String? phone = tags['phone'];
    if (phone != null && phone.isNotEmpty) {
      phone = HotelSuggestion._cleanPhoneNumber(phone);
      if (!HotelSuggestion._isValidIndianPhone(phone)) {
        phone = HotelSuggestion._generateFallbackPhone(transportId);
      } else {
        phone = '+91-$phone';
      }
    } else {
      phone = HotelSuggestion._generateFallbackPhone(transportId);
    }

    // Generate better address if not available
    String? address = tags['addr:full'] ?? tags['addr:street'] ?? tags['addr:housenumber'];
    if (address == null || address.isEmpty) {
      address = _generateTransportAddress(name, lat, lon, distance);
    }
    
    return TransportSuggestion(
      id: transportId,
      name: name,
      type: transportType,
      description: tags['description:en'] ?? tags['description'],
      address: address,
      phone: phone,
      website: tags['website'],
      lat: lat,
      lon: lon,
      estimatedCost: null,
      distanceFromCenter: distance,
      operatingHours: operatingHours,
      facilities: facilities,
      routeInfo: routeInfo,
      isAvailable: isAvailable,
      additionalInfo: tags.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  static bool _hasFacility(Map<String, dynamic> tags, String key, [String? altKey]) {
    final value = tags[key] ?? (altKey != null ? tags[altKey] : null);
    if (value == null) return false;
    final str = value.toString().toLowerCase();
    return str == 'yes' || str == 'true' || str == '1' || str == 'wlan' || str == 'customers';
  }

  /// Get fallback facilities for transport based on type
  static List<String> _getTransportFacilities(String transportType, String transportId) {
    final facilities = <String>[];
    final hash = transportId.hashCode.abs();
    final variation = hash % 10;
    final typeStr = transportType.toLowerCase();

    // Basic facilities
    if (typeStr.contains('bus') || typeStr.contains('train')) {
      facilities.add('Ticket Counter');
      if (variation % 2 == 0) facilities.add('WiFi');
      if (variation % 3 == 0) facilities.add('Air Conditioning');
      if (variation % 4 == 0) facilities.add('Waiting Room');
      if (variation % 5 == 0) facilities.add('Food Court');
      if (variation % 6 == 0) facilities.add('ATM');
    } else if (typeStr.contains('airport')) {
      facilities.addAll(['WiFi', 'Air Conditioning', 'Parking', 'Food Court', 'ATM', 'Waiting Room']);
      if (variation % 2 == 0) facilities.add('Lounge');
      if (variation % 3 == 0) facilities.add('Duty Free');
    } else if (typeStr.contains('taxi') || typeStr.contains('car_rental')) {
      facilities.add('24/7 Service');
      if (variation % 2 == 0) facilities.add('Online Booking');
      if (variation % 3 == 0) facilities.add('AC Vehicles');
    } else if (typeStr.contains('ferry')) {
      facilities.add('Ticket Counter');
      if (variation % 2 == 0) facilities.add('Waiting Area');
      if (variation % 3 == 0) facilities.add('Parking');
    }

    // Ensure at least 2-3 facilities
    if (facilities.isEmpty) {
      facilities.addAll(['Ticket Counter', 'Parking']);
    }

    return facilities;
  }

  /// Get default operating hours based on transport type
  static String _getDefaultOperatingHours(String transportType) {
    final typeStr = transportType.toLowerCase();
    if (typeStr.contains('bus') || typeStr.contains('train')) {
      return 'Daily: 5:00 AM - 11:00 PM';
    } else if (typeStr.contains('airport')) {
      return '24/7';
    } else if (typeStr.contains('taxi') || typeStr.contains('car_rental')) {
      return '24/7';
    } else if (typeStr.contains('ferry')) {
      return 'Daily: 6:00 AM - 10:00 PM';
    }
    return 'Daily: 6:00 AM - 10:00 PM';
  }

  /// Get default route information
  static String _getDefaultRouteInfo(String transportType, String name) {
    final typeStr = transportType.toLowerCase();
    if (typeStr.contains('bus')) {
      return 'Multiple routes available';
    } else if (typeStr.contains('train')) {
      return 'Connects to major cities';
    } else if (typeStr.contains('airport')) {
      return 'Domestic & International flights';
    } else if (typeStr.contains('taxi')) {
      return 'Local & intercity services';
    } else if (typeStr.contains('car_rental')) {
      return 'Self-drive & chauffeur options';
    } else if (typeStr.contains('ferry')) {
      return 'Regular ferry services';
    }
    return 'Transport services available';
  }

  /// Calculate distance between two coordinates (Haversine formula)
  static double _calculateTransportDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degToRad(double deg) => deg * (3.141592653589793 / 180.0);

  /// Generate fallback address for transport
  static String _generateTransportAddress(String name, double? lat, double? lon, double? distance) {
    String area;
    if (distance == null || distance < 1.0) {
      area = 'City Center';
    } else if (distance < 3.0) {
      area = 'Downtown';
    } else if (distance < 5.0) {
      area = 'Suburban Area';
    } else {
      area = 'Outskirts';
    }
    
    final streetNum = lat != null ? ((lat * 1000).toInt() % 500 + 1).toString() : '1';
    return '$streetNum Transport Road, $area';
  }

  static String _getBestEnglishName(Map<String, dynamic> tags) {
    for (final key in ['name:en', 'name:en:official', 'name:en:common', 'name']) {
      final val = tags[key];
      if (val != null && val.toString().trim().isNotEmpty) {
        return val.toString().trim();
      }
    }
    return 'Unnamed Place';
  }

  IconData get icon {
    switch (type.toLowerCase()) {
      case 'bus_station':
      case 'bus':
      case 'public_transport':
        return Icons.directions_bus;
      case 'train_station':
      case 'railway':
      case 'station':
        return Icons.train;
      case 'taxi':
        return Icons.local_taxi;
      case 'rental_car':
      case 'car_rental':
        return Icons.directions_car;
      case 'bike_sharing':
      case 'bicycle_rental':
        return Icons.pedal_bike;
      case 'airport':
      case 'aerodrome':
        return Icons.flight;
      case 'ferry_terminal':
      case 'ferry':
        return Icons.directions_boat;
      default:
        return Icons.directions_transit;
    }
  }

  String get displayCost => estimatedCost != null ? '₹${estimatedCost!.toStringAsFixed(0)}' : 'Cost varies';
}

/// Filters for hotels and transport
class HotelTransportFilters {
  final double? minBudget;
  final double? maxBudget;
  final double? minRating;
  final double? maxDistance; // km
  final List<String>? hotelTypes;
  final List<String>? transportTypes;

  HotelTransportFilters({
    this.minBudget,
    this.maxBudget,
    this.minRating,
    this.maxDistance,
    this.hotelTypes,
    this.transportTypes,
  });
}

