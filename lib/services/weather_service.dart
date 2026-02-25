import 'dart:convert';
import 'package:http/http.dart' as http;

/// Simple forecast client using Open-Meteo (no API key required).
/// API docs: https://open-meteo.com/
class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Fetch daily forecast for [startDate]..[endDate] (inclusive).
  ///
  /// Validation:
  /// - latitude must be in [-90, 90]
  /// - longitude must be in [-180, 180]
  /// - startDate <= endDate
  Future<List<DailyForecast>> getDailyForecast({
    required double latitude,
    required double longitude,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (latitude.isNaN || latitude < -90 || latitude > 90) {
      throw ArgumentError('Invalid latitude: $latitude');
    }
    if (longitude.isNaN || longitude < -180 || longitude > 180) {
      throw ArgumentError('Invalid longitude: $longitude');
    }
    
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    if (end.isBefore(start)) {
      throw ArgumentError('endDate must be on/after startDate');
    }
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'daily': [
        'weather_code',
        'precipitation_sum',
        'precipitation_probability_max',
        'wind_speed_10m_max',
        'temperature_2m_max',
      ].join(','),
      'timezone': 'auto',
      'start_date': _fmtDate(start),
      'end_date': _fmtDate(end),
    });

    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      
      if (resp.statusCode != 200) {
        // Try to parse error message from response
        String errorMsg = 'Unable to fetch weather forecast';
        try {
          final errorBody = json.decode(resp.body) as Map<String, dynamic>?;
          if (errorBody != null && errorBody.containsKey('reason')) {
            final reason = errorBody['reason']?.toString() ?? '';
            if (reason.contains('date') || reason.contains('time')) {
              errorMsg = 'Weather forecast is only available for dates within the next 16 days. Your trip dates may be outside this range.';
            } else {
              errorMsg = 'Weather API error: $reason';
            }
          }
        } catch (_) {
          // Use default error message
        }
        
        if (resp.statusCode == 400) {
          // Check if it's a date-related error
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final maxDate = today.add(const Duration(days: 16));
          
          if (start.isAfter(maxDate)) {
            throw Exception(
              'Weather forecasts are only available up to 16 days ahead.\n'
              'Your trip starts on ${_fmtDate(start)}, which is beyond the forecast window.\n'
              'The itinerary will still be generated, but weather-based adjustments cannot be applied.'
            );
          } else if (start.isBefore(today)) {
            throw Exception(
              'Weather forecasts are only available for future dates.\n'
              'Your trip starts on ${_fmtDate(start)}, which is in the past.'
            );
          } else {
            throw Exception(errorMsg);
          }
        }
        throw Exception(errorMsg);
      }

      final decoded = json.decode(resp.body) as Map<String, dynamic>;
      final daily = decoded['daily'];
      if (daily is! Map<String, dynamic>) return const [];

      final times = (daily['time'] as List?)?.cast<dynamic>() ?? const [];
      final codes = (daily['weather_code'] as List?)?.cast<dynamic>() ?? const [];
      final precipSum =
          (daily['precipitation_sum'] as List?)?.cast<dynamic>() ?? const [];
      final precipProb = (daily['precipitation_probability_max'] as List?)
              ?.cast<dynamic>() ??
          const [];
      final windMax =
          (daily['wind_speed_10m_max'] as List?)?.cast<dynamic>() ?? const [];
      final tempMax =
          (daily['temperature_2m_max'] as List?)?.cast<dynamic>() ?? const [];

      final n = times.length;
      final out = <DailyForecast>[];
      for (var i = 0; i < n; i++) {
        final t = times[i]?.toString();
        if (t == null || t.isEmpty) continue;
        final date = DateTime.tryParse(t);
        if (date == null) continue;

        out.add(DailyForecast(
          date: DateTime(date.year, date.month, date.day),
          weatherCode: _toInt(codes, i),
          precipitationSumMm: _toDouble(precipSum, i),
          precipitationProbabilityMaxPct: _toInt(precipProb, i),
          windSpeedMaxKmh: _toDouble(windMax, i),
          temperatureMaxC: _toDouble(tempMax, i),
        ));
      }
      return out;
    } catch (e) {
      if (e is ArgumentError || e is Exception) {
        rethrow;
      }
      throw Exception('Failed to fetch weather data: ${e.toString()}');
    }
  }

  static int? _toInt(List<dynamic> xs, int i) {
    if (i < 0 || i >= xs.length) return null;
    final v = xs[i];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  static double? _toDouble(List<dynamic> xs, int i) {
    if (i < 0 || i >= xs.length) return null;
    final v = xs[i];
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  static String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}

class DailyForecast {
  final DateTime date;
  final int? weatherCode; // WMO weather interpretation code
  final double? precipitationSumMm;
  final int? precipitationProbabilityMaxPct;
  final double? windSpeedMaxKmh;
  final double? temperatureMaxC;

  const DailyForecast({
    required this.date,
    this.weatherCode,
    this.precipitationSumMm,
    this.precipitationProbabilityMaxPct,
    this.windSpeedMaxKmh,
    this.temperatureMaxC,
  });

  /// Heuristic for "poor weather" where outdoor activities should be swapped.
  bool get isPoorForOutdoors {
    final pProb = precipitationProbabilityMaxPct ?? 0;
    final pSum = precipitationSumMm ?? 0.0;
    final wind = windSpeedMaxKmh ?? 0.0;
    final code = weatherCode ?? 0;

    final isThunderstorm = code >= 95; // 95-99
    final isSnow = code >= 71 && code <= 86;
    final isRain = (code >= 51 && code <= 67) || (code >= 80 && code <= 82);
    final isFreezingRain = code >= 66 && code <= 67;

    if (isThunderstorm) return true;
    if (isSnow) return true;
    if (isFreezingRain) return true;
    if (pProb >= 60) return true;
    if (pSum >= 5.0) return true;
    if (wind >= 35.0) return true;
    if (isRain && pProb >= 40) return true;
    return false;
  }
}

