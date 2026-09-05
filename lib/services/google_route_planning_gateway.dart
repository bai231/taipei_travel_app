import '../features/route_planning/models/route_travel_mode.dart';
import '../models/tdx_route.dart';

abstract interface class GoogleRoutePlanningGateway {
  Future<TdxRoute?> getRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required DateTime requestedDeparture,
    required RouteTravelMode travelMode,
  });
}
