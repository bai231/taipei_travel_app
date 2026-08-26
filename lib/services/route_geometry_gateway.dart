import '../models/route_geometry_segment.dart';

abstract interface class RouteGeometryGateway {
  Future<List<RouteGeometrySegment>> getTransitRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required DateTime departureTime,
  });
}
