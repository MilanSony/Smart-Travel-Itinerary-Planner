import '../models/itinerary_model.dart';
import 'weather_service.dart';

/// Public representation of a packing suggestion item.
class PackingItem {
  final String id;
  final String name;
  final bool isEssential;
  final String? reason;
  /// Whether this item is specifically for children (vs general/adult).
  /// Used by the UI to show a separate "Children's packing list" section.
  final bool isForChildren;

  const PackingItem({
    required this.id,
    required this.name,
    this.isEssential = false,
    this.reason,
    this.isForChildren = false,
  });
}

/// Internal rule structure representing an association-style rule learned
/// offline from historical trips (context tags -> suggested items).
class _PackingRule {
  final Set<String> conditions;
  final List<PackingItem> conclusions;

  const _PackingRule({
    required this.conditions,
    required this.conclusions,
  });
}

/// Simple ML-style engine that approximates association rule mining.
///
/// In a real setup, the rules would be generated offline from data using
/// Apriori / FP-Growth and then shipped as a JSON model. Here we embed a
/// small, curated rule set that still behaves like a learned model by
/// matching abstract context tags (weather + activities) to items.
class PackingListService {
  static const List<_PackingRule> _rules = [
    // Hot + beach-style activities
    _PackingRule(
      conditions: {'hot_weather', 'beach_or_water'},
      conclusions: [
        PackingItem(
          id: 'sunscreen',
          name: 'Sunscreen (SPF 30+)',
          isEssential: true,
          reason: 'Strong sun and outdoor time near water.',
        ),
        PackingItem(
          id: 'hat_cap',
          name: 'Hat / Cap',
          reason: 'Helps prevent sunburn during hot days.',
        ),
        PackingItem(
          id: 'swimwear',
          name: 'Swimwear',
          reason: 'Recommended for beach or pool activities.',
        ),
      ],
    ),
    // Hot generic city sightseeing
    _PackingRule(
      conditions: {'hot_weather', 'city_sightseeing'},
      conclusions: [
        PackingItem(
          id: 'light_clothes',
          name: 'Light, breathable clothing',
          reason: 'Keeps you comfortable while walking in high temperatures.',
        ),
        PackingItem(
          id: 'water_bottle',
          name: 'Reusable water bottle',
          isEssential: true,
          reason: 'Prevents dehydration on hot sightseeing days.',
        ),
      ],
    ),
    // Cold + hill / trekking
    _PackingRule(
      conditions: {'cold_weather', 'hill_or_trek'},
      conclusions: [
        PackingItem(
          id: 'warm_jacket',
          name: 'Warm jacket',
          isEssential: true,
          reason: 'Needed for low temperatures in hill stations or treks.',
        ),
        PackingItem(
          id: 'gloves',
          name: 'Gloves & warm cap',
          reason: 'Keeps extremities warm during outdoor activities.',
        ),
        PackingItem(
          id: 'trek_shoes',
          name: 'Trekking / sturdy shoes',
          reason: 'Better grip and comfort on uneven terrain.',
        ),
      ],
    ),
    // High rain probability
    _PackingRule(
      conditions: {'high_rain_risk'},
      conclusions: [
        PackingItem(
          id: 'umbrella',
          name: 'Compact umbrella or raincoat',
          isEssential: true,
          reason: 'High chance of rain during your trip.',
        ),
        PackingItem(
          id: 'waterproof_bag',
          name: 'Waterproof bag / cover',
          reason: 'Protects electronics and documents from rain.',
        ),
      ],
    ),
    // Business / formal activities
    _PackingRule(
      conditions: {'business_focus'},
      conclusions: [
        PackingItem(
          id: 'formal_wear',
          name: 'Formal wear (shirt, trousers, shoes)',
          isEssential: true,
          reason: 'Useful for meetings, conferences or client visits.',
        ),
        PackingItem(
          id: 'laptop_docs',
          name: 'Laptop & important documents',
          reason: 'Commonly required during business-focused trips.',
        ),
      ],
    ),
    // Family / kids focus
    _PackingRule(
      conditions: {'family_focus'},
      conclusions: [
        PackingItem(
          id: 'snacks_kids',
          name: 'Snacks & basic medicines for family',
          reason: 'Helps with kids or elders during long travel days.',
        ),
        PackingItem(
          id: 'entertainment_kids',
          name: 'Small entertainment items (books / games)',
          reason: 'Keeps children engaged during transit and waiting times.',
        ),
      ],
    ),
  ];

  /// Build high-level context tags from itinerary and forecasts.
  /// These tags are used both by the deterministic rule-engine
  /// and as part of Apriori transactions in Firestore.
  static Set<String> buildContextTags(
    Itinerary itinerary,
    List<DailyForecast> forecasts,
  ) {
    final tags = <String>{};

    // Basic duration estimate.
    final start = itinerary.startDate;
    DateTime? end = itinerary.endDate;
    int tripDays = itinerary.dayPlans.isNotEmpty ? itinerary.dayPlans.length : 3;
    if (start != null) {
      end ??= start.add(Duration(days: tripDays - 1));
      tripDays = end.difference(start).inDays + 1;
    }
    if (tripDays <= 3) {
      tags.add('3_days');
    } else if (tripDays <= 6) {
      tags.add('4_6_days');
    } else {
      tags.add('7_plus_days');
    }

    // Demographic / travelers-based tags (for research + ARM).
    final adults = itinerary.numAdults ?? 0;
    final children = itinerary.numChildren ?? 0;
    if (adults > 0) {
      tags.add('with_adults');
    }
    if (children > 0) {
      tags.add('with_children');
      // Coarse child age-group tags if available.
      final groups = itinerary.childrenAgeGroups ?? const <String>[];
      for (final g in groups) {
        final key = g.toLowerCase();
        if (key.contains('infant') || key.contains('0_2')) {
          tags.add('with_infant');
        } else if (key.contains('toddler') || key.contains('3_6')) {
          tags.add('with_toddler');
        } else if (key.contains('school') ||
            key.contains('7_12') ||
            key.contains('child')) {
          tags.add('with_school_age_child');
        }
      }
    }

    // Weather-based tags (aggregated over the trip).
    if (forecasts.isNotEmpty) {
      final temps =
          forecasts.map((f) => f.temperatureMaxC).whereType<double>().toList();
      final precipProb = forecasts
          .map((f) => f.precipitationProbabilityMaxPct)
          .whereType<int>()
          .toList();
      final weatherCodes =
          forecasts.map((f) => f.weatherCode).whereType<int>().toList();

      final maxTemp =
          temps.isEmpty ? null : temps.reduce((a, b) => a > b ? a : b);
      final minTemp =
          temps.isEmpty ? null : temps.reduce((a, b) => a < b ? a : b);
      final maxPrecipProb = precipProb.isEmpty
          ? null
          : precipProb.reduce((a, b) => a > b ? a : b);

      if (maxTemp != null) {
        if (maxTemp >= 32) {
          tags.add('hot_weather');
        } else if (maxTemp <= 18) {
          tags.add('cold_weather');
        }
      }
      if (minTemp != null && minTemp <= 15) {
        tags.add('cool_nights');
      }

      if (maxPrecipProb != null) {
        if (maxPrecipProb >= 70) {
          tags.add('high_rain_risk');
        } else if (maxPrecipProb >= 40) {
          tags.add('some_rain');
        }
      }

      final hasSnow = weatherCodes.any((code) => code >= 71 && code <= 86);
      if (hasSnow) {
        tags.add('snow_risk');
        tags.add('cold_weather');
      }
    }

    // Itinerary / activity-based tags.
    final lowerDestination = itinerary.destination.toLowerCase();
    if (lowerDestination.contains('goa') || lowerDestination.contains('beach')) {
      tags.add('beach_or_water');
    }
    if (lowerDestination.contains('manali') ||
        lowerDestination.contains('shimla') ||
        lowerDestination.contains('hill')) {
      tags.add('hill_or_trek');
    }
    if (lowerDestination.contains('pune') ||
        lowerDestination.contains('mumbai') ||
        lowerDestination.contains('delhi') ||
        lowerDestination.contains('bengaluru') ||
        lowerDestination.contains('bangalore') ||
        lowerDestination.contains('chennai') ||
        lowerDestination.contains('hyderabad')) {
      tags.add('metro_city');
    }

    bool hasBeachLike = false;
    bool hasTrekLike = false;
    bool hasBusinessLike = false;
    bool hasFamilyLike = false;

    for (final day in itinerary.dayPlans) {
      final desc = day.description.toLowerCase();
      if (desc.contains('beach') ||
          desc.contains('water sports') ||
          desc.contains('boat')) {
        hasBeachLike = true;
      }
      if (desc.contains('trek') ||
          desc.contains('hike') ||
          desc.contains('camp')) {
        hasTrekLike = true;
      }
      if (desc.contains('meeting') ||
          desc.contains('conference') ||
          desc.contains('business')) {
        hasBusinessLike = true;
      }
      if (desc.contains('family') || desc.contains('kids')) {
        hasFamilyLike = true;
      }

      for (final act in day.activities) {
        final t = act.title.toLowerCase();
        final ad = act.description.toLowerCase();
        if (t.contains('beach') || t.contains('boat') || ad.contains('beach')) {
          hasBeachLike = true;
        }
        if (t.contains('trek') ||
            t.contains('hike') ||
            t.contains('camp')) {
          hasTrekLike = true;
        }
        if (t.contains('meeting') ||
            t.contains('office') ||
            ad.contains('business')) {
          hasBusinessLike = true;
        }
        if (t.contains('family') || ad.contains('kids')) {
          hasFamilyLike = true;
        }
      }
    }

    if (hasBeachLike) tags.add('beach_or_water');
    if (hasTrekLike) tags.add('hill_or_trek');
    if (hasBusinessLike) tags.add('business_focus');
    if (hasFamilyLike) tags.add('family_focus');

    // Generic sightseeing if not clearly business-only.
    if (!hasBusinessLike) {
      tags.add('city_sightseeing');
    }

    return tags;
  }

  static List<PackingItem> generatePackingList(
    Itinerary itinerary,
    List<DailyForecast> forecasts,
  ) {
    // Only generate list if we have weather data
    if (forecasts.isEmpty) {
      return const [];
    }

    final tags = buildContextTags(itinerary, forecasts);

    // Recompute duration days for clothing calculations.
    final start = itinerary.startDate;
    DateTime? end = itinerary.endDate;
    int tripDays = itinerary.dayPlans.isNotEmpty ? itinerary.dayPlans.length : 3;
    if (start != null) {
      end ??= start.add(Duration(days: tripDays - 1));
      tripDays = end.difference(start).inDays + 1;
    }

    // Extract weather conditions for climate-specific recommendations
    final temps =
        forecasts.map((f) => f.temperatureMaxC).whereType<double>().toList();
    final maxTemp = temps.isEmpty ? null : temps.reduce((a, b) => a > b ? a : b);

    final precipProb = forecasts
        .map((f) => f.precipitationProbabilityMaxPct)
        .whereType<int>()
        .toList();
    final precipSum =
        forecasts.map((f) => f.precipitationSumMm).whereType<double>().toList();
    final winds =
        forecasts.map((f) => f.windSpeedMaxKmh).whereType<double>().toList();
    final codes = forecasts.map((f) => f.weatherCode).whereType<int>().toList();

    final maxPrecipProb = precipProb.isEmpty
        ? null
        : precipProb.reduce((a, b) => a > b ? a : b);
    final maxPrecipSum =
        precipSum.isEmpty ? null : precipSum.reduce((a, b) => a > b ? a : b);
    final maxWind = winds.isEmpty ? null : winds.reduce((a, b) => a > b ? a : b);

    final bool hasThunderstorm = codes.any((c) => c >= 95);
    final bool hasSnow = codes.any((c) => c >= 71 && c <= 86);
    final bool hasFog = codes.any((c) => c >= 45 && c <= 48);

    final bool isVeryHot = maxTemp != null && maxTemp >= 35;
    final bool isHot = maxTemp != null && maxTemp >= 32;
    final bool isVeryCold = maxTemp != null && maxTemp <= 10;
    final bool isCold = maxTemp != null && maxTemp <= 18;
    final bool isModerate = maxTemp != null && maxTemp > 18 && maxTemp < 32;
    // Check for cool nights based on tags (set in buildContextTags)
    final bool hasCoolNights = tags.contains('cool_nights');

    final bool isHeavyRain =
        (maxPrecipProb != null && maxPrecipProb >= 70) ||
            (maxPrecipSum != null && maxPrecipSum >= 10);
    final bool isSomeRain =
        !isHeavyRain && (maxPrecipProb != null && maxPrecipProb >= 40);
    final bool isVeryWindy = maxWind != null && maxWind >= 35;
    final bool isWindy = maxWind != null && maxWind >= 25;

    final Map<String, PackingItem> result = {};

    // Demographic counts used for quantity hints for children items.
    final int adults = itinerary.numAdults ?? 1; // Default to 1 if not specified
    final int children = itinerary.numChildren ?? 0;

    // 1. CLOTHING - Destination and climate-aware generation
    // Check destination type for specific recommendations
    final bool isBeachDestination = tags.contains('beach_or_water');
    final bool isHillStation = tags.contains('hill_or_trek');
    final bool isMetroCity = tags.contains('metro_city');
    final bool isBusinessTrip = tags.contains('business_focus');

    if (isHot || isCold || isModerate) {
      // Base quantities per person (based on trip duration)
      final int shirtsPerPerson = tripDays <= 3 ? 3 : (tripDays <= 6 ? 4 : 6);
      final int bottomsPerPerson = tripDays <= 3 ? 2 : (tripDays <= 6 ? 3 : 4);
      final int innerwearPerPerson = tripDays + 1;
      final int socksPerPerson = tripDays <= 3 ? 3 : (tripDays <= 6 ? 5 : 7);
      final int sleepwearPerPerson = tripDays <= 3 ? 1 : 2;

      // Scale quantities by number of adults
      final int shirts = shirtsPerPerson * adults;
      final int bottoms = bottomsPerPerson * adults;
      final int innerwear = innerwearPerPerson * adults;
      final int socks = socksPerPerson * adults;
      final int sleepwear = sleepwearPerPerson * adults;

      // Tops based on climate + destination type
      if (isVeryHot) {
        if (isBeachDestination) {
          result['clothes_tops'] = PackingItem(
            id: 'clothes_tops',
            name: '$shirts very light, breathable t-shirts / tank tops / beach shirts',
            reason:
                'Very hot beach weather in ${itinerary.destination} (${maxTemp?.toStringAsFixed(0)}°C max) — pack ultra-light, quick-dry fabrics for $adults ${adults == 1 ? 'adult' : 'adults'}.',
          );
        } else if (isMetroCity) {
          result['clothes_tops'] = PackingItem(
            id: 'clothes_tops',
            name: '$shirts light cotton shirts / t-shirts (mix of casual & semi-formal)',
            reason:
                'Very hot city weather in ${itinerary.destination} (${maxTemp?.toStringAsFixed(0)}°C max) — pack versatile, breathable clothes for $adults ${adults == 1 ? 'adult' : 'adults'}.',
          );
        } else {
          result['clothes_tops'] = PackingItem(
            id: 'clothes_tops',
            name: '$shirts very light, breathable shirts / t-shirts',
            reason:
                'Very hot weather in ${itinerary.destination} (${maxTemp?.toStringAsFixed(0)}°C max) — pack light, breathable fabrics for $adults ${adults == 1 ? 'adult' : 'adults'}.',
          );
        }
        result['quick_dry'] = const PackingItem(
          id: 'quick_dry',
          name: 'Quick-dry clothing (optional)',
          reason: 'Useful when sweating a lot or during sudden showers.',
        );
      } else if (isHot) {
        if (isBeachDestination) {
          result['clothes_tops'] = PackingItem(
            id: 'clothes_tops',
            name: '$shirts light t-shirts / tank tops / casual beach shirts',
            reason:
                'Hot beach weather in ${itinerary.destination} (${maxTemp?.toStringAsFixed(0)}°C max) — pack casual, light cotton/linen clothes for $adults ${adults == 1 ? 'adult' : 'adults'}.',
          );
        } else if (isMetroCity && isBusinessTrip) {
          result['clothes_tops'] = PackingItem(
            id: 'clothes_tops',
            name: '$shirts light formal shirts / casual business shirts',
            reason:
                'Hot business trip in ${itinerary.destination} (${maxTemp?.toStringAsFixed(0)}°C max) — pack breathable formal wear for $adults ${adults == 1 ? 'adult' : 'adults'}.',
          );
        } else if (isMetroCity) {
          result['clothes_tops'] = PackingItem(
            id: 'clothes_tops',
            name: '$shirts light shirts / t-shirts (mix of casual & smart casual)',
            reason:
                'Hot city weather in ${itinerary.destination} (${maxTemp?.toStringAsFixed(0)}°C max) — pack versatile, light cotton clothes for $adults ${adults == 1 ? 'adult' : 'adults'}.',
          );
        } else {
          result['clothes_tops'] = PackingItem(
            id: 'clothes_tops',
            name: '$shirts light, breathable shirts / t-shirts',
            reason:
                'Hot weather in ${itinerary.destination} (${maxTemp?.toStringAsFixed(0)}°C max) — pack light, cotton clothes for $adults ${adults == 1 ? 'adult' : 'adults'}.',
          );
        }
      } else if (isCold) {
        if (isHillStation) {
          result['clothes_tops'] = PackingItem(
            id: 'clothes_tops',
            name: '$shirts warm layers / thermal shirts / fleece sweaters',
            reason:
                'Cold hill station weather in ${itinerary.destination} (${maxTemp?.toStringAsFixed(0)}°C max) — pack warm, layered clothing for $adults ${adults == 1 ? 'adult' : 'adults'}.',
          );
        } else if (isMetroCity && isBusinessTrip) {
          result['clothes_tops'] = PackingItem(
            id: 'clothes_tops',
            name: '$shirts warm formal shirts / sweaters / blazers',
            reason:
                'Cold business trip in ${itinerary.destination} (${maxTemp?.toStringAsFixed(0)}°C max) — pack warm, professional layers for $adults ${adults == 1 ? 'adult' : 'adults'}.',
          );
        } else if (isMetroCity) {
          result['clothes_tops'] = PackingItem(
            id: 'clothes_tops',
            name: '$shirts warm layers / sweaters / hoodies',
            reason:
                'Cold city weather in ${itinerary.destination} (${maxTemp?.toStringAsFixed(0)}°C max) — pack warm, versatile layers for $adults ${adults == 1 ? 'adult' : 'adults'}.',
          );
        } else {
          result['clothes_tops'] = PackingItem(
            id: 'clothes_tops',
            name: '$shirts warm layers / sweaters',
            reason:
                'Cold weather in ${itinerary.destination} (${maxTemp?.toStringAsFixed(0)}°C max) — pack warm layers for $adults ${adults == 1 ? 'adult' : 'adults'}.',
          );
        }
      } else if (isModerate) {
        if (isBeachDestination) {
          result['clothes_tops'] = PackingItem(
            id: 'clothes_tops',
            name: '$shirts comfortable t-shirts / casual shirts / light layers',
            reason:
                'Moderate beach weather in ${itinerary.destination} (${maxTemp?.toStringAsFixed(0)}°C max) — pack comfortable, casual layers for $adults ${adults == 1 ? 'adult' : 'adults'}.',
          );
        } else if (isHillStation) {
          result['clothes_tops'] = PackingItem(
            id: 'clothes_tops',
            name: '$shirts comfortable shirts / light sweaters / layers',
            reason:
                'Moderate hill station weather in ${itinerary.destination} (${maxTemp?.toStringAsFixed(0)}°C max) — pack layered clothing for temperature changes for $adults ${adults == 1 ? 'adult' : 'adults'}.',
          );
        } else if (isMetroCity && isBusinessTrip) {
          result['clothes_tops'] = PackingItem(
            id: 'clothes_tops',
            name: '$shirts comfortable formal shirts / smart casual shirts',
            reason:
                'Moderate business trip in ${itinerary.destination} (${maxTemp?.toStringAsFixed(0)}°C max) — pack versatile professional wear for $adults ${adults == 1 ? 'adult' : 'adults'}.',
          );
        } else if (isMetroCity) {
          result['clothes_tops'] = PackingItem(
            id: 'clothes_tops',
            name: '$shirts comfortable shirts / t-shirts (versatile mix)',
            reason:
                'Moderate city weather in ${itinerary.destination} (${maxTemp?.toStringAsFixed(0)}°C max) — pack versatile, comfortable layers for $adults ${adults == 1 ? 'adult' : 'adults'}.',
          );
        } else {
          result['clothes_tops'] = PackingItem(
            id: 'clothes_tops',
            name: '$shirts comfortable shirts / t-shirts',
            reason:
                'Moderate weather in ${itinerary.destination} (${maxTemp?.toStringAsFixed(0)}°C max) — pack comfortable layers for $adults ${adults == 1 ? 'adult' : 'adults'}.',
          );
        }
      }

      // Bottoms - Destination-specific
      if (isBeachDestination && isHot) {
        result['clothes_bottoms'] = PackingItem(
          id: 'clothes_bottoms',
          name: '$bottoms pairs of shorts / beach pants / casual pants',
          reason: 'Beach destination — pack casual, comfortable bottoms for $adults ${adults == 1 ? 'adult' : 'adults'} during your $tripDays-day trip.',
        );
      } else if (isHillStation) {
        result['clothes_bottoms'] = PackingItem(
          id: 'clothes_bottoms',
          name: '$bottoms pairs of comfortable pants / trekking pants${isHot ? ' + shorts' : ''}',
          reason: 'Hill station destination — pack durable, comfortable bottoms for $adults ${adults == 1 ? 'adult' : 'adults'} during your $tripDays-day trip.',
        );
      } else if (isMetroCity && isBusinessTrip) {
        result['clothes_bottoms'] = PackingItem(
          id: 'clothes_bottoms',
          name: '$bottoms pairs of formal trousers / business pants${isHot ? ' + casual pants' : ''}',
          reason: 'Business trip — pack professional bottoms for $adults ${adults == 1 ? 'adult' : 'adults'} during your $tripDays-day trip.',
        );
      } else if (isMetroCity) {
        result['clothes_bottoms'] = PackingItem(
          id: 'clothes_bottoms',
          name: '$bottoms pairs of comfortable pants${isHot ? '/shorts' : ''} (mix of casual & smart casual)',
          reason: 'City destination — pack versatile bottoms for $adults ${adults == 1 ? 'adult' : 'adults'} during your $tripDays-day trip.',
        );
      } else {
        result['clothes_bottoms'] = PackingItem(
          id: 'clothes_bottoms',
          name: '$bottoms pairs of comfortable pants${isHot ? '/shorts' : ''}',
          reason: 'Enough bottoms for $adults ${adults == 1 ? 'adult' : 'adults'} during your $tripDays-day trip.',
        );
      }

      // Innerwear
      result['clothes_innerwear'] = PackingItem(
        id: 'clothes_innerwear',
        name: '$innerwear sets of innerwear',
        reason: 'One set per day per person plus an extra for emergencies for $adults ${adults == 1 ? 'adult' : 'adults'}.',
      );

      // Socks - Destination-specific
      if (isBeachDestination && isHot) {
        result['clothes_socks'] = PackingItem(
          id: 'clothes_socks',
          name: '$socks pairs of light cotton socks / ankle socks',
          reason: 'Beach destination — pack light socks for $adults ${adults == 1 ? 'adult' : 'adults'} (less needed, but useful for walking).',
        );
      } else if (isHillStation) {
        result['clothes_socks'] = PackingItem(
          id: 'clothes_socks',
          name: '$socks pairs of thick woolen / thermal socks',
          reason: 'Hill station — pack warm, moisture-wicking socks for $adults ${adults == 1 ? 'adult' : 'adults'} during trekking and cold weather.',
        );
      } else if (isCold) {
        result['clothes_socks'] = PackingItem(
          id: 'clothes_socks',
          name: '$socks pairs of warm socks / woolen socks',
          reason: 'Cold weather — pack warm socks for $adults ${adults == 1 ? 'adult' : 'adults'} to keep feet comfortable.',
        );
      } else {
        result['clothes_socks'] = PackingItem(
          id: 'clothes_socks',
          name: '$socks pairs of comfortable socks',
          reason: 'Keeps feet comfortable for $adults ${adults == 1 ? 'adult' : 'adults'} during walking and travel days.',
        );
      }

      // Sleepwear
      result['clothes_sleepwear'] = PackingItem(
        id: 'clothes_sleepwear',
        name: '$sleepwear ${sleepwear == 1 ? 'set' : 'sets'} of comfortable sleepwear',
        reason: 'Useful for hotel stays and overnight journeys for $adults ${adults == 1 ? 'adult' : 'adults'}.',
      );

      // Climate-specific extras
      if (isHot) {
        result['sun_protection'] = PackingItem(
          id: 'sun_protection',
          name: '$adults ${adults == 1 ? 'Hat / Cap & Sunglasses' : 'Hats / Caps & Sunglasses'}',
          reason: 'Essential for sun protection in hot weather for $adults ${adults == 1 ? 'adult' : 'adults'}.',
        );
        // Sunscreen can be shared, but scale quantity based on number of people
        final String sunscreenQty = adults <= 2 ? '1-2 bottles' : '${(adults / 2).ceil()} bottles';
        result['sunscreen_base'] = PackingItem(
          id: 'sunscreen_base',
          name: 'Sunscreen (SPF 30+) - $sunscreenQty',
          isEssential: true,
          reason: 'Recommended for strong UV exposure in hot weather for $adults ${adults == 1 ? 'adult' : 'adults'}.',
        );
      }
      if (isCold) {
        result['cold_extras'] = PackingItem(
          id: 'cold_extras',
          name: '$adults ${adults == 1 ? 'set' : 'sets'} of thermal innerwear, gloves & warm cap',
          reason: 'Essential for cold weather in ${itinerary.destination} for $adults ${adults == 1 ? 'adult' : 'adults'}.',
        );
        // Lip balm can be shared, but scale based on number of people
        final String lipBalmQty = adults <= 2 ? '1-2' : '$adults';
        result['lip_balm'] = PackingItem(
          id: 'lip_balm',
          name: '$lipBalmQty moisturizer + lip balm${adults > 2 ? 's' : ''}',
          reason: 'Helps prevent dry skin and cracked lips in cold weather for $adults ${adults == 1 ? 'adult' : 'adults'}.',
        );
      }
      if (hasCoolNights && !isCold) {
        result['light_jacket'] = PackingItem(
          id: 'light_jacket',
          name: '$adults light jacket${adults == 1 ? '' : 's'} or sweater${adults > 1 ? 's' : ''}',
          reason: 'Cool nights expected - pack a light layer for evenings for $adults ${adults == 1 ? 'adult' : 'adults'}.',
        );
      }
      if (isWindy) {
        result['windbreaker'] = PackingItem(
          id: 'windbreaker',
          name: '$adults light windbreaker${adults == 1 ? '' : 's'}',
          reason: maxWind != null
              ? 'Windy days expected (up to ${maxWind.toStringAsFixed(0)} km/h) — carry wind protection for $adults ${adults == 1 ? 'adult' : 'adults'}.'
              : 'Windy days expected — carry wind protection for $adults ${adults == 1 ? 'adult' : 'adults'}.',
        );
      }
    }

    // 2. WEATHER-SPECIFIC ITEMS - Only if relevant
    if (isHeavyRain || isSomeRain) {
      final String rainGearName = isHeavyRain 
          ? '$adults raincoat${adults == 1 ? '' : 's'} / poncho${adults > 1 ? 's' : ''} (recommended)'
          : '$adults compact umbrella${adults == 1 ? '' : 's'}';
      result['rain_gear'] = PackingItem(
        id: 'rain_gear',
        name: rainGearName,
        isEssential: isHeavyRain,
        reason: isHeavyRain
            ? 'Heavy rain expected (${maxPrecipProb ?? '-'}% chance, ${maxPrecipSum?.toStringAsFixed(1) ?? '-'} mm) for $adults ${adults == 1 ? 'adult' : 'adults'}.'
            : 'Rain possible (${maxPrecipProb ?? '-'}% chance) for $adults ${adults == 1 ? 'adult' : 'adults'}.',
      );
      // Waterproof bags can be shared, scale appropriately
      final String bagQty = adults <= 2 ? '1-2' : '${(adults / 2).ceil()}';
      result['waterproof_bag'] = PackingItem(
        id: 'waterproof_bag',
        name: '$bagQty waterproof bag${adults > 2 ? 's' : ''} / cover${adults > 2 ? 's' : ''}',
        reason: 'Protects electronics and documents from rain for $adults ${adults == 1 ? 'adult' : 'adults'}.',
      );
      result['water_resistant_shoes'] = PackingItem(
        id: 'water_resistant_shoes',
        name: '$adults pair${adults == 1 ? '' : 's'} of water-resistant footwear',
        reason: 'Keeps feet dry and prevents slipping on wet surfaces for $adults ${adults == 1 ? 'adult' : 'adults'}.',
      );
    }

    if (hasThunderstorm) {
      result['storm_safety'] = const PackingItem(
        id: 'storm_safety',
        name: 'Small flashlight (or phone torch) + extra power bank',
        reason: 'Thunderstorms possible — useful during power cuts or low visibility.',
      );
    }

    if (hasFog) {
      result['fog_safety'] = const PackingItem(
        id: 'fog_safety',
        name: 'Reflective/bright accessory (or small torch)',
        reason: 'Fog expected — improves visibility and safety during early mornings/nights.',
      );
    }

    if (hasSnow) {
      result['snow_gear'] = PackingItem(
        id: 'snow_gear',
        name: '$adults pair${adults == 1 ? '' : 's'} of snow/thermal socks + $adults pair${adults == 1 ? '' : 's'} of waterproof gloves',
        reason: 'Snow conditions detected — pack extra warm, waterproof accessories for $adults ${adults == 1 ? 'adult' : 'adults'}.',
      );
    }

    if (isHot && tags.contains('beach_or_water')) {
      final String sunscreenQty = adults <= 2 ? '1-2 bottles' : '${(adults / 2).ceil()} bottles';
      result['sunscreen'] = PackingItem(
        id: 'sunscreen',
        name: 'Sunscreen (SPF 30+) - $sunscreenQty',
        isEssential: true,
        reason: 'Strong sun and outdoor time near water in ${itinerary.destination} for $adults ${adults == 1 ? 'adult' : 'adults'}.',
      );
      result['swimwear'] = PackingItem(
        id: 'swimwear',
        name: '$adults ${adults == 1 ? 'swimwear set' : 'swimwear sets'}',
        reason: 'Recommended for beach or pool activities for $adults ${adults == 1 ? 'adult' : 'adults'}.',
      );
      result['waterproof_phone'] = PackingItem(
        id: 'waterproof_phone',
        name: '$adults waterproof phone pouch${adults == 1 ? '' : 'es'} / cover${adults > 1 ? 's' : ''}',
        reason: 'Protects phone${adults > 1 ? 's' : ''} near water and during water activities for $adults ${adults == 1 ? 'adult' : 'adults'}.',
      );
    }

    if (isHot && !tags.contains('beach_or_water')) {
      result['water_bottle'] = PackingItem(
        id: 'water_bottle',
        name: '$adults reusable water bottle${adults == 1 ? '' : 's'}',
        isEssential: true,
        reason: 'Prevents dehydration in hot weather for $adults ${adults == 1 ? 'adult' : 'adults'}.',
      );
    }

    if (isCold && tags.contains('hill_or_trek')) {
      result['warm_jacket'] = PackingItem(
        id: 'warm_jacket',
        name: '$adults warm jacket${adults == 1 ? '' : 's'}',
        isEssential: true,
        reason: 'Needed for low temperatures in ${itinerary.destination} for $adults ${adults == 1 ? 'adult' : 'adults'}.',
      );
      result['trek_shoes'] = PackingItem(
        id: 'trek_shoes',
        name: '$adults pair${adults == 1 ? '' : 's'} of trekking / sturdy shoes',
        reason: 'Better grip and comfort on uneven terrain for $adults ${adults == 1 ? 'adult' : 'adults'}.',
      );
    }

    // 3. ACTIVITY-SPECIFIC ITEMS - Only if relevant
    if (tags.contains('business_focus')) {
      result['formal_wear'] = PackingItem(
        id: 'formal_wear',
        name: '$adults ${adults == 1 ? 'set' : 'sets'} of formal wear (shirt, trousers, shoes)',
        isEssential: true,
        reason: 'Useful for meetings, conferences or client visits for $adults ${adults == 1 ? 'adult' : 'adults'}.',
      );
      // Laptops can be shared, but scale based on number of people
      final String laptopQty = adults <= 2 ? '1-2 laptops' : '${(adults / 2).ceil()} laptops';
      result['laptop_docs'] = PackingItem(
        id: 'laptop_docs',
        name: '$laptopQty & important documents',
        reason: 'Commonly required during business-focused trips for $adults ${adults == 1 ? 'adult' : 'adults'}.',
      );
    }

    if (tags.contains('family_focus')) {
      result['snacks_kids'] = const PackingItem(
        id: 'snacks_kids',
        name: 'Snacks & basic medicines for family',
        reason: 'Helps with kids or elders during long travel days.',
      );
      result['entertainment_kids'] = const PackingItem(
        id: 'entertainment_kids',
        name: 'Small entertainment items (books / games)',
        reason: 'Keeps children engaged during transit and waiting times.',
      );
    }

    // 4b. CHILD-SPECIFIC PACKING LIST (separate section) - Age-group specific
    if (children > 0) {
      // Basic child profile based on age groups
      final groups = itinerary.childrenAgeGroups ?? const <String>[];
      final bool hasInfant =
          groups.any((g) => g.toLowerCase().contains('infant') || g.contains('0_2'));
      final bool hasToddler =
          groups.any((g) => g.toLowerCase().contains('toddler') || g.contains('3_6'));
      final bool hasSchoolAge = groups.any((g) =>
          g.toLowerCase().contains('school') ||
          g.toLowerCase().contains('7_12'));

      // Count children by age group for better item descriptions
      final int infantCount = hasInfant ? children : 0;
      final int toddlerCount = hasToddler ? children : 0;
      final int schoolAgeCount = hasSchoolAge ? children : 0;

      // ========== INFANT-SPECIFIC ITEMS (0-2 years) ==========
      if (hasInfant) {
        final String infantLabel = infantCount == 1 ? '1 infant' : '$infantCount infants';
        
        // Infant clothing
        result['infant_clothes'] = PackingItem(
          id: 'infant_clothes',
          name: 'Baby outfits for $infantLabel ($tripDays days)',
          reason:
              'Pack enough onesies, sleepers, and soft cotton outfits for $infantLabel. Include extra sets for spills and changes.',
          isForChildren: true,
        );

        // Weather-specific infant items
        if (isHot || isVeryHot) {
          result['infant_sun_protection'] = PackingItem(
            id: 'infant_sun_protection',
            name: 'Baby sun hat, UV-protective clothing & baby-safe sunscreen',
            reason:
                'Infants have sensitive skin – essential sun protection for hot weather (${maxTemp?.toStringAsFixed(0)}°C).',
            isForChildren: true,
          );
        }
        if (isCold || isVeryCold || hasSnow) {
          result['infant_warm_layers'] = PackingItem(
            id: 'infant_warm_layers',
            name: 'Warm baby clothes, booties, mittens & warm cap',
            reason:
                'Infants lose heat quickly – pack extra warm layers for cold weather (${maxTemp?.toStringAsFixed(0)}°C).',
            isForChildren: true,
          );
        }
        if (isHeavyRain || isSomeRain) {
          result['infant_rain_gear'] = PackingItem(
            id: 'infant_rain_gear',
            name: 'Baby rain cover for stroller / carrier',
            reason:
                'Keeps $infantLabel dry during rain. Stroller rain covers are essential for infants.',
            isForChildren: true,
          );
        }

        // Infant essentials
        result['infant_diapers'] = PackingItem(
          id: 'infant_diapers',
          name: 'Diapers (${tripDays * 6}-${tripDays * 8} pcs), wipes & changing mat',
          reason:
              'Infants need frequent diaper changes – pack extra for $infantLabel. Include portable changing pad.',
          isForChildren: true,
        );
        result['infant_feeding'] = PackingItem(
          id: 'infant_feeding',
          name: 'Feeding bottles, formula / baby food, bibs & burp cloths',
          reason:
              'Essential feeding items for $infantLabel. Pack enough formula/food for the trip duration.',
          isForChildren: true,
        );
        result['infant_blanket'] = PackingItem(
          id: 'infant_blanket',
          name: 'Soft baby blanket, swaddles & pacifiers',
          reason:
              'Comfort items for $infantLabel during travel and sleep. Pacifiers help with ear pressure during flights.',
          isForChildren: true,
        );
        result['infant_carrier'] = PackingItem(
          id: 'infant_carrier',
          name: 'Baby carrier / sling',
          reason:
              'Hands-free carrying for $infantLabel during sightseeing and transit. More convenient than stroller in crowded places.',
          isForChildren: true,
        );
        result['infant_health'] = PackingItem(
          id: 'infant_health',
          name: 'Infant-safe fever reducer (consult pediatrician) & baby thermometer',
          reason:
              'Age-appropriate medicine for $infantLabel. Always consult doctor before travel for specific recommendations.',
          isForChildren: true,
        );
      }

      // ========== TODDLER-SPECIFIC ITEMS (3-6 years) ==========
      if (hasToddler) {
        final String toddlerLabel = toddlerCount == 1 ? '1 toddler' : '$toddlerCount toddlers';
        
        // Toddler clothing
        result['toddler_clothes'] = PackingItem(
          id: 'toddler_clothes',
          name: 'Toddler outfits for $toddlerLabel ($tripDays days)',
          reason:
              'Pack comfortable, easy-to-change clothes for $toddlerLabel. Include extra sets for accidents and play.',
          isForChildren: true,
        );

        // Weather-specific toddler items
        if (isHot || isVeryHot) {
          result['toddler_sun_protection'] = PackingItem(
            id: 'toddler_sun_protection',
            name: 'Toddler sun hat, child-safe sunscreen (SPF 50+) & UV sunglasses',
            reason:
                'Toddlers are active outdoors – protect $toddlerLabel from sunburn in hot weather (${maxTemp?.toStringAsFixed(0)}°C).',
            isForChildren: true,
          );
        }
        if (isCold || isVeryCold || hasSnow) {
          result['toddler_warm_layers'] = PackingItem(
            id: 'toddler_warm_layers',
            name: 'Warm layers for $toddlerLabel (jackets, sweaters, caps, gloves)',
            reason:
                'Toddlers need warm clothing for cold weather (${maxTemp?.toStringAsFixed(0)}°C). Pack waterproof outer layer if snow expected.',
            isForChildren: true,
          );
        }
        if (isHeavyRain || isSomeRain) {
          result['toddler_rain_gear'] = PackingItem(
            id: 'toddler_rain_gear',
            name: 'Toddler-sized raincoat, rain boots & compact umbrella',
            reason:
                'Keep $toddlerLabel dry during rain. Rain boots prevent wet feet from puddles.',
            isForChildren: true,
          );
        }

        // Toddler essentials
        result['toddler_potty'] = PackingItem(
          id: 'toddler_potty',
          name: 'Portable potty seat / training pants (if potty training)',
          reason:
              'Essential for $toddlerLabel if potty training. Portable seat helps with unfamiliar toilets.',
          isForChildren: true,
        );
        result['toddler_snacks'] = PackingItem(
          id: 'toddler_snacks',
          name: 'Healthy snacks, sippy cups & spill-proof containers',
          reason:
              'Toddlers need frequent snacks. Spill-proof containers prevent mess during travel.',
          isForChildren: true,
        );
        result['toddler_toys'] = PackingItem(
          id: 'toddler_toys',
          name: 'Small toys, picture books, coloring books & crayons',
          reason:
              'Keeps $toddlerLabel engaged during travel. Simple toys and books work best for this age.',
          isForChildren: true,
        );
        result['toddler_comfort'] = PackingItem(
          id: 'toddler_comfort',
          name: 'Comfort item (favorite toy / blanket) & nightlight',
          reason:
              'Familiar items help $toddlerLabel feel secure in new places. Nightlight helps with sleep in unfamiliar rooms.',
          isForChildren: true,
        );
        result['toddler_health'] = PackingItem(
          id: 'toddler_health',
          name: 'Toddler-safe fever/pain medicine (consult pediatrician)',
          reason:
              'Age-appropriate medicine for $toddlerLabel. Consult doctor for correct dosage based on weight.',
          isForChildren: true,
        );
        result['toddler_bandages'] = PackingItem(
          id: 'toddler_bandages',
          name: 'Fun bandages, antiseptic wipes & child-safe insect repellent',
          reason:
              'Toddlers are active and prone to minor injuries. Fun bandages make boo-boos less scary.',
          isForChildren: true,
        );
        if (isHot || isVeryHot) {
          result['toddler_ors'] = PackingItem(
            id: 'toddler_ors',
            name: 'ORS / electrolyte solution for toddlers',
            reason:
                'Prevents dehydration for active $toddlerLabel in hot weather (${maxTemp?.toStringAsFixed(0)}°C).',
            isForChildren: true,
          );
        }
      }

      // ========== SCHOOL-AGE SPECIFIC ITEMS (7-12 years) ==========
      if (hasSchoolAge) {
        final String schoolLabel = schoolAgeCount == 1 ? '1 child' : '$schoolAgeCount children';
        
        // School-age clothing
        result['school_clothes'] = PackingItem(
          id: 'school_clothes',
          name: 'Outfits for $schoolLabel ($tripDays days)',
          reason:
              'Pack comfortable, weather-appropriate clothes for $schoolLabel. Include mix of casual and activity wear.',
          isForChildren: true,
        );

        // Weather-specific school-age items
        if (isHot || isVeryHot) {
          result['school_sun_protection'] = PackingItem(
            id: 'school_sun_protection',
            name: 'Sun hat, child-safe sunscreen (SPF 30+) & sunglasses',
            reason:
                'Protect $schoolLabel from sunburn during outdoor activities in hot weather (${maxTemp?.toStringAsFixed(0)}°C).',
            isForChildren: true,
          );
        }
        if (isCold || isVeryCold || hasSnow) {
          result['school_warm_layers'] = PackingItem(
            id: 'school_warm_layers',
            name: 'Warm layers for $schoolLabel (jackets, sweaters, caps, gloves)',
            reason:
                'School-age children need warm clothing for cold weather (${maxTemp?.toStringAsFixed(0)}°C). Pack waterproof outer layer if snow expected.',
            isForChildren: true,
          );
        }
        if (isHeavyRain || isSomeRain) {
          result['school_rain_gear'] = PackingItem(
            id: 'school_rain_gear',
            name: 'Raincoat / rain jacket & waterproof shoes for $schoolLabel',
            reason:
                'Keep $schoolLabel dry during rain. Waterproof shoes prevent wet feet.',
            isForChildren: true,
          );
        }

        // School-age essentials
        result['school_snacks'] = PackingItem(
          id: 'school_snacks',
          name: 'Healthy snacks, reusable water bottles & lunch box',
          reason:
              'School-age children need regular snacks and hydration. Reusable bottles are eco-friendly.',
          isForChildren: true,
        );
        result['school_entertainment'] = PackingItem(
          id: 'school_entertainment',
          name: 'Books, travel games, activity books, puzzle books & headphones',
          reason:
              'Keeps $schoolLabel engaged during travel. Headphones for tablets/phones during flights.',
          isForChildren: true,
        );
        result['school_independence'] = PackingItem(
          id: 'school_independence',
          name: 'Small backpack, travel journal & camera (if interested)',
          reason:
              'Encourages independence for $schoolLabel. They can carry their own items and document the trip.',
          isForChildren: true,
        );
        result['school_health'] = PackingItem(
          id: 'school_health',
          name: 'Child-safe fever/pain medicine (consult pediatrician)',
          reason:
              'Age-appropriate medicine for $schoolLabel. Consult doctor for correct dosage.',
          isForChildren: true,
        );
        result['school_bandages'] = PackingItem(
          id: 'school_bandages',
          name: 'Bandages, antiseptic wipes & child-safe insect repellent',
          reason:
              'School-age children are active explorers. First-aid essentials for minor injuries.',
          isForChildren: true,
        );
        if (isHot || isVeryHot) {
          result['school_ors'] = PackingItem(
            id: 'school_ors',
            name: 'ORS / electrolyte solution for children',
            reason:
                'Prevents dehydration for active $schoolLabel in hot weather (${maxTemp?.toStringAsFixed(0)}°C).',
            isForChildren: true,
          );
        }
      }
    }

    // 4c. ESSENTIAL ITEMS - Always included
    result['id_docs'] = PackingItem(
      id: 'id_docs',
      name: '$adults ${adults == 1 ? 'set' : 'sets'} of ID, tickets & hotel details',
      isEssential: true,
      reason: 'Required for almost every trip for $adults ${adults == 1 ? 'adult' : 'adults'}.',
    );
    result['phone_power'] = PackingItem(
      id: 'phone_power',
      name: '$adults phone${adults == 1 ? '' : 's'}, charger${adults > 1 ? 's' : ''} & power bank${adults > 1 ? 's' : ''}',
      isEssential: true,
      reason: 'Keeps communication and navigation available for $adults ${adults == 1 ? 'adult' : 'adults'}.',
    );

    // 5. MEDICINES - Dynamically generated based on actual climate conditions
    final List<String> medicineList = [];
    final List<String> medicineReasons = [];

    // Core travel medicines (always needed regardless of weather)
    medicineList.add('Personal prescription medicines');
    medicineReasons.add('Your regular medications as prescribed by your doctor.');

    medicineList.add('Pain relievers');
    medicineReasons.add('Essential for headaches, body aches, and general pain relief during travel.');

    medicineList.add('Digestive aids / Antacids');
    medicineReasons.add('Prevents stomach upset and indigestion from different food and water.');

    medicineList.add('Motion sickness tablets');
    medicineReasons.add('Prevents nausea during travel by road, air, or water.');

    medicineList.add('Antihistamines');
    medicineReasons.add('For allergic reactions, insect bites, and seasonal allergies.');

    medicineList.add('Basic first-aid kit');
    medicineReasons.add('Band-aids, antiseptic, gauze for minor cuts and wounds.');

    // Climate-specific medicines based on actual temperature analysis
    if (maxTemp != null) {
      if (maxTemp >= 35) {
        // Very hot conditions
        medicineList.add('High SPF sunscreen (SPF 50+)');
        medicineReasons.add(
            'Critical for very hot weather (${maxTemp.toStringAsFixed(0)}°C) - prevents severe sunburn.');

        medicineList.add('Aloe vera gel / After-sun lotion');
        medicineReasons.add(
            'Soothes sunburn and skin damage from extreme heat (${maxTemp.toStringAsFixed(0)}°C).');

        medicineList.add('Electrolyte powder / ORS packets');
        medicineReasons.add(
            'Essential for preventing dehydration in extreme heat (${maxTemp.toStringAsFixed(0)}°C).');

        medicineList.add('Heat exhaustion prevention tablets');
        medicineReasons.add(
            'Prevents heat stroke and exhaustion in very hot conditions (${maxTemp.toStringAsFixed(0)}°C).');

        medicineList.add('Anti-fungal powder');
        medicineReasons.add(
            'Prevents fungal infections common in hot, humid conditions (${maxTemp.toStringAsFixed(0)}°C).');

        medicineList.add('Heat rash / Prickly heat powder');
        medicineReasons.add(
            'Relieves skin irritation from excessive sweating in hot weather (${maxTemp.toStringAsFixed(0)}°C).');
      } else if (maxTemp >= 32) {
        // Hot conditions
        medicineList.add('Sunscreen (SPF 30+)');
        medicineReasons.add(
            'Prevents sunburn in hot weather (${maxTemp.toStringAsFixed(0)}°C).');

        medicineList.add('Electrolyte powder / ORS packets');
        medicineReasons.add(
            'Prevents dehydration in hot conditions (${maxTemp.toStringAsFixed(0)}°C).');

        medicineList.add('Anti-fungal powder');
        medicineReasons.add(
            'Prevents fungal infections in hot, humid weather (${maxTemp.toStringAsFixed(0)}°C).');

        medicineList.add('Heat rash powder');
        medicineReasons.add(
            'Relieves skin irritation from sweating (${maxTemp.toStringAsFixed(0)}°C).');
      } else if (maxTemp <= 10) {
        // Very cold conditions
        medicineList.add('Cold & flu prevention medicine');
        medicineReasons.add(
            'Essential for very cold weather (${maxTemp.toStringAsFixed(0)}°C) - prevents common cold.');

        medicineList.add('Cough syrup / Throat lozenges');
        medicineReasons.add(
            'Relieves cough and throat irritation in very cold conditions (${maxTemp.toStringAsFixed(0)}°C).');

        medicineList.add('Decongestant nasal spray');
        medicineReasons.add(
            'Relieves nasal congestion in cold weather (${maxTemp.toStringAsFixed(0)}°C).');

        medicineList.add('Vaporub / Menthol balm');
        medicineReasons.add(
            'Relieves chest congestion and breathing issues in cold weather (${maxTemp.toStringAsFixed(0)}°C).');

        medicineList.add('Joint pain relief cream');
        medicineReasons.add(
            'Helps with joint stiffness in very cold conditions (${maxTemp.toStringAsFixed(0)}°C).');

        medicineList.add('Vitamin C supplements');
        medicineReasons.add(
            'Boosts immunity in cold weather (${maxTemp.toStringAsFixed(0)}°C).');
      } else if (maxTemp <= 18) {
        // Cold conditions
        medicineList.add('Cold & flu medicine');
        medicineReasons.add(
            'Prevents common cold symptoms in cold weather (${maxTemp.toStringAsFixed(0)}°C).');

        medicineList.add('Cough syrup / Lozenges');
        medicineReasons.add(
            'Relieves cough and throat irritation (${maxTemp.toStringAsFixed(0)}°C).');

        medicineList.add('Vaporub / Menthol balm');
        medicineReasons.add(
            'Relieves nasal and chest congestion (${maxTemp.toStringAsFixed(0)}°C).');

        medicineList.add('Joint pain relief cream');
        medicineReasons.add(
            'Helps with joint stiffness in cold weather (${maxTemp.toStringAsFixed(0)}°C).');
      }
    }

    // Precipitation-based medicines
    if (maxPrecipProb != null) {
      if (maxPrecipProb >= 70 || (maxPrecipSum != null && maxPrecipSum >= 10)) {
        // Heavy rain conditions
        medicineList.add('Anti-fungal powder / cream');
        medicineReasons.add(
            'Critical for heavy rain conditions (${maxPrecipProb}% chance, ${maxPrecipSum != null ? maxPrecipSum!.toStringAsFixed(1) : "high"}mm) - prevents fungal infections.');

        medicineList.add('Antiseptic solution');
        medicineReasons.add(
            'Prevents infection from cuts and wounds in wet conditions (${maxPrecipProb}% rain chance).');

        medicineList.add('Waterproof bandages');
        medicineReasons.add(
            'Protects wounds from getting wet in heavy rain (${maxPrecipProb}% chance).');

        medicineList.add('Anti-diarrheal medicine');
        medicineReasons.add(
            'Prevents waterborne illnesses common during heavy rainfall (${maxPrecipProb}% chance).');
      } else if (maxPrecipProb >= 40) {
        // Moderate rain conditions
        medicineList.add('Anti-fungal powder');
        medicineReasons.add(
            'Prevents fungal infections from damp conditions (${maxPrecipProb}% rain chance).');

        medicineList.add('Antiseptic solution');
        medicineReasons.add(
            'Prevents infection from cuts in wet conditions (${maxPrecipProb}% rain chance).');
      }
    }

    // Temperature variation medicines
    if (maxTemp != null && temps.length > 1) {
      final tempRange = temps.reduce((a, b) => a > b ? a : b) -
          temps.reduce((a, b) => a < b ? a : b);
      if (tempRange >= 12) {
        medicineList.add('Multi-layer clothing support medicine');
        medicineReasons.add(
            'Large temperature swings (${tempRange.toStringAsFixed(0)}°C range) - helps body adapt to temperature changes.');
      }
    }

    // Add medicines as separate items
    for (int i = 0; i < medicineList.length; i++) {
      final medId = 'med_${i}_${medicineList[i].toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
      result[medId] = PackingItem(
        id: medId,
        name: medicineList[i],
        isEssential: i < 6, // First 6 are essential general medicines
        reason: medicineReasons[i],
      );
    }

    return result.values.toList(growable: false);
  }
}

