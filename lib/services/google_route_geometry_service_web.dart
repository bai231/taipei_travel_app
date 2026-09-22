import 'dart:convert';
import 'dart:js_interop';

import '../models/route_geometry_segment.dart';
import '../features/route_planning/models/route_travel_mode.dart';
import 'route_geometry_gateway.dart';
import 'google_route_request_cache.dart';

@JS('computeTransitRouteGeometry')
external JSPromise<JSString> _computeTransitRouteGeometry(JSString requestJson);

class GoogleRouteGeometryService implements RouteGeometryGateway {
  const GoogleRouteGeometryService();

  @override
  Future<List<RouteGeometrySegment>> getRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required DateTime departureTime,
    required RouteTravelMode travelMode,
  }) async {
    final request = GoogleRouteRequestCache.request(
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      departureTime: departureTime,
      travelMode: travelMode,
    );
    return GoogleRouteRequestCache.shared.get(
      'geometry:$request',
      () => _load(request),
      canCache: (segments) => segments.isNotEmpty,
    );
  }

  Future<List<RouteGeometrySegment>> _load(String request) async {
    final response = (await _computeTransitRouteGeometry(
      request.toJS,
    ).toDart).toDart;
    final decoded = jsonDecode(response) as List<dynamic>;
    final segments = decoded
        .whereType<Map<String, dynamic>>()
        .map(RouteGeometrySegment.fromJson)
        .where((segment) => segment.points.length >= 2)
        .toList();
    return segments;
  }
}
