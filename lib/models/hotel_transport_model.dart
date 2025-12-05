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
        final match = RegExp(r'(\\d{3,6})').firstMatch(val.toString());
        if (match != null) {
          pricePerNight = double.tryParse(match.group(1)!);
          break;
        }
      }
    }

    final name = _getBestEnglishName(tags);

    return HotelSuggestion(
      id: '${lat.toStringAsFixed(6)}_${lon.toStringAsFixed(6)}',
      name: name,
      description: tags['description:en'] ?? tags['description'] ?? tags['note:en'] ?? tags['note'],
      address: tags['addr:full'] ?? tags['addr:street'] ?? tags['addr:housenumber'],
      phone: tags['phone'],
      website: tags['website'],
      lat: lat,
      lon: lon,
      rating: rating,
      pricePerNight: pricePerNight,
      hotelType: tags['tourism'] ?? tags['amenity'],
      imageUrl: tags['image'] ?? tags['photo'],
      distanceFromCenter: distance,
      additionalInfo: tags.map((k, v) => MapEntry(k, v.toString())),
    );
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
    this.additionalInfo = const {},
  });

  factory TransportSuggestion.fromOsmElement(Map<String, dynamic> element, double centerLat, double centerLon) {
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final lat = element['lat']?.toDouble() ?? element['center']?['lat']?.toDouble();
    final lon = element['lon']?.toDouble() ?? element['center']?['lon']?.toDouble();

    double? distance;
    if (lat != null && lon != null) {
      distance = HotelSuggestion.fromOsmElement(element, centerLat, centerLon).distanceFromCenter;
    }

    String name = _getBestEnglishName(tags);
    if (name == 'Unnamed Place') {
      final type = tags['amenity'] ?? tags['public_transport'] ?? tags['highway'] ?? 'transport';
      name = '${type.toString().replaceAll('_', ' ')} Station';
    }

    return TransportSuggestion(
      id: '${lat ?? 0}_${lon ?? 0}',
      name: name,
      type: tags['amenity'] ?? tags['public_transport'] ?? tags['highway'] ?? 'transport',
      description: tags['description:en'] ?? tags['description'],
      address: tags['addr:full'] ?? tags['addr:street'],
      phone: tags['phone'],
      website: tags['website'],
      lat: lat,
      lon: lon,
      estimatedCost: null,
      distanceFromCenter: distance,
      additionalInfo: tags.map((k, v) => MapEntry(k, v.toString())),
    );
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
        return Icons.directions_bus;
      case 'train_station':
      case 'railway':
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

