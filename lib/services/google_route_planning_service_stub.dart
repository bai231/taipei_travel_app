import '../features/route_planning/models/route_travel_mode.dart';
import '../models/tdx_route.dart';
import 'google_route_planning_gateway.dart';

class GoogleRoutePlanningService implements GoogleRoutePlanningGateway {
  const GoogleRoutePlanningService();

  @override
  Future<TdxRoute?> getRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required DateTime requestedDeparture,
    required RouteTravelMode travelMode,
  }) {
    throw UnsupportedError('Google Routes 排程目前只支援 Web。');
  }
}
