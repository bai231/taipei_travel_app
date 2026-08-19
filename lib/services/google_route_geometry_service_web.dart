import 'dart:convert';
import 'dart:js_interop';

import '../models/route_geometry_segment.dart';
import 'route_geometry_gateway.dart';

@JS('computeTransitRouteGeometry')
external JSPromise<JSString> _computeTransitRouteGeometry(JSString requestJson);

class GoogleRouteGeometryService implements RouteGeometryGateway {
  static final Map<String, List<RouteGeometrySegment>> _cache = {};

  const GoogleRouteGeometryService();

  @override
  Future<List<RouteGeometrySegment>> getTransitRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required DateTime departureTime,
  }) async {
    final request = jsonEncode({
      'origin': {'latitude': originLatitude, 'longitude': originLongitude},
      'destination': {
        'latitude': destinationLatitude,
        'longitude': destinationLongitude,
      },
      'departureTime': departureTime.toUtc().toIso8601String(),
    });
    final cached = _cache[request];
    if (cached != null) return cached;

    final response = (await _computeTransitRouteGeometry(
      request.toJS,
    ).toDart).toDart;
    final decoded = jsonDecode(response) as List<dynamic>;
    final segments = decoded
        .whereType<Map<String, dynamic>>()
        .map(RouteGeometrySegment.fromJson)
        .where((segment) => segment.points.length >= 2)
        .toList();
    _cache[request] = segments;
    return segments;
  }
}
