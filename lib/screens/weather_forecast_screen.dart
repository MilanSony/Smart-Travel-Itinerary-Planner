import 'package:flutter/material.dart';
import '../models/itinerary_model.dart';
import '../services/weather_service.dart';
import '../services/itinerary_service.dart';

class WeatherForecastScreen extends StatefulWidget {
  final Itinerary itinerary;

  const WeatherForecastScreen({super.key, required this.itinerary});

  @override
  State<WeatherForecastScreen> createState() => _WeatherForecastScreenState();
}

class _WeatherForecastScreenState extends State<WeatherForecastScreen> {
  List<DailyForecast>? _forecasts;
  bool _isLoading = true;
  String? _errorMessage;
  Map<DateTime, bool> _adjustedDays = {};
  List<String> _packingHints = const [];

  @override
  void initState() {
    super.initState();
    _loadWeatherData();
  }

  Future<void> _loadWeatherData() async {
    if (widget.itinerary.startDate == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No dates available for weather forecast';
      });
      return;
    }

    try {
      final itineraryService = ItineraryService();
      final coords = await itineraryService.getDestinationCoordinates(
        widget.itinerary.destination,
      );

      if (coords == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Could not get coordinates for ${widget.itinerary.destination}';
        });
        return;
      }

      final start = widget.itinerary.startDate!;
      final end = widget.itinerary.endDate ??
          start.add(Duration(days: widget.itinerary.dayPlans.length - 1));

      final weatherService = WeatherService();
      final forecasts = await weatherService.getDailyForecast(
        latitude: coords['lat']!,
        longitude: coords['lon']!,
        startDate: start,
        endDate: end,
      );

      // Determine which days were adjusted (have weather note in description)
      final adjustedDays = <DateTime, bool>{};
      for (var i = 0; i < widget.itinerary.dayPlans.length; i++) {
        final dayPlan = widget.itinerary.dayPlans[i];
        final dayDate = DateTime(start.year, start.month, start.day)
            .add(Duration(days: i));

        // Check if description contains weather adjustment note
        if (dayPlan.description.toLowerCase().contains('weather forecast') ||
            dayPlan.description.toLowerCase().contains('poor conditions')) {
          adjustedDays[dayDate] = true;
        }
      }

      setState(() {
        _forecasts = forecasts;
        _adjustedDays = adjustedDays;
        _packingHints =
            _buildPackingHints(forecasts, widget.itinerary.destination);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        // Show user-friendly error messages
        String errorMsg = 'Unable to load weather forecast';
        if (e.toString().contains('16 days')) {
          errorMsg = e.toString().replaceAll('Exception: ', '');
        } else if (e.toString().contains('future dates')) {
          errorMsg = e.toString().replaceAll('Exception: ', '');
        } else if (e.toString().contains('coordinates')) {
          errorMsg = 'Could not determine location for ${widget.itinerary.destination}. Weather forecast unavailable.';
        } else {
          errorMsg = 'Weather forecast unavailable. ${e.toString().replaceAll('Exception: ', '').replaceAll('Failed to load weather: ', '')}';
        }
        _errorMessage = errorMsg;
      });
    }
  }

  static List<String> _buildPackingHints(
      List<DailyForecast> forecasts, String destination) {
    if (forecasts.isEmpty) {
      // Minimal fallback if no weather data
      return [
        'Carry basic documents (ID, tickets, hotel details) and some cash.',
        'Pack phone, charger and a power bank for the trip.',
        'Keep any personal medicines and a small first-aid kit.',
        'Wear comfortable walking shoes and carry a reusable water bottle.',
      ];
    }

    // Extract ALL weather data directly from API response
    final temps =
        forecasts.map((f) => f.temperatureMaxC).whereType<double>().toList();
    final precipProb =
        forecasts.map((f) => f.precipitationProbabilityMaxPct).whereType<int>().toList();
    final precipSum =
        forecasts.map((f) => f.precipitationSumMm).whereType<double>().toList();
    final wind =
        forecasts.map((f) => f.windSpeedMaxKmh).whereType<double>().toList();
    final weatherCodes =
        forecasts.map((f) => f.weatherCode).whereType<int>().toList();

    // Calculate statistics from actual API data
    final maxTemp = temps.isEmpty ? null : temps.reduce((a, b) => a > b ? a : b);
    final minTemp = temps.isEmpty ? null : temps.reduce((a, b) => a < b ? a : b);
    final avgTemp = temps.isEmpty ? null : temps.reduce((a, b) => a + b) / temps.length;
    final maxPrecipProb =
        precipProb.isEmpty ? null : precipProb.reduce((a, b) => a > b ? a : b);
    final maxPrecipSum =
        precipSum.isEmpty ? null : precipSum.reduce((a, b) => a > b ? a : b);
    final maxWind = wind.isEmpty ? null : wind.reduce((a, b) => a > b ? a : b);
    final tempRange = (maxTemp != null && minTemp != null) ? (maxTemp - minTemp) : null;

    // Check weather codes from API for specific conditions
    final hasThunderstorm = weatherCodes.any((code) => code >= 95);
    final hasSnow = weatherCodes.any((code) => code >= 71 && code <= 86);
    final hasHeavyRain = weatherCodes.any((code) => code >= 61 && code <= 65) ||
        weatherCodes.any((code) => code >= 80 && code <= 82);
    final hasFog = weatherCodes.any((code) => code >= 45 && code <= 48);

    final hints = <String>[];

    // Essentials (always shown)
    hints.add('Carry basic documents (ID, tickets, hotel details) and some cash.');
    hints.add('Pack phone, charger and a power bank for the trip.');
    hints.add('Keep any personal medicines and a small first-aid kit.');
    hints.add('Wear comfortable walking shoes and carry a reusable water bottle.');

    // Generate hints based PURELY on weather API data values

    // Temperature-based (from API temperature_2m_max)
    if (maxTemp != null) {
      if (maxTemp >= 35) {
        hints.add('Very hot weather expected (${maxTemp.toStringAsFixed(0)}°C max). Pack light, breathable clothes, sunscreen (SPF 30+), sunglasses, and a hat.');
        hints.add('Stay hydrated - carry extra water bottles and electrolyte packets.');
      } else if (maxTemp >= 30) {
        hints.add('Hot weather (${maxTemp.toStringAsFixed(0)}°C max). Pack light clothes, sunscreen, and sunglasses.');
      } else if (maxTemp >= 25) {
        hints.add('Warm weather (${maxTemp.toStringAsFixed(0)}°C max). Pack light layers and sunscreen.');
      } else if (maxTemp >= 20) {
        hints.add('Moderate temperature (${maxTemp.toStringAsFixed(0)}°C max). Pack comfortable layers.');
      } else if (maxTemp >= 15) {
        hints.add('Cool weather (${maxTemp.toStringAsFixed(0)}°C max). Pack a light jacket or sweater.');
      } else {
        hints.add('Cold weather (${maxTemp.toStringAsFixed(0)}°C max). Pack warm layers, jacket, and thermal wear if needed.');
      }
    }

    // Min temperature considerations (from API data)
    if (minTemp != null && minTemp <= 10) {
      hints.add('Cold mornings/evenings expected (${minTemp.toStringAsFixed(0)}°C min). Bring warm accessories: scarf, gloves, and warm socks.');
    } else if (minTemp != null && minTemp <= 15) {
      hints.add('Cool mornings/evenings (${minTemp.toStringAsFixed(0)}°C min). Bring a light sweater or jacket.');
    }

    // Temperature variation (calculated from API data)
    if (tempRange != null && tempRange >= 12) {
      hints.add('Large temperature swings (${tempRange.toStringAsFixed(0)}°C difference). Use layered clothing to adjust throughout the day.');
    } else if (tempRange != null && tempRange >= 8) {
      hints.add('Moderate temperature changes (${tempRange.toStringAsFixed(0)}°C difference). Pack versatile layers.');
    }

    // Precipitation probability (from API precipitation_probability_max)
    if (maxPrecipProb != null) {
      if (maxPrecipProb >= 80) {
        hints.add('Very high rain chance (${maxPrecipProb}%). Carry an umbrella, waterproof jacket, and water-resistant footwear.');
      } else if (maxPrecipProb >= 60) {
        hints.add('High rain chance (${maxPrecipProb}%). Carry an umbrella or light rain jacket.');
        hints.add('Wear water-resistant footwear if possible.');
      } else if (maxPrecipProb >= 40) {
        hints.add('Moderate rain chance (${maxPrecipProb}%). Carry a compact umbrella.');
      } else if (maxPrecipProb >= 20) {
        hints.add('Low rain chance (${maxPrecipProb}%). Consider a light rain cover.');
      }
    }

    // Precipitation amount (from API precipitation_sum)
    if (maxPrecipSum != null && maxPrecipSum >= 10) {
      hints.add('Heavy rainfall expected (${maxPrecipSum.toStringAsFixed(1)}mm). Pack waterproof gear and quick-dry clothing.');
    } else if (maxPrecipSum != null && maxPrecipSum >= 5) {
      hints.add('Moderate rainfall (${maxPrecipSum.toStringAsFixed(1)}mm). Waterproof jacket recommended.');
    }

    // Wind speed (from API wind_speed_10m_max)
    if (maxWind != null) {
      if (maxWind >= 40) {
        hints.add('Very windy conditions (${maxWind.toStringAsFixed(0)} km/h). Carry a windbreaker and secure loose items.');
      } else if (maxWind >= 30) {
        hints.add('Windy conditions (${maxWind.toStringAsFixed(0)} km/h). Carry a windbreaker jacket.');
      } else if (maxWind >= 20) {
        hints.add('Moderate wind (${maxWind.toStringAsFixed(0)} km/h). Light wind protection may be useful.');
      }
    }

    // Weather code specific conditions (from API weather_code)
    if (hasThunderstorm) {
      hints.add('Thunderstorms possible. Avoid outdoor activities during storms and seek indoor shelter.');
    }
    if (hasSnow) {
      hints.add('Snow expected. Pack warm winter gear, waterproof boots, and traction aids if walking on ice.');
    }
    if (hasHeavyRain) {
      hints.add('Heavy rain periods expected. Plan indoor backup activities and allow extra travel time.');
    }
    if (hasFog) {
      hints.add('Foggy conditions possible. Use caution when driving or navigating, carry a flashlight.');
    }

    // Limit to most important 8-10 items
    return hints.take(10).toList(growable: false);
  }

  Widget _buildPackingHintsCard(ThemeData theme) {
    if (_packingHints.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.backpack_outlined,
                  color: Color(0xFF6C5CE7),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Packing hints',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._packingHints.map(
            (h) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      h,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF374151),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build a single day's forecast card for the list view (keeps markup local & reduces nesting complexity)
  Widget _buildForecastCard(int idx, DailyForecast forecast) {
    final theme = Theme.of(context);
    final isPoor = forecast.isPoorForOutdoors;
    final isAdjusted = _adjustedDays.containsKey(forecast.date);
    final dayPlan = idx < widget.itinerary.dayPlans.length ? widget.itinerary.dayPlans[idx] : null;
    final outdoorPlanActivities = dayPlan != null ? dayPlan.activities.where((a) => _isLikelyOutdoor(a)).map((a) => a.title).toList() : const [];

    // Header
    final header = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPoor ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getWeatherColor(isPoor).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getWeatherIcon(forecast.weatherCode, isPoor),
              color: _getWeatherColor(isPoor),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayPlan?.dayTitle ?? 'Day ${idx + 1}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(forecast.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (isPoor)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('Poor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );

    final detailsChildren = <Widget>[];

    // Weather description
    detailsChildren.add(Row(
      children: [
        Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _getWeatherDescription(forecast.weatherCode),
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: const Color(0xFF374151)),
          ),
        ),
      ],
    ));

    detailsChildren.add(const SizedBox(height: 12));
    detailsChildren.add(_buildComfortChip(forecast, theme));
    detailsChildren.add(const SizedBox(height: 12));

    if (forecast.temperatureMaxC != null) {
      detailsChildren.add(_buildDetailRow(icon: Icons.thermostat, label: 'Max Temperature', value: '${forecast.temperatureMaxC!.toStringAsFixed(1)}°C', color: Colors.red));
      detailsChildren.add(const SizedBox(height: 12));
    }
    if (forecast.precipitationProbabilityMaxPct != null) {
      detailsChildren.add(_buildDetailRow(icon: Icons.water_drop, label: 'Rain Chance', value: '${forecast.precipitationProbabilityMaxPct}%', color: Colors.blue));
    }
    if (forecast.precipitationSumMm != null) {
      detailsChildren.add(Padding(
        padding: const EdgeInsets.only(left: 26, top: 4),
        child: Text('Expected: ${forecast.precipitationSumMm!.toStringAsFixed(1)} mm', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
      ));
    }
    if (forecast.windSpeedMaxKmh != null) {
      detailsChildren.add(const SizedBox(height: 12));
      detailsChildren.add(_buildDetailRow(icon: Icons.air, label: 'Max Wind Speed', value: '${forecast.windSpeedMaxKmh!.toStringAsFixed(1)} km/h', color: Colors.grey));
    }

    detailsChildren.add(const SizedBox(height: 8));
    detailsChildren.add(_buildExtremeWeatherNotice(forecast, theme));

    // Weather adjustments summary
    if (isAdjusted) {
      detailsChildren.add(const SizedBox(height: 16));
      detailsChildren.add(Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.swap_horiz, color: Colors.blue[700], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'This day\'s itinerary has been adjusted for weather. Outdoor activities were replaced with indoor alternatives.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.blue[900],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ));
    } else if (isPoor && outdoorPlanActivities.isNotEmpty) {
      // If forecast is poor but not yet adjusted, show warning
      detailsChildren.add(const SizedBox(height: 16));
      detailsChildren.add(Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Poor weather expected. Consider indoor alternatives for outdoor activities.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange[900],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Potentially affected activities:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange[900],
              ),
            ),
            const SizedBox(height: 8),
            ...outdoorPlanActivities.take(3).map((s) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[700],
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ));
    }

    // Good weather message when appropriate
    if (!isPoor) {
      detailsChildren.add(const SizedBox(height: 12));
      detailsChildren.add(Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.green.withOpacity(0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.withOpacity(0.18))),
        child: Row(children: [Icon(Icons.terrain, color: Colors.green[700], size: 18), const SizedBox(width: 8), Expanded(child: Text(outdoorPlanActivities.isNotEmpty ? 'Good weather – great day for outdoor activities. Highlights: ${outdoorPlanActivities.take(3).join(', ')}.' : 'Good weather – a great day to explore outdoors. Consider viewpoints, parks, or beaches based on your interests.', style: theme.textTheme.bodySmall?.copyWith(color: Colors.green[900], fontWeight: FontWeight.w500),),),],),
      ));
    }

    final detailsSection = Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: detailsChildren));
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPoor ? Colors.orange.withOpacity(0.5) : Colors.grey.withOpacity(0.2), width: isPoor ? 2 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header, detailsSection]),
    );
  }

  String _getWeatherDescription(int? code) {
    if (code == null) return 'Unknown';
    if (code == 0) return 'Clear sky';
    if (code == 1 || code == 2 || code == 3) return 'Mainly clear/partly cloudy';
    if (code >= 45 && code <= 48) return 'Foggy';
    if (code >= 51 && code <= 55) return 'Drizzle';
    if (code >= 56 && code <= 57) return 'Freezing drizzle';
    if (code >= 61 && code <= 65) return 'Rain';
    if (code >= 66 && code <= 67) return 'Freezing rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code >= 85 && code <= 86) return 'Snow showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Variable';
  }

  IconData _getWeatherIcon(int? code, bool isPoor) {
    if (isPoor) return Icons.warning_amber_rounded;
    if (code == null) return Icons.help_outline;
    if (code == 0) return Icons.wb_sunny;
    if (code >= 1 && code <= 3) return Icons.wb_cloudy;
    if (code >= 45 && code <= 48) return Icons.foggy;
    if (code >= 51 && code <= 67) return Icons.grain;
    if (code >= 71 && code <= 86) return Icons.ac_unit;
    if (code >= 80 && code <= 82) return Icons.umbrella;
    if (code >= 95) return Icons.flash_on;
    return Icons.wb_cloudy;
  }

  Color _getWeatherColor(bool isPoor) {
    if (isPoor) return Colors.orange;
    return Colors.blue;
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6C5CE7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text(
          'Weather Forecast',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6C5CE7),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadWeatherData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _forecasts == null || _forecasts!.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No weather data available',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Header card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF6C5CE7),
                                Color(0xFFA29BFE),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.itinerary.destination,
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${widget.itinerary.dayPlans.length}-Day Trip Forecast',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildPackingHintsCard(theme),
                        const SizedBox(height: 24),
                        // Forecast cards
                        ..._forecasts!.asMap().entries.map((entry) => _buildForecastCard(entry.key, entry.value)).toList(),
                        const SizedBox(height: 16),
                        // Info footer
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lightbulb_outline,
                                  color: Colors.amber[700], size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Weather-based adjustments are automatically applied to your itinerary. Outdoor activities on poor weather days are replaced with indoor alternatives.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  // Compact chip summarising comfort level for the day.
  Widget _buildComfortChip(DailyForecast forecast, ThemeData theme) {
    final text = _getComfortLevel(forecast);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sentiment_satisfied,
            size: 16,
            color: Colors.green[700],
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.green[900],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getComfortLevel(DailyForecast forecast) {
    final temp = forecast.temperatureMaxC ?? 22.0;
    final precip = forecast.precipitationProbabilityMaxPct ?? 0;
    final wind = forecast.windSpeedMaxKmh ?? 0.0;

    if (forecast.isPoorForOutdoors) {
      return 'Challenging – prefer indoor plans';
    }
    if (temp >= 36 && precip < 40 && wind < 25) {
      return 'Very hot – avoid mid‑day sun';
    }
    if (temp >= 28 && precip < 50 && wind < 30) {
      return 'Warm – good for outdoors';
    }
    if (temp >= 20 && temp < 28 && precip < 60 && wind < 30) {
      return 'Comfortable – ideal sightseeing';
    }
    if (temp < 18 && precip < 50) {
      return 'Cool – carry a light jacket';
    }
    return 'Mixed conditions – keep plans flexible';
  }

  // Heuristic to detect if an Activity is likely outdoors (used for suggestions).
  bool _isLikelyOutdoor(Activity activity) {
    final title = activity.title.toLowerCase();
    final desc = activity.description.toLowerCase();
    final place = activity.placeDetails;
    final keywords = [
      'beach',
      'park',
      'garden',
      'viewpoint',
      'waterfall',
      'lake',
      'river',
      'mountain',
      'hill',
      'trek',
      'hike',
      'camp',
      'wildlife',
      'safari',
      'monument',
      'falls',
      'bay',
      'island',
      'coast',
      'peak'
    ];
    bool containsAny(String text) => keywords.any((k) => text.contains(k));
    if (containsAny(title) || containsAny(desc)) return true;
    if (place != null) {
      final t = place.tourismType ?? '';
      final a = place.amenityType ?? '';
      if (keywords.any((k) => t.contains(k) || a.contains(k))) return true;
      if (place.additionalTags.containsKey('leisure') &&
          (place.additionalTags['leisure'] == 'park' ||
              place.additionalTags['leisure'] == 'garden')) return true;
    }
    return false;
  }

  // Extra notice when weather is significantly worse than ideal.
  Widget _buildExtremeWeatherNotice(
      DailyForecast forecast, ThemeData theme) {
    final temp = forecast.temperatureMaxC ?? 0;
    final precipProb = forecast.precipitationProbabilityMaxPct ?? 0;
    final precipSum = forecast.precipitationSumMm ?? 0.0;
    final wind = forecast.windSpeedMaxKmh ?? 0.0;

    String? message;
    IconData icon = Icons.info_outline;
    Color color = Colors.orange;

    if (temp >= 36) {
      message =
          'Very hot day – schedule outdoor activities for early morning or evening, carry plenty of water and sunscreen.';
      icon = Icons.wb_sunny_outlined;
      color = Colors.deepOrange;
    } else if (precipProb >= 80 || precipSum >= 10.0) {
      message =
          'Heavy rain likely – have backup indoor activities and allow extra travel time between places.';
      icon = Icons.water_drop_outlined;
      color = Colors.blue;
    } else if (wind >= 35) {
      message =
          'Strong winds – avoid high viewpoints or exposed hikes, and secure loose items.';
      icon = Icons.air;
      color = Colors.teal;
    }

    if (message == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF374151),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
