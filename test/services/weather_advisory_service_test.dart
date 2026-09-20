import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/services/weather_advisory_service.dart';

void main() {
  test('creates rain, UV, and heat advice at the configured thresholds', () {
    final advisories = WeatherAdvisory.evaluate(
      const CwaForecast(
        precipitationProbability: 50,
        uvIndex: 8,
        apparentTemperature: 33,
      ),
    );

    expect(advisories.map((advisory) => advisory.kind), [
      'rain',
      'uv',
      'heat',
    ]);
  });

  test('does not create advice below every threshold', () {
    final advisories = WeatherAdvisory.evaluate(
      const CwaForecast(
        precipitationProbability: 49,
        uvIndex: 7,
        apparentTemperature: 32.9,
      ),
    );

    expect(advisories, isEmpty);
  });
}
