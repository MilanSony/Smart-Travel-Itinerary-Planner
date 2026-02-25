import 'package:flutter_test/flutter_test.dart';
import 'package:trip_genie/services/weather_service.dart';

void main() {
  test('DailyForecast.isPoorForOutdoors triggers on high precip probability', () {
    final f = DailyForecast(
      date: DateTime(2026, 1, 1),
      precipitationProbabilityMaxPct: 80,
      precipitationSumMm: 0,
      windSpeedMaxKmh: 0,
      weatherCode: 1,
    );
    expect(f.isPoorForOutdoors, true);
  });

  test('WeatherService validates latitude/longitude ranges', () async {
    final svc = WeatherService();
    await expectLater(
      () => svc.getDailyForecast(
        latitude: 999,
        longitude: 10,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 1),
      ),
      throwsArgumentError,
    );
    await expectLater(
      () => svc.getDailyForecast(
        latitude: 10,
        longitude: 999,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 1),
      ),
      throwsArgumentError,
    );
  });

  test('WeatherService validates startDate <= endDate', () async {
    final svc = WeatherService();
    await expectLater(
      () => svc.getDailyForecast(
        latitude: 10,
        longitude: 10,
        startDate: DateTime(2026, 1, 2),
        endDate: DateTime(2026, 1, 1),
      ),
      throwsArgumentError,
    );
  });
}

