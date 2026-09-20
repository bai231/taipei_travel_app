import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/route_geometry_segment.dart';
import 'google_route_request_cache.dart';

/// Android direct REST transport. Web keeps its existing JavaScript bridge.
class GoogleRoutesNativeClient {
  static final shared = GoogleRoutesNativeClient();
  final http.Client client;
  final Future<Map<String, String>> Function() config;
  final GoogleRouteRequestCache _cache = GoogleRouteRequestCache();

  GoogleRoutesNativeClient({
    http.Client? client,
    Future<Map<String, String>> Function()? config,
  }) : client = client ?? http.Client(),
       config = config ?? _androidConfig;

  static Future<Map<String, String>> _androidConfig() async {
    if (!Platform.isAndroid) throw UnsupportedError('此平台尚未支援路線查詢');
    final value = await const MethodChannel(
      'travel_app/routes_config',
    ).invokeMapMethod<String, String>('getConfig');
    return value ?? {};
  }

  Future<Map<String, dynamic>?> route(String request) => _cache.get(
    request,
    () => _load(request),
    canCache: (value) => value != null,
  );

  Future<Map<String, dynamic>?> _load(String request) async {
    final input = jsonDecode(request) as Map<String, dynamic>;
    final mode = switch (input['travelMode']) {
      'WALKING' => 'WALK',
      'DRIVING' => 'DRIVE',
      'TRANSIT' => 'TRANSIT',
      _ => throw ArgumentError('Unsupported travel mode'),
    };
    if (mode == 'TRANSIT') {
      final departure = DateTime.parse(input['departureTime'] as String);
      final now = DateTime.now();
      if (departure.isBefore(now.subtract(const Duration(days: 7))) ||
          departure.isAfter(now.add(const Duration(days: 100)))) {
        throw StateError('路線日期超出查詢範圍，未改用其他日期。');
      }
    }
    final settings = await config();
    if ([
      'apiKey',
      'packageName',
      'certificate',
    ].any((key) => (settings[key] ?? '').isEmpty)) {
      throw StateError('尚未設定 Android Routes API 金鑰。');
    }
    final response = await client
        .post(
          Uri.parse(
            'https://routes.googleapis.com/directions/v2:computeRoutes',
          ),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': settings['apiKey']!,
            'X-Android-Package': settings['packageName']!,
            'X-Android-Cert': settings['certificate']!,
            'X-Goog-FieldMask':
                'routes.duration,routes.distanceMeters,routes.legs.steps.polyline,routes.legs.steps.travelMode,routes.legs.steps.transitDetails.transitLine',
          },
          body: jsonEncode({
            'origin': {
              'location': {'latLng': input['origin']},
            },
            'destination': {
              'location': {'latLng': input['destination']},
            },
            'travelMode': mode,
            'languageCode': 'zh-TW',
            'regionCode': 'TW',
            'polylineQuality': 'HIGH_QUALITY',
            if (mode == 'DRIVE') 'routingPreference': 'TRAFFIC_UNAWARE',
            if (mode == 'TRANSIT') 'departureTime': input['departureTime'],
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      // Do not forward provider bodies, keys or request URLs into UI/snapshots.
      throw StateError('Google Routes HTTP ${response.statusCode}');
    }
    final routes =
        (jsonDecode(response.body) as Map<String, dynamic>)['routes'] as List?;
    return routes == null || routes.isEmpty
        ? null
        : routes.first as Map<String, dynamic>;
  }
}

List<RouteGeometryPoint> decodeRoutePolyline(String encoded) {
  var index = 0, latitude = 0, longitude = 0;
  int component() {
    var result = 0, shift = 0;
    while (true) {
      if (index >= encoded.length || shift > 30) {
        throw const FormatException('Invalid route polyline');
      }
      final value = encoded.codeUnitAt(index++) - 63;
      if (value < 0 || value > 63) {
        throw const FormatException('Invalid route polyline');
      }
      result |= (value & 31) << shift;
      shift += 5;
      if (value < 32) break;
    }
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  final points = <RouteGeometryPoint>[];
  while (index < encoded.length) {
    latitude += component();
    longitude += component();
    points.add(
      RouteGeometryPoint(latitude: latitude / 1e5, longitude: longitude / 1e5),
    );
  }
  return points;
}
