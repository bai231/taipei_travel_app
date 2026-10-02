import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taipei_travel_app/services/cwa_query_limiter.dart';
import 'package:taipei_travel_app/services/location_service.dart';
import 'package:taipei_travel_app/services/trip_notification_service.dart';

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

  test('景點綜覽與同縣市 GPS 共用快取，跨縣市仍受一小時節流', () async {
    var requests = 0;
    final service = WeatherAdvisoryService(
      apiKey: 'test-key',
      queryLimiter: CwaQueryLimiter(store: _MemoryQueryTimeStore()),
      notifications: _WeatherNotifications(),
      client: MockClient((_) async {
        requests++;
        return http.Response('{"records":{"Locations":[]}}', 200);
      }),
    );
    addTearDown(service.dispose);
    final start = DateTime(2026, 9, 23, 10);
    const position = LocationPoint(latitude: 25.05, longitude: 121.6);

    await service.overviewForPlace(
      districtName: '南港區',
      cityName: '臺北市',
      placePosition: position,
      now: start,
    );
    await service.check(
      position,
      cityName: '臺北市',
      now: start.add(const Duration(minutes: 5)),
    );
    expect(requests, 1);

    final otherCity = await service.overviewForPlace(
      districtName: '中區',
      cityName: '臺中市',
      placePosition: position,
      now: start.add(const Duration(minutes: 10)),
    );
    expect(otherCity, isNull);
    expect(requests, 1);
  });

  test('parses a CWA rain observation', () {
    final forecast = CwaForecast.fromJson(
      jsonDecode(_forecastResponse(rain: 60).body) as Map<String, dynamic>,
      const LocationPoint(latitude: 25.04, longitude: 121.52),
      DateTime(2026, 9, 27, 9),
    );
    expect(forecast.precipitationProbability, 60);
  });

  test(
    'one-hour reservation survives a new limiter and is shared by trips',
    () async {
      final store = _MemoryQueryTimeStore();
      final first = CwaQueryLimiter(store: store);
      final nextTrip = CwaQueryLimiter(store: store);
      final start = DateTime(2026, 9, 27, 9);

      expect(await first.reserve(start), isTrue);
      expect(
        await nextTrip.reserve(start.add(const Duration(minutes: 59))),
        isFalse,
      );
      expect(
        await nextTrip.reserve(start.add(const Duration(hours: 1))),
        isTrue,
      );
    },
  );

  test('simultaneous checks share one CWA reservation', () async {
    final limiter = CwaQueryLimiter(store: _MemoryQueryTimeStore());
    final now = DateTime(2026, 9, 27, 9);

    final results = await Future.wait([
      limiter.reserve(now),
      limiter.reserve(now),
    ]);
    expect(results.where((allowed) => allowed), hasLength(1));
  });

  test(
    'separate weather service instances share the same hourly quota',
    () async {
      final store = _MemoryQueryTimeStore();
      var requests = 0;
      WeatherAdvisoryService service() => WeatherAdvisoryService(
        apiKey: 'test-key',
        queryLimiter: CwaQueryLimiter(store: store),
        notifications: _WeatherNotifications(),
        client: MockClient((_) async {
          requests++;
          return _forecastResponse(rain: 20);
        }),
      );
      final first = service();
      final second = service();
      final start = DateTime(2026, 9, 27, 9);
      const position = LocationPoint(latitude: 25.04, longitude: 121.52);

      await first.check(position, now: start);
      await second.check(position, now: start.add(const Duration(minutes: 30)));
      expect(requests, 1);
      await second.check(position, now: start.add(const Duration(hours: 1)));
      expect(requests, 2);

      first.dispose();
      second.dispose();
    },
  );

  test('a failed CWA response also consumes the hour interval', () async {
    var requests = 0;
    final service = WeatherAdvisoryService(
      apiKey: 'test-key',
      queryLimiter: CwaQueryLimiter(store: _MemoryQueryTimeStore()),
      notifications: _WeatherNotifications(),
      client: MockClient((_) async {
        requests++;
        return http.Response('unavailable', 503);
      }),
    );
    final start = DateTime(2026, 9, 27, 9);
    const position = LocationPoint(latitude: 25.04, longitude: 121.52);

    await service.check(position, now: start);
    await service.check(position, now: start.add(const Duration(minutes: 5)));
    expect(requests, 1);
    await service.check(position, now: start.add(const Duration(hours: 1)));
    expect(requests, 2);
    service.dispose();
  });

  test(
    'latest position is used after an hour, not on each GPS update',
    () async {
      final requests = <http.Request>[];
      final service = WeatherAdvisoryService(
        apiKey: 'test-key',
        queryLimiter: CwaQueryLimiter(store: _MemoryQueryTimeStore()),
        notifications: _WeatherNotifications(),
        client: MockClient((request) async {
          requests.add(request);
          return _forecastResponse(rain: 20);
        }),
      );
      final start = DateTime(2026, 9, 27, 9);
      const firstPosition = LocationPoint(latitude: 25.04, longitude: 121.52);
      const laterPosition = LocationPoint(latitude: 24.15, longitude: 120.67);

      await service.check(firstPosition, now: start);
      await service.check(
        laterPosition,
        now: start.add(const Duration(minutes: 30)),
      );
      expect(requests, hasLength(1));
      await service.check(
        laterPosition,
        now: start.add(const Duration(hours: 1)),
      );
      expect(requests, hasLength(2));
      service.dispose();
    },
  );

  test(
    'same risk alerts once, then alerts again after observed recovery',
    () async {
      final notifications = _WeatherNotifications();
      final rainValues = [60.0, 80.0, 20.0, 55.0];
      var requestIndex = 0;
      final service = WeatherAdvisoryService(
        apiKey: 'test-key',
        queryLimiter: CwaQueryLimiter(store: _MemoryQueryTimeStore()),
        notifications: notifications,
        client: MockClient(
          (_) async => _forecastResponse(rain: rainValues[requestIndex++]),
        ),
      );
      final start = DateTime(2026, 9, 27, 9);
      const position = LocationPoint(latitude: 25.04, longitude: 121.52);

      for (var hour = 0; hour < 4; hour++) {
        await service.check(position, now: start.add(Duration(hours: hour)));
      }

      expect(requestIndex, 4);
      expect(notifications.titles, ['稍後可能下雨', '稍後可能下雨']);
      service.dispose();
    },
  );

  test('weather notification carries the active guardian session ID', () async {
    final notifications = _WeatherNotifications();
    final service = WeatherAdvisoryService(
      apiKey: 'test-key',
      queryLimiter: CwaQueryLimiter(store: _MemoryQueryTimeStore()),
      notifications: notifications,
      client: MockClient((_) async => _forecastResponse(rain: 60)),
    );
    addTearDown(service.dispose);

    await service.check(
      const LocationPoint(latitude: 25.04, longitude: 121.52),
      now: DateTime(2026, 9, 27, 9),
      guardianSessionId: 'active-trip-1',
    );

    expect(notifications.payloads, ['guardian:weather:active-trip-1']);
  });

  test('missing observations do not clear an active risk', () async {
    final notifications = _WeatherNotifications();
    final rainValues = <double?>[60, null, 65];
    var requestIndex = 0;
    final service = WeatherAdvisoryService(
      apiKey: 'test-key',
      queryLimiter: CwaQueryLimiter(store: _MemoryQueryTimeStore()),
      notifications: notifications,
      client: MockClient(
        (_) async => _forecastResponse(rain: rainValues[requestIndex++]),
      ),
    );
    final start = DateTime(2026, 9, 27, 9);
    const position = LocationPoint(latitude: 25.04, longitude: 121.52);

    for (var hour = 0; hour < 3; hour++) {
      await service.check(position, now: start.add(Duration(hours: hour)));
    }

    expect(notifications.titles, ['稍後可能下雨']);
    service.dispose();
  });
}

class _MemoryQueryTimeStore implements CwaQueryTimeStore {
  DateTime? lastAttempt;

  @override
  Future<DateTime?> readLastAttempt() async => lastAttempt;

  @override
  Future<void> writeLastAttempt(DateTime time) async {
    lastAttempt = time;
  }
}

class _WeatherNotifications extends Fake implements TripNotificationGateway {
  final List<String> titles = [];
  final List<String?> payloads = [];

  @override
  Future<void> showWeatherAdvisory({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    titles.add(title);
    payloads.add(payload);
  }
}

http.Response _forecastResponse({double? rain}) => http.Response(
  jsonEncode({
    'records': {
      'locations': [
        {
          'location': [
            {
              'lat': '25.04',
              'lon': '121.52',
              'weatherElement': [
                if (rain != null)
                  {
                    'elementName': '降雨機率',
                    'time': [
                      {
                        'elementValue': [
                          {'value': '$rain'},
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
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
