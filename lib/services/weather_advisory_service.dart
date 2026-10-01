import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'location_service.dart';
import 'trip_notification_service.dart';

/// CWA forecast client and travel-only advisory evaluator.
///
/// The CWA key is intentionally supplied at build time, never committed to the
/// app. See `docs/weather-alerts.md` for production delivery requirements.
enum WeatherRiskLevel { warning, severe }

class WeatherAdvisoryService {
  static const _endpoint =
      'https://opendata.cwa.gov.tw/api/v1/rest/datastore/F-D0047-093';
  static const _checkInterval = Duration(hours: 1);
  // F-D0047-093 is an aggregate endpoint. CWA requires at least one of its
  // county forecast resource IDs; including all of them lets GPS select the
  // nearest township without maintaining a second reverse-geocoding service.
  static const _locationIds = <String>[
    'F-D0047-001',
    'F-D0047-003',
    'F-D0047-005',
    'F-D0047-007',
    'F-D0047-009',
    'F-D0047-011',
    'F-D0047-013',
    'F-D0047-015',
    'F-D0047-017',
    'F-D0047-019',
    'F-D0047-021',
    'F-D0047-023',
    'F-D0047-025',
    'F-D0047-027',
    'F-D0047-029',
    'F-D0047-031',
    'F-D0047-033',
    'F-D0047-035',
    'F-D0047-037',
    'F-D0047-039',
    'F-D0047-041',
    'F-D0047-043',
    'F-D0047-045',
    'F-D0047-047',
    'F-D0047-049',
    'F-D0047-051',
    'F-D0047-053',
    'F-D0047-055',
    'F-D0047-057',
    'F-D0047-059',
    'F-D0047-061',
    'F-D0047-063',
    'F-D0047-065',
    'F-D0047-067',
    'F-D0047-069',
    'F-D0047-071',
    'F-D0047-073',
    'F-D0047-075',
    'F-D0047-077',
    'F-D0047-079',
    'F-D0047-081',
    'F-D0047-083',
    'F-D0047-085',
    'F-D0047-087',
    'F-D0047-089',
    'F-D0047-091',
  ];
  static const _locationIdsByCity = <String, List<String>>{
    '宜蘭縣': ['F-D0047-001', 'F-D0047-003'],
    '桃園市': ['F-D0047-005', 'F-D0047-007'],
    '新竹縣': ['F-D0047-009', 'F-D0047-011'],
    '苗栗縣': ['F-D0047-013', 'F-D0047-015'],
    '彰化縣': ['F-D0047-017', 'F-D0047-019'],
    '南投縣': ['F-D0047-021', 'F-D0047-023'],
    '雲林縣': ['F-D0047-025', 'F-D0047-027'],
    '嘉義縣': ['F-D0047-029', 'F-D0047-031'],
    '屏東縣': ['F-D0047-033', 'F-D0047-035'],
    '臺東縣': ['F-D0047-037', 'F-D0047-039'],
    '花蓮縣': ['F-D0047-041', 'F-D0047-043'],
    '澎湖縣': ['F-D0047-045', 'F-D0047-047'],
    '基隆市': ['F-D0047-049', 'F-D0047-051'],
    '新竹市': ['F-D0047-053', 'F-D0047-055'],
    '嘉義市': ['F-D0047-057', 'F-D0047-059'],
    '臺北市': ['F-D0047-061', 'F-D0047-063'],
    '高雄市': ['F-D0047-065', 'F-D0047-067'],
    '新北市': ['F-D0047-069', 'F-D0047-071'],
    '臺中市': ['F-D0047-073', 'F-D0047-075'],
    '臺南市': ['F-D0047-077', 'F-D0047-079'],
    '連江縣': ['F-D0047-081', 'F-D0047-083'],
    '金門縣': ['F-D0047-085', 'F-D0047-087'],
  };

  final String apiKey;
  final http.Client _client;
  final TripNotificationService _notifications;
  DateTime? _lastCheck;
  DateTime? _cachedAt;
  Map<String, dynamic>? _cachedJson;
  String? _cachedLocationIdsKey;
  Future<Map<String, dynamic>?>? _inFlightRequest;
  final Set<String> _sentKinds = <String>{};
  String? lastError;

  WeatherAdvisoryService({
    required this.apiKey,
    http.Client? client,
    TripNotificationService? notifications,
  }) : _client = client ?? http.Client(),
       _notifications = notifications ?? TripNotificationService();

  bool get isConfigured => apiKey.isNotEmpty;

  /// Fetches a township forecast and emits device notifications for new risks.
  Future<WeatherCheckResult?> check(
    LocationPoint position, {
    String? cityName,
    DateTime? now,
  }) async {
    if (!isConfigured) {
      lastError = '尚未設定 CWA_API_KEY。';
      return null;
    }
    final checkedAt = now ?? DateTime.now();
    if (_lastCheck != null &&
        checkedAt.difference(_lastCheck!) < _checkInterval) {
      return null;
    }
    final normalizedCity = _normalizeCityName(cityName);
    final json = await _forecastJson(
      checkedAt,
      locationIds: _locationIdsByCity[normalizedCity] ?? _locationIds,
    );
    if (json == null) return null;
    try {
      _lastCheck = checkedAt;
      final forecast = CwaForecast.fromJson(json, position, checkedAt);
      final newAdvisories = <WeatherAdvisory>[];
      for (final advisory in WeatherAdvisory.evaluate(forecast)) {
        if (!_sentKinds.add(advisory.kind)) continue;
        newAdvisories.add(advisory);
        await _notifications.showWeatherAdvisory(
          id: 7100 + advisory.kind.hashCode.abs() % 100,
          title: advisory.title,
          body: advisory.body,
        );
      }
      return WeatherCheckResult(forecast: forecast, advisories: newAdvisories);
    } catch (error) {
      // Weather advice must never interrupt GPS itinerary tracking.
      lastError = '無法讀取 CWA 天氣資料：$error';
      return null;
    }
  }

  /// Returns the overview for the first attraction's district. If CWA has no
  /// exact district record, it falls back to the nearest record in its city.
  Future<CwaForecast?> overviewForPlace({
    required String? districtName,
    required String? cityName,
    required LocationPoint placePosition,
    DateTime? now,
  }) async {
    final checkedAt = now ?? DateTime.now();
    final normalizedCity = _normalizeCityName(cityName);
    final json = await _forecastJson(
      checkedAt,
      locationIds: _locationIdsByCity[normalizedCity] ?? _locationIds,
    );
    if (json == null) return null;
    try {
      return CwaForecast.fromJsonForLocation(
        json,
        districtName: districtName,
        cityName: cityName,
        fallbackPosition: placePosition,
        now: checkedAt,
      );
    } catch (error) {
      lastError = '無法解析 CWA 景點天氣資料：$error';
      return null;
    }
  }

  Future<Map<String, dynamic>?> _forecastJson(
    DateTime now, {
    List<String>? locationIds,
  }) async {
    final requestedIds = locationIds ?? _locationIds;
    final locationIdsKey = requestedIds.join(',');
    if (!isConfigured) {
      lastError = '尚未設定 CWA_API_KEY。';
      return null;
    }
    if (_cachedJson != null &&
        _cachedAt != null &&
        _cachedLocationIdsKey == locationIdsKey &&
        now.difference(_cachedAt!) < _checkInterval) {
      return _cachedJson;
    }
    final pending = _inFlightRequest;
    if (pending != null) return pending;
    final request = _fetchForecastJson(now, requestedIds, locationIdsKey);
    _inFlightRequest = request;
    try {
      return await request;
    } finally {
      _inFlightRequest = null;
    }
  }

  Future<Map<String, dynamic>?> _fetchForecastJson(
    DateTime now,
    List<String> locationIds,
    String locationIdsKey,
  ) async {
    lastError = null;
    try {
      final response = await _client.get(
        Uri.parse(_endpoint).replace(
          queryParameters: <String, dynamic>{
            'Authorization': apiKey,
            'format': 'JSON',
            'locationId': locationIds.join(','),
            'ElementName': [
              '天氣預報綜合描述',
              '天氣現象',
              '3小時降雨機率',
              '體感溫度',
              '最高溫度',
              '最低溫度',
              '紫外線指數',
            ].join(','),
          },
        ),
      );
      if (response.statusCode != 200) {
        lastError = 'CWA 查詢失敗（HTTP ${response.statusCode}）。';
        return null;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      _cachedAt = now;
      _cachedJson = json;
      _cachedLocationIdsKey = locationIdsKey;
      return json;
    } catch (error) {
      lastError = '無法讀取 CWA 天氣資料：$error';
      return null;
    }
  }

  static String _normalizeCityName(String? value) =>
      (value ?? '').trim().replaceAll('台', '臺');

  void dispose() => _client.close();
}

class CwaForecast {
  final String? cityName;
  final String? locationName;
  final String? weatherDescription;
  final double? precipitationProbability;
  final double? apparentTemperature;
  final double? uvIndex;
  final double? maximumTemperature;
  final double? minimumTemperature;

  const CwaForecast({
    this.cityName,
    this.locationName,
    this.weatherDescription,
    this.precipitationProbability,
    this.apparentTemperature,
    this.uvIndex,
    this.maximumTemperature,
    this.minimumTemperature,
  });

  factory CwaForecast.fromJson(
    Map<String, dynamic> json,
    LocationPoint position,
    DateTime now,
  ) {
    var candidates = _candidates(
      json,
    )..sort((a, b) => _distance(a, position).compareTo(_distance(b, position)));
    if (candidates.isNotEmpty) {
      final selectedName = _normalizeName(candidates.first.locationName);
      candidates = candidates
          .where(
            (candidate) =>
                _normalizeName(candidate.locationName) == selectedName,
          )
          .toList();
    }
    return _fromCandidates(candidates, now);
  }

  factory CwaForecast.fromJsonForLocation(
    Map<String, dynamic> json, {
    required String? districtName,
    required String? cityName,
    required LocationPoint fallbackPosition,
    required DateTime now,
  }) {
    final all = _candidates(json);
    final district = _normalizeName(districtName);
    final city = _normalizeName(cityName);
    var candidates = all
        .where(
          (candidate) =>
              district.isNotEmpty &&
              _normalizeName(candidate.locationName) == district &&
              (city.isEmpty || _normalizeName(candidate.cityName) == city),
        )
        .toList();
    if (candidates.isEmpty && city.isNotEmpty) {
      candidates =
          all
              .where((candidate) => _normalizeName(candidate.cityName) == city)
              .toList()
            ..sort(
              (a, b) => _distance(
                a,
                fallbackPosition,
              ).compareTo(_distance(b, fallbackPosition)),
            );
    }
    if (candidates.isEmpty) {
      candidates = all
        ..sort(
          (a, b) => _distance(
            a,
            fallbackPosition,
          ).compareTo(_distance(b, fallbackPosition)),
        );
    }
    if (candidates.isNotEmpty) {
      candidates.sort(
        (a, b) => _distance(
          a,
          fallbackPosition,
        ).compareTo(_distance(b, fallbackPosition)),
      );
      final selectedName = _normalizeName(candidates.first.locationName);
      candidates = candidates
          .where(
            (candidate) =>
                _normalizeName(candidate.locationName) == selectedName,
          )
          .toList();
    }
    return _fromCandidates(candidates, now);
  }

  static List<_ForecastCandidate> _candidates(Map<String, dynamic> json) {
    final records = json['records'] as Map?;
    final locations =
        (records?['Locations'] ?? records?['locations']) as List? ?? const [];
    final candidates = <_ForecastCandidate>[];
    for (final group in locations) {
      final groupMap = group as Map;
      final cityName = (groupMap['LocationsName'] ?? groupMap['locationsName'])
          ?.toString();
      final towns =
          (groupMap['Location'] ?? groupMap['location']) as List? ?? const [];
      for (final town in towns) {
        final item = Map<String, dynamic>.from(town as Map);
        final lat = double.tryParse(
          '${item['Latitude'] ?? item['lat'] ?? item['latitude']}',
        );
        final lon = double.tryParse(
          '${item['Longitude'] ?? item['lon'] ?? item['longitude']}',
        );
        if (lat == null || lon == null) continue;
        candidates.add(
          _ForecastCandidate(
            item: item,
            cityName: cityName,
            locationName: (item['LocationName'] ?? item['locationName'])
                ?.toString(),
            latitude: lat,
            longitude: lon,
          ),
        );
      }
    }
    return candidates;
  }

  static CwaForecast _fromCandidates(
    List<_ForecastCandidate> candidates,
    DateTime now,
  ) {
    final closest = candidates.firstOrNull;
    Object? rawValueFor(Set<String> names) {
      for (final candidate in candidates) {
        final elements =
            (candidate.item['WeatherElement'] ??
                    candidate.item['weatherElement'])
                as List? ??
            const [];
        for (final raw in elements) {
          final element = raw as Map;
          final elementName = element['ElementName'] ?? element['elementName'];
          if (!names.contains(elementName)) continue;
          final times =
              (element['Time'] ?? element['time']) as List? ?? const [];
          final active = times.cast<Map?>().firstWhere(
            (time) => time != null && _covers(time, now),
            orElse: () => times.isEmpty ? null : times.first as Map,
          );
          final value = active?['ElementValue'] ?? active?['elementValue'];
          return value is List && value.isNotEmpty ? value.first : value;
        }
      }
      return null;
    }

    double? valueFor(Set<String> names) {
      final rawValue = rawValueFor(names);
      if (rawValue is Map) {
        final value = _mapScalar(rawValue);
        return value == null ? null : double.tryParse('$value');
      }
      return double.tryParse('$rawValue');
    }

    String? textFor(Set<String> names) {
      final rawValue = rawValueFor(names);
      if (rawValue is Map) {
        final value = _mapScalar(rawValue);
        return value == null ? null : '$value';
      }
      return rawValue == null ? null : '$rawValue';
    }

    return CwaForecast(
      cityName: closest?.cityName,
      locationName: closest?.locationName ?? closest?.cityName,
      weatherDescription: textFor({'天氣預報綜合描述', '天氣現象', 'Wx'}),
      precipitationProbability: valueFor({'3小時降雨機率', '降雨機率', 'PoP3h', 'PoP'}),
      apparentTemperature: valueFor({'體感溫度', '溫度', 'AT', 'T'}),
      uvIndex: valueFor({'紫外線指數', 'UVI', 'UVIndex'}),
      maximumTemperature: valueFor({'最高溫度', 'MaxT'}),
      minimumTemperature: valueFor({'最低溫度', 'MinT'}),
    );
  }

  static double _distance(
    _ForecastCandidate candidate,
    LocationPoint position,
  ) =>
      (pow(candidate.latitude - position.latitude, 2) +
              pow(candidate.longitude - position.longitude, 2))
          .toDouble();

  static String _normalizeName(String? value) =>
      (value ?? '').trim().replaceAll('台', '臺');

  static bool _covers(Map time, DateTime now) {
    final start = DateTime.tryParse(
      '${time['StartTime'] ?? time['startTime']}',
    );
    final end = DateTime.tryParse('${time['EndTime'] ?? time['endTime']}');
    return start != null &&
        end != null &&
        !now.isBefore(start) &&
        now.isBefore(end);
  }

  static Object? _mapScalar(Map value) {
    final preferred = value['value'] ?? value['measures'];
    if (preferred != null) return preferred;
    for (final candidate in value.values) {
      if (candidate is String || candidate is num) return candidate;
    }
    return null;
  }
}

class _ForecastCandidate {
  final Map<String, dynamic> item;
  final String? cityName;
  final String? locationName;
  final double latitude;
  final double longitude;

  const _ForecastCandidate({
    required this.item,
    required this.cityName,
    required this.locationName,
    required this.latitude,
    required this.longitude,
  });
}

class WeatherCheckResult {
  final CwaForecast forecast;
  final List<WeatherAdvisory> advisories;

  const WeatherCheckResult({required this.forecast, required this.advisories});
}

class WeatherAdvisory {
  final String kind;
  final String title;
  final String body;
  final WeatherRiskLevel level;

  const WeatherAdvisory({
    required this.kind,
    required this.title,
    required this.body,
    required this.level,
  });

  static List<WeatherAdvisory> evaluate(CwaForecast forecast) {
    final alerts = <WeatherAdvisory>[];

    final rain = forecast.precipitationProbability;
    final uv = forecast.uvIndex;
    final temperature = forecast.apparentTemperature;
    final description = forecast.weatherDescription ?? '';

    // 雷雨、豪雨等文字型風險
    final hasSevereRainDescription = const [
      '雷雨',
      '豪雨',
      '大雨',
      '暴雨',
    ].any(description.contains);

    if (hasSevereRainDescription) {
      alerts.add(
        WeatherAdvisory(
          kind: 'storm',
          title: '天氣狀況可能影響戶外行程',
          body: '氣象預報包含雷雨或較強降雨，建議準備室內備案。',
          level: WeatherRiskLevel.severe,
        ),
      );
    }

    // 降雨機率
    if (rain != null && rain >= 80) {
      alerts.add(
        WeatherAdvisory(
          kind: 'rain',
          title: '降雨機率很高',
          body: '目前降雨機率為 ${rain.round()}%，建議調整戶外行程。',
          level: WeatherRiskLevel.severe,
        ),
      );
    } else if (rain != null && rain >= 50) {
      alerts.add(
        WeatherAdvisory(
          kind: 'rain',
          title: '稍後可能下雨',
          body: '目前降雨機率為 ${rain.round()}%，建議攜帶雨具並準備備案。',
          level: WeatherRiskLevel.warning,
        ),
      );
    }

    // 紫外線
    if (uv != null && uv >= 11) {
      alerts.add(
        WeatherAdvisory(
          kind: 'uv',
          title: '紫外線極強',
          body: '紫外線指數為 ${uv.toStringAsFixed(0)}，不建議長時間進行戶外活動。',
          level: WeatherRiskLevel.severe,
        ),
      );
    } else if (uv != null && uv >= 8) {
      alerts.add(
        WeatherAdvisory(
          kind: 'uv',
          title: '紫外線很強',
          body: '紫外線指數為 ${uv.toStringAsFixed(0)}，請做好防曬並避免長時間曝曬。',
          level: WeatherRiskLevel.warning,
        ),
      );
    }

    // 體感溫度
    if (temperature != null && temperature >= 36) {
      alerts.add(
        WeatherAdvisory(
          kind: 'heat',
          title: '體感溫度過高',
          body: '目前體感溫度約 ${temperature.round()}°C，戶外活動可能有熱傷害風險。',
          level: WeatherRiskLevel.severe,
        ),
      );
    } else if (temperature != null && temperature >= 33) {
      alerts.add(
        WeatherAdvisory(
          kind: 'heat',
          title: '天氣炎熱',
          body: '目前體感溫度約 ${temperature.round()}°C，請補充水分並適度休息。',
          level: WeatherRiskLevel.warning,
        ),
      );
    }

    return alerts;
  }

  static bool shouldOfferIndoorAlternative(Iterable<WeatherAdvisory> alerts) {
    return alerts.any(
      (alert) =>
          alert.kind == 'rain' || alert.kind == 'storm' || alert.kind == 'uv',
    );
  }
}

class WeatherItineraryPlace {
  final String occurrenceId;
  final String placeId;
  final String name;
  final String category;
  final List<String> tags;
  final String address;
  final String county;
  final int startMinutes;
  final int endMinutes;
  final bool locked;

  /// indoor、mixed、outdoor
  final String exposure;

  final bool affected;
  final List<String> impactReasons;

  const WeatherItineraryPlace({
    required this.occurrenceId,
    required this.placeId,
    required this.name,
    required this.category,
    required this.tags,
    required this.address,
    required this.county,
    required this.startMinutes,
    required this.endMinutes,
    required this.locked,
    required this.exposure,
    required this.affected,
    required this.impactReasons,
  });

  Map<String, dynamic> toJson() {
    return {
      'occurrenceId': occurrenceId,
      'placeId': placeId,
      'name': name,
      'category': category,
      'tags': tags,
      'address': address,
      'county': county,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'locked': locked,
      'exposure': exposure,
      'affected': affected,
      'impactReasons': impactReasons,
    };
  }
}

/// Input passed to the AI/recommendation layer when the traveller asks for an
/// indoor alternative.  The weather feature owns the trigger, while the
/// itinerary recommendation implementation remains replaceable.
class WeatherIndoorItineraryRequest {
  final List<WeatherAdvisory> advisories;
  final DateTime requestedAt;

  final int dayNumber;
  final DateTime dayDate;

  final String tripLocation;
  final int people;
  final int budget_level;
  final List<String> preferences;

  final double? currentLatitude;
  final double? currentLongitude;

  final String preferencePrompt;

  /// 今天尚未結束的完整行程，不只是受影響景點。
  final List<WeatherItineraryPlace> remainingPlaces;

  const WeatherIndoorItineraryRequest({
    required this.advisories,
    required this.requestedAt,
    this.dayNumber = 1,
    required this.dayDate,
    this.tripLocation = '',
    this.people = 1,
    this.budget_level = 1,
    this.preferences = const [],
    this.currentLatitude,
    this.currentLongitude,
    this.preferencePrompt = '',
    this.remainingPlaces = const [],
  });

  List<String> get reasons =>
      advisories.map((advisory) => advisory.title).toList(growable: false);

  List<WeatherItineraryPlace> get affectedPlaces =>
      remainingPlaces.where((place) => place.affected).toList(growable: false);

  Map<String, dynamic> toJson() {
    return {
      'requestedAt': requestedAt.toIso8601String(),
      'dayNumber': dayNumber,
      'dayDate': dayDate.toIso8601String(),
      'trip': {
        'location': tripLocation,
        'people': people,
        'budget_level': budget_level,
        'preferences': preferences,
        'preferencePrompt': preferencePrompt,
      },
      'currentLocation': {
        'latitude': currentLatitude,
        'longitude': currentLongitude,
      },
      'weather': advisories
          .map(
            (advisory) => {
              'kind': advisory.kind,
              'title': advisory.title,
              'body': advisory.body,
              'level': advisory.level.name,
            },
          )
          .toList(growable: false),
      'remainingPlaces': remainingPlaces
          .map((place) => place.toJson())
          .toList(growable: false),
    };
  }
}
