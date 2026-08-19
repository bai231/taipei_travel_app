import '../models/route_geometry_segment.dart';
import 'route_geometry_gateway.dart';

class GoogleRouteGeometryService implements RouteGeometryGateway {
  const GoogleRouteGeometryService();

  @override
  Future<List<RouteGeometrySegment>> getTransitRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required DateTime departureTime,
  }) async {
    return const [];
  }
}
