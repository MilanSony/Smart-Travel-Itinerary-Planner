import 'dart:math';

/// Service that provides climate/seasonal weather guidance when exact forecasts aren't available
class ClimateService {
  /// Get seasonal weather guidance based on month and location
  static Map<String, dynamic> getSeasonalGuidance({
    required DateTime date,
    required double latitude,
  }) {
    final month = date.month;
    final isNorthernHemisphere = latitude >= 0;
    
    // Determine season based on hemisphere
    String season;
    if (isNorthernHemisphere) {
      if (month >= 3 && month <= 5) {
        season = 'Spring';
      } else if (month >= 6 && month <= 8) {
        season = 'Summer';
      } else if (month >= 9 && month <= 11) {
        season = 'Autumn';
      } else {
        season = 'Winter';
      }
    } else {
      // Southern hemisphere - reversed seasons
      if (month >= 3 && month <= 5) {
        season = 'Autumn';
      } else if (month >= 6 && month <= 8) {
        season = 'Winter';
      } else if (month >= 9 && month <= 11) {
        season = 'Spring';
      } else {
        season = 'Summer';
      }
    }
    
    // Estimate temperature based on latitude and season
    double estimatedTemp = _estimateTemperature(latitude, month, isNorthernHemisphere);
    
    // Estimate precipitation probability based on season and location
    int precipProb = _estimatePrecipitationProbability(latitude, month, isNorthernHemisphere);
    
    // Determine if likely poor weather
    bool likelyPoorWeather = _isLikelyPoorWeather(month, latitude, isNorthernHemisphere);
    
    return {
      'season': season,
      'estimatedTemperature': estimatedTemp,
      'estimatedPrecipitationProbability': precipProb,
      'likelyPoorWeather': likelyPoorWeather,
      'guidance': _getSeasonalGuidance(season, latitude, month),
    };
  }
  
  static double _estimateTemperature(double latitude, int month, bool isNorthernHemisphere) {
    // Rough temperature estimation based on latitude and month
    // This is a simplified model - actual temperatures vary greatly
    
    // Base temperature decreases with distance from equator
    double baseTemp = 30 - (latitude.abs() * 0.7);
    
    // Seasonal variation (simplified)
    double seasonalAdjustment = 0;
    if (isNorthernHemisphere) {
      // Northern hemisphere: coldest in Jan (month 1), warmest in Jul (month 7)
      seasonalAdjustment = 10 * sin((month - 1) * pi / 6);
    } else {
      // Southern hemisphere: reversed
      seasonalAdjustment = 10 * sin((month - 7) * pi / 6);
    }
    
    return (baseTemp + seasonalAdjustment).clamp(-10.0, 45.0);
  }
  
  static int _estimatePrecipitationProbability(double latitude, int month, bool isNorthernHemisphere) {
    // Simplified precipitation probability estimation
    // Monsoon regions, coastal areas, etc. would need more complex logic
    
    // Higher probability in certain months for tropical regions
    if (latitude.abs() < 23.5) {
      // Tropical region - higher chance of rain
      return 40 + (Random().nextInt(30));
    }
    
    // Mid-latitudes - seasonal variation
    if (isNorthernHemisphere) {
      if (month >= 6 && month <= 8) {
        return 30 + (Random().nextInt(20)); // Summer - moderate rain
      } else if (month >= 12 || month <= 2) {
        return 20 + (Random().nextInt(15)); // Winter - less rain
      }
    }
    
    return 25 + (Random().nextInt(25)); // Default moderate probability
  }
  
  static bool _isLikelyPoorWeather(int month, double latitude, bool isNorthernHemisphere) {
    // Determine if weather is likely to be poor based on season and location
    
    // Monsoon seasons (simplified)
    if (latitude > 0 && latitude < 30) {
      // Northern hemisphere monsoon regions
      if (month >= 6 && month <= 9) {
        return true; // Monsoon season
      }
    } else if (latitude < 0 && latitude > -30) {
      // Southern hemisphere monsoon regions
      if (month >= 12 || month <= 3) {
        return true; // Monsoon season
      }
    }
    
    // Winter months in high latitudes
    if (latitude.abs() > 40) {
      if (isNorthernHemisphere && (month >= 12 || month <= 2)) {
        return true; // Winter - snow/ice likely
      } else if (!isNorthernHemisphere && (month >= 6 && month <= 8)) {
        return true; // Winter - snow/ice likely
      }
    }
    
    return false;
  }
  
  static String _getSeasonalGuidance(String season, double latitude, int month) {
    final isTropical = latitude.abs() < 23.5;
    final isTemperate = latitude.abs() >= 23.5 && latitude.abs() < 60;
    final isPolar = latitude.abs() >= 60;
    
    if (isTropical) {
      return 'Tropical climate: Expect warm temperatures year-round. '
          'Rain is common, especially during monsoon seasons. '
          'Pack light, breathable clothing and rain protection.';
    } else if (isTemperate) {
      switch (season) {
        case 'Summer':
          return 'Summer: Warm to hot temperatures. '
              'Good for outdoor activities. Pack sunscreen and light clothing.';
        case 'Winter':
          return 'Winter: Cold temperatures possible. '
              'Pack warm clothing and be prepared for snow in some regions.';
        case 'Spring':
          return 'Spring: Mild temperatures with variable weather. '
              'Pack layers and be prepared for occasional rain.';
        case 'Autumn':
          return 'Autumn: Cool temperatures, generally pleasant. '
              'Pack layers and light rain protection.';
        default:
          return 'Variable weather expected. Pack layers and be prepared for changes.';
      }
    } else if (isPolar) {
      return 'Polar/subarctic climate: Very cold temperatures expected. '
          'Pack heavy winter clothing and be prepared for snow and ice.';
    }
    
    return 'Weather conditions vary by season. Check local forecasts closer to your travel date.';
  }
  
  /// Get general packing suggestions based on climate
  static List<String> getClimateBasedPacking({
    required double latitude,
    required int month,
  }) {
    final guidance = getSeasonalGuidance(
      date: DateTime(2024, month, 15),
      latitude: latitude,
    );
    
    final temp = guidance['estimatedTemperature'] as double;
    final precipProb = guidance['estimatedPrecipitationProbability'] as int;
    final likelyPoor = guidance['likelyPoorWeather'] as bool;
    
    final suggestions = <String>[];
    
    if (temp >= 25) {
      suggestions.addAll([
        'Lightweight, breathable clothing',
        'Sunscreen (SPF 30+)',
        'Sun hat or cap',
        'Sunglasses',
        'Water bottle',
      ]);
    } else if (temp >= 15) {
      suggestions.addAll([
        'Light layers',
        'Comfortable walking shoes',
        'Light jacket or sweater',
      ]);
    } else {
      suggestions.addAll([
        'Warm layers',
        'Jacket or coat',
        'Warm socks',
        'Scarf and gloves (if very cold)',
      ]);
    }
    
    if (precipProb >= 40 || likelyPoor) {
      suggestions.addAll([
        'Umbrella',
        'Waterproof jacket',
        'Waterproof shoes',
      ]);
    }
    
    suggestions.addAll([
      'Comfortable walking shoes',
      'First aid kit',
      'Portable charger',
    ]);
    
    return suggestions;
  }
}
