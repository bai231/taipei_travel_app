import '../models/route_geometry_segment.dart';
import '../features/route_planning/models/route_travel_mode.dart';

abstract interface class RouteGeometryGateway {
  Future<List<RouteGeometrySegment>> getRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required DateTime departureTime,
    required RouteTravelMode travelMode,
  });
}
