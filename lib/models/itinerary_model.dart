import 'package:flutter/material.dart';

// Enhanced models for detailed place information
class PlaceDetails {
  final String name;
  final String? description;
  final String? website;
  final String? phone;
  final String? openingHours;
  final String? address;
  final String? cuisine;
  final String? tourismType;
  final String? amenityType;
  final double? rating;
  final String? imageUrl;
  final double lat;
  final double lon;
  final Map<String, String> additionalTags;

  PlaceDetails({
    required this.name,
    this.description,
    this.website,
    this.phone,
    this.openingHours,
    this.address,
    this.cuisine,
    this.tourismType,
    this.amenityType,
    this.rating,
    this.imageUrl,
    required this.lat,
    required this.lon,
    this.additionalTags = const {},
  });

  factory PlaceDetails.fromOsmElement(Map<String, dynamic> element) {
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final lat = element['lat']?.toDouble() ?? element['center']?['lat']?.toDouble() ?? 0.0;
    final lon = element['lon']?.toDouble() ?? element['center']?['lon']?.toDouble() ?? 0.0;

    // Prioritize English names, fallback to local names
    String name = _getBestEnglishName(tags);
    
    return PlaceDetails(
      name: name,
      description: tags['description:en'] ?? tags['description'] ?? tags['note:en'] ?? tags['note'],
      website: tags['website'],
      phone: tags['phone'],
      openingHours: tags['opening_hours'],
      address: tags['addr:full'] ?? tags['addr:street'],
      cuisine: tags['cuisine'],
      tourismType: tags['tourism'],
      amenityType: tags['amenity'],
      rating: _parseRating(tags['stars']),
      imageUrl: tags['image'] ?? tags['photo'],
      lat: lat,
      lon: lon,
      additionalTags: tags.map((key, value) => MapEntry(key, value.toString())),
    );
  }

  // Helper method to get the best English name
  static String _getBestEnglishName(Map<String, dynamic> tags) {
    // Priority order for English names
    final englishNameKeys = [
      'name:en',           // Official English name
      'name:en:official',   // Official English name
      'name:en:common',     // Common English name
      'name:en:short',      // Short English name
      'name:en:alt',        // Alternative English name
      'name',               // Default name (might be English)
    ];

    // Try to find an English name first
    for (final key in englishNameKeys) {
      final name = tags[key];
      if (name != null && name.toString().trim().isNotEmpty) {
        final nameStr = name.toString().trim();
        // Check if it contains only English characters and common punctuation
        if (_isEnglishText(nameStr)) {
          return nameStr;
        }
      }
    }

    // If no English name found, try the default name
    final defaultName = tags['name'];
    if (defaultName != null && defaultName.toString().trim().isNotEmpty) {
      final nameStr = defaultName.toString().trim();
      // If it looks like English, use it
      if (_isEnglishText(nameStr)) {
        return nameStr;
      }
    }

    // Fallback to any available name
    for (final key in ['name:en', 'name', 'name:local', 'name:official']) {
      final name = tags[key];
      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString().trim();
      }
    }

    return 'Unnamed Place';
  }

  // Check if text appears to be in English
  static bool _isEnglishText(String text) {
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

  static double? _parseRating(dynamic stars) {
    if (stars == null) return null;
    if (stars is num) return stars.toDouble();
    if (stars is String) return double.tryParse(stars);
    return null;
  }

  String get category {
    if (tourismType != null) return tourismType!;
    if (amenityType != null) return amenityType!;
    return 'place';
  }

  String get displayDescription {
    if (description != null && description!.isNotEmpty) {
      return description!;
    }
    
    // Generate description based on type
    switch (tourismType) {
      case 'museum':
        return 'Explore this fascinating museum showcasing local history and culture.';
      case 'gallery':
        return 'Visit this art gallery featuring contemporary and traditional works.';
      case 'zoo':
        return 'Enjoy a day at this zoo with diverse wildlife and educational exhibits.';
      case 'theme_park':
        return 'Experience thrilling rides and entertainment at this theme park.';
      case 'attraction':
        return 'Discover this popular local attraction and landmark.';
      case 'monument':
        return 'Visit this historic monument with significant cultural importance.';
      case 'memorial':
        return 'Pay respects at this memorial site of historical significance.';
      case 'artwork':
        return 'Admire this beautiful artwork and sculpture.';
      case 'viewpoint':
        return 'Take in breathtaking panoramic views from this scenic viewpoint.';
      case 'information':
        return 'Get tourist information and local recommendations here.';
      default:
        break;
    }

    switch (amenityType) {
      case 'restaurant':
        return 'Enjoy delicious ${cuisine ?? 'local'} cuisine at this restaurant.';
      case 'cafe':
        return 'Relax with coffee and light meals at this cozy cafe.';
      case 'bar':
        return 'Unwind with drinks and socialize at this local bar.';
      case 'fast_food':
        return 'Grab a quick bite at this fast food establishment.';
      case 'pub':
        return 'Experience local culture at this traditional pub.';
      case 'nightclub':
        return 'Dance the night away at this vibrant nightclub.';
      case 'hotel':
        return 'Stay comfortably at this accommodation option.';
      case 'hostel':
        return 'Budget-friendly accommodation with shared facilities.';
      case 'guest_house':
        return 'Cozy guest house offering personalized hospitality.';
      default:
        return 'Visit this interesting local place.';
    }
  }

  IconData get icon {
    switch (tourismType) {
      case 'museum':
        return Icons.museum_outlined;
      case 'gallery':
        return Icons.photo_library_outlined;
      case 'zoo':
        return Icons.pets_outlined;
      case 'theme_park':
        return Icons.attractions_outlined;
      case 'attraction':
        return Icons.place_outlined;
      case 'monument':
        return Icons.account_balance_outlined;
      case 'memorial':
        return Icons.flag_outlined;
      case 'artwork':
        return Icons.palette_outlined;
      case 'viewpoint':
        return Icons.visibility_outlined;
      case 'information':
        return Icons.info_outline;
      default:
        break;
    }

    switch (amenityType) {
      case 'restaurant':
        return Icons.restaurant_outlined;
      case 'cafe':
        return Icons.local_cafe_outlined;
      case 'bar':
        return Icons.local_bar_outlined;
      case 'fast_food':
        return Icons.fastfood_outlined;
      case 'pub':
        return Icons.sports_bar_outlined;
      case 'nightclub':
        return Icons.nightlife_outlined;
      case 'hotel':
        return Icons.hotel_outlined;
      case 'hostel':
        return Icons.bed_outlined;
      case 'guest_house':
        return Icons.home_outlined;
      default:
        return Icons.place_outlined;
    }
  }
}

class Activity {
  final String time;
  final String title;
  final String description;
  final IconData icon;
  final PlaceDetails? placeDetails;
  final String? estimatedDuration;
  final String? cost;

  Activity({
    required this.time,
    required this.title,
    required this.description,
    required this.icon,
    this.placeDetails,
    this.estimatedDuration,
    this.cost,
  });

  factory Activity.fromPlaceDetails(PlaceDetails place, String time, {String? customDescription, String? customCost}) {
    return Activity(
      time: time,
      title: place.name,
      description: customDescription ?? place.displayDescription,
      icon: place.icon,
      placeDetails: place,
      estimatedDuration: _estimateDuration(place),
      cost: customCost ?? _estimateCost(place),
    );
  }

  static String _estimateDuration(PlaceDetails place) {
    switch (place.tourismType) {
      case 'museum':
        return '2-3 hours';
      case 'gallery':
        return '1-2 hours';
      case 'zoo':
        return '3-4 hours';
      case 'theme_park':
        return '4-6 hours';
      case 'attraction':
        return '1-2 hours';
      case 'monument':
        return '30-60 minutes';
      case 'viewpoint':
        return '30-60 minutes';
      default:
        break;
    }

    switch (place.amenityType) {
      case 'restaurant':
        return '1-2 hours';
      case 'cafe':
        return '30-60 minutes';
      case 'bar':
        return '1-3 hours';
      case 'fast_food':
        return '20-40 minutes';
      default:
        return '1-2 hours';
    }
  }

  static String _estimateCost(PlaceDetails place) {
    // Prefer explicit OSM fee/charge/ticket tags when available
    final tags = place.additionalTags;
    final feeTag = tags['fee']?.toLowerCase();
    final chargeTag = tags['charge']?.toLowerCase();
    final entranceFee = tags['entrance_fee'] ?? tags['entrance:fee'] ?? tags['admission'] ?? tags['ticket'];

    String? parsedAmount;
    for (final val in [tags['fee:amount'], tags['charge:amount'], entranceFee, chargeTag]) {
      if (val == null) continue;
      final match = RegExp(r'(\d{2,6})').firstMatch(val);
      if (match != null) {
        parsedAmount = match.group(1);
        break;
      }
    }
    if (parsedAmount != null) {
      return '₹$parsedAmount per person';
    }
    if (feeTag == 'yes' || (entranceFee != null && entranceFee.toString().isNotEmpty) || (chargeTag != null && chargeTag.contains('yes'))) {
      if (place.tourismType == 'museum' || place.tourismType == 'monument' || place.tourismType == 'attraction') {
        return '₹50-200 per person';
      }
      if (place.additionalTags['leisure'] == 'park' || place.additionalTags['leisure'] == 'garden') {
        return '₹20-50 per person';
      }
      return '₹30-100 per person';
    }

    // Attractions by tourism type
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

    // Amenities
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

  // Local helper for attractions cost when OSM tags didn't give an exact value
  static String _estimateAttractionCost(PlaceDetails place) {
    final name = place.name.toLowerCase();
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
    return '₹50-200 per person';
  }
}

class DayPlan {
  final String dayTitle;
  final String description;
  final List<Activity> activities;
  final double? totalEstimatedCost;

  DayPlan({
    required this.dayTitle,
    required this.description,
    required this.activities,
    this.totalEstimatedCost,
  });
}

class Itinerary {
  final String destination;
  final String title;
  final List<DayPlan> dayPlans;
  final String? summary;
  final double? totalEstimatedCost;
  final DateTime? startDate;
  final DateTime? endDate;

  Itinerary({
    required this.destination,
    required this.title,
    required this.dayPlans,
    this.summary,
    this.totalEstimatedCost,
    this.startDate,
    this.endDate,
  });
}
