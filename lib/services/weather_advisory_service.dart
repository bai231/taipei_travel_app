import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'location_service.dart';
import 'trip_notification_service.dart';

/// CWA forecast client and travel-only advisory evaluator.
///
/// The CWA key is intentionally supplied at build time, never committed to the
/// app. See `docs/weather-alerts.md` for production delivery requirements.
class WeatherAdvisoryService {
  static const _endpoint =
      'https://opendata.cwa.gov.tw/api/v1/rest/datastore/F-D0047-093';
  static const _checkInterval = Duration(hours: 1);

  final String apiKey;
  final http.Client _client;
  final TripNotificationService _notifications;
  DateTime? _lastCheck;
  final Set<String> _sentKinds = <String>{};

  WeatherAdvisoryService({
    required this.apiKey,
    http.Client? client,
    TripNotificationService? notifications,
  }) : _client = client ?? http.Client(),
       _notifications = notifications ?? TripNotificationService();

  bool get isConfigured => apiKey.isNotEmpty;

  Future<void> check(LocationPoint position, {DateTime? now}) async {
    if (!isConfigured) return;
    final checkedAt = now ?? DateTime.now();
    if (_lastCheck != null && checkedAt.difference(_lastCheck!) < _checkInterval) {
      return;
    }
    _lastCheck = checkedAt;
    try {
      final response = await _client.get(
        Uri.parse(_endpoint).replace(queryParameters: {
          'Authorization': apiKey,
          'format': 'JSON',
          // Reduces payload while retaining fields used by the evaluator.
          'ElementName': '3小時降雨機率,降雨機率,體感溫度,溫度,紫外線指數,UVI',
        }),
      );
      if (response.statusCode != 200) return;
      final forecast = CwaForecast.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
        position,
        checkedAt,
      );
      for (final advisory in WeatherAdvisory.evaluate(forecast)) {
        if (!_sentKinds.add(advisory.kind)) continue;
        await _notifications.showWeatherAdvisory(
          id: 7100 + advisory.kind.hashCode.abs() % 100,
          title: advisory.title,
          body: advisory.body,
        );
      }
    } catch (_) {
      // Weather advice must never interrupt GPS itinerary tracking.
    }
  }

  void dispose() => _client.close();
}

class CwaForecast {
  final double? precipitationProbability;
  final double? apparentTemperature;
  final double? uvIndex;

  const CwaForecast({this.precipitationProbability, this.apparentTemperature, this.uvIndex});

  factory CwaForecast.fromJson(
    Map<String, dynamic> json,
    LocationPoint position,
    DateTime now,
  ) {
    final locations = ((json['records'] as Map?)?['locations'] as List?) ?? const [];
    Map<String, dynamic>? closest;
    var closestDistance = double.infinity;
    for (final group in locations) {
      final towns = (group as Map)['location'] as List? ?? const [];
      for (final town in towns) {
        final item = Map<String, dynamic>.from(town as Map);
        final lat = double.tryParse('${item['lat'] ?? item['latitude']}');
        final lon = double.tryParse('${item['lon'] ?? item['longitude']}');
        if (lat == null || lon == null) continue;
        final distance = pow(lat - position.latitude, 2) + pow(lon - position.longitude, 2);
        if (distance < closestDistance) {
          closest = item;
          closestDistance = distance.toDouble();
        }
      }
    }
    final elements = (closest?['weatherElement'] as List?) ?? const [];
    double? valueFor(Set<String> names) {
      for (final raw in elements) {
        final element = raw as Map;
        if (!names.contains(element['elementName'])) continue;
        final times = element['time'] as List? ?? const [];
        final active = times.cast<Map?>().firstWhere(
          (time) => time != null && _covers(time, now),
          orElse: () => times.isEmpty ? null : times.first as Map,
        );
        final value = active?['elementValue'];
        final rawValue = value is List && value.isNotEmpty ? value.first : value;
        if (rawValue is Map) {
          return double.tryParse('${rawValue['value'] ?? rawValue['measures']}');
        }
        return double.tryParse('$rawValue');
      }
      return null;
    }
    return CwaForecast(
      precipitationProbability: valueFor({'3小時降雨機率', '降雨機率', 'PoP3h', 'PoP'}),
      apparentTemperature: valueFor({'體感溫度', '溫度', 'AT', 'T'}),
      uvIndex: valueFor({'紫外線指數', 'UVI', 'UVIndex'}),
    );
  }

  static bool _covers(Map time, DateTime now) {
    final start = DateTime.tryParse('${time['startTime']}');
    final end = DateTime.tryParse('${time['endTime']}');
    return start != null && end != null && !now.isBefore(start) && now.isBefore(end);
  }
}

class WeatherAdvisory {
  final String kind;
  final String title;
  final String body;
  const WeatherAdvisory(this.kind, this.title, this.body);

  static List<WeatherAdvisory> evaluate(CwaForecast forecast) {
    final alerts = <WeatherAdvisory>[];
    if ((forecast.precipitationProbability ?? 0) >= 50) {
      alerts.add(const WeatherAdvisory('rain', '稍後可能下雨', '未來幾小時降雨機率偏高，出門請攜帶雨具。'));
    }
    if ((forecast.uvIndex ?? 0) >= 8) {
      alerts.add(const WeatherAdvisory('uv', '紫外線很強', '今天紫外線偏強，請做好防曬並避免長時間曝曬。'));
    }
    if ((forecast.apparentTemperature ?? -100) >= 33) {
      alerts.add(const WeatherAdvisory('heat', '天氣炎熱', '今日體感溫度偏高，請補充水分並留意熱傷害。'));
    }
    return alerts;
  }
}
