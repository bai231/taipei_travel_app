import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taipei_travel_app/services/location_service.dart';
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

    expect(advisories.map((advisory) => advisory.kind), ['rain', 'uv', 'heat']);
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

  test('selects the nearest township and merges forecast horizons', () {
    final forecast = CwaForecast.fromJson(
      {
        'records': {
          'Locations': [
            {
              'Location': [
                {
                  'LocationName': '中正區',
                  'Latitude': '25.0324',
                  'Longitude': '121.5199',
                  'WeatherElement': [
                    {
                      'ElementName': '天氣預報綜合描述',
                      'Time': [
                        {
                          'StartTime': '2026-09-22T09:00:00+08:00',
                          'EndTime': '2026-09-22T12:00:00+08:00',
                          'ElementValue': [
                            {'WeatherDescription': '晴時多雲'},
                          ],
                        },
                      ],
                    },
                    {
                      'ElementName': '3小時降雨機率',
                      'Time': [
                        {
                          'StartTime': '2026-09-22T09:00:00+08:00',
                          'EndTime': '2026-09-22T12:00:00+08:00',
                          'ElementValue': [
                            {'ProbabilityOfPrecipitation': '60'},
                          ],
                        },
                      ],
                    },
                  ],
                },
              ],
            },
            {
              'Location': [
                {
                  'LocationName': '中正區',
                  'Latitude': '25.0324',
                  'Longitude': '121.5199',
                  'WeatherElement': [
                    {
                      'ElementName': '最高溫度',
                      'Time': [
                        {
                          'StartTime': '2026-09-22T06:00:00+08:00',
                          'EndTime': '2026-09-22T18:00:00+08:00',
                          'ElementValue': [
                            {'MaxTemperature': '34'},
                          ],
                        },
                      ],
                    },
                    {
                      'ElementName': '最低溫度',
                      'Time': [
                        {
                          'StartTime': '2026-09-22T06:00:00+08:00',
                          'EndTime': '2026-09-22T18:00:00+08:00',
                          'ElementValue': [
                            {'MinTemperature': '27'},
                          ],
                        },
                      ],
                    },
                    {
                      'ElementName': '紫外線指數',
                      'Time': [
                        {
                          'StartTime': '2026-09-22T06:00:00+08:00',
                          'EndTime': '2026-09-22T18:00:00+08:00',
                          'ElementValue': [
                            {'UVIndex': '8'},
                          ],
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
      },
      const LocationPoint(latitude: 25.033, longitude: 121.52),
      DateTime.parse('2026-09-22T10:00:00+08:00'),
    );

    expect(forecast.locationName, '中正區');
    expect(forecast.weatherDescription, '晴時多雲');
    expect(forecast.precipitationProbability, 60);
    expect(forecast.maximumTemperature, 34);
    expect(forecast.minimumTemperature, 27);
    expect(forecast.uvIndex, 8);
  });

  test(
    'overview prefers the attraction district over the fallback GPS area',
    () {
      final forecast = CwaForecast.fromJsonForLocation(
        {
          'records': {
            'Locations': [
              {
                'LocationsName': '臺北市',
                'Location': [
                  {
                    'LocationName': '中正區',
                    'Latitude': '25.0324',
                    'Longitude': '121.5199',
                    'WeatherElement': const [],
                  },
                ],
              },
              {
                'LocationsName': '桃園市',
                'Location': [
                  {
                    'LocationName': '龜山區',
                    'Latitude': '25.0330',
                    'Longitude': '121.5200',
                    'WeatherElement': const [],
                  },
                ],
              },
            ],
          },
        },
        districtName: '中正區',
        cityName: '台北市',
        fallbackPosition: const LocationPoint(
          latitude: 25.033,
          longitude: 121.52,
        ),
        now: DateTime.parse('2026-09-22T10:00:00+08:00'),
      );

      expect(forecast.cityName, '臺北市');
      expect(forecast.locationName, '中正區');
    },
  );

  test('overview requests only the database city CWA datasets', () async {
    late Uri requestedUri;
    final service = WeatherAdvisoryService(
      apiKey: 'test-key',
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response('{"records":{"Locations":[]}}', 200);
      }),
    );
    addTearDown(service.dispose);

    await service.overviewForPlace(
      districtName: '南港區',
      cityName: '台北市',
      placePosition: const LocationPoint(
        latitude: 25.052645,
        longitude: 121.605982,
      ),
      now: DateTime.parse('2026-09-23T10:00:00+08:00'),
    );

    expect(
      requestedUri.queryParameters['locationId'],
      'F-D0047-061,F-D0047-063',
    );
  });
}
