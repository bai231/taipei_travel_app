import '../models/route_geometry_segment.dart';
import '../features/route_planning/models/route_travel_mode.dart';
import 'route_geometry_gateway.dart';

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
    return const [];
  }
}
