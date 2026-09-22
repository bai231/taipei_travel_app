import '../features/route_planning/models/route_travel_mode.dart';
import '../models/route_geometry_segment.dart';
import 'route_geometry_gateway.dart';
import 'google_route_request_cache.dart';
import 'google_routes_native_client.dart';

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
    final response = await GoogleRoutesNativeClient.shared.route(
      GoogleRouteRequestCache.request(
        originLatitude: originLatitude,
        originLongitude: originLongitude,
        destinationLatitude: destinationLatitude,
        destinationLongitude: destinationLongitude,
        departureTime: departureTime,
        travelMode: travelMode,
      ),
    );
    return parseNativeGeometry(response);
  }
}

List<RouteGeometrySegment> parseNativeGeometry(Map<String, dynamic>? response) {
  final segments = <RouteGeometrySegment>[];
  for (final leg in response?['legs'] as List? ?? []) {
    for (final step in leg['steps'] as List? ?? []) {
      final encoded = step['polyline']?['encodedPolyline'] as String?;
      if (encoded == null || encoded.isEmpty) continue;
      final points = decodeRoutePolyline(encoded);
      if (points.length < 2) continue;
      final line = step['transitDetails']?['transitLine'];
      segments.add(
        RouteGeometrySegment(
          travelMode: switch (step['travelMode']) {
            'WALK' => 'WALKING',
            'DRIVE' => 'DRIVING',
            _ => 'TRANSIT',
          },
          vehicleType: line?['vehicle']?['type'] as String?,
          lineName: (line?['nameShort'] ?? line?['name']) as String?,
          lineColor: line?['color'] as String?,
          points: points,
        ),
      );
    }
  }
  return segments;
}
