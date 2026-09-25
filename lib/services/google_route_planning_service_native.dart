import '../features/route_planning/models/route_travel_mode.dart';
import '../models/tdx_route.dart';
import 'google_route_planning_gateway.dart';
import 'google_route_planning_response.dart';
import 'google_route_request_cache.dart';
import 'google_routes_native_client.dart';

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
  }) async {
    if (travelMode == RouteTravelMode.transit) {
      throw ArgumentError('大眾運輸排程使用 TDX');
    }
    final response = await GoogleRoutesNativeClient.shared.route(
      GoogleRouteRequestCache.request(
        originLatitude: originLatitude,
        originLongitude: originLongitude,
        destinationLatitude: destinationLatitude,
        destinationLongitude: destinationLongitude,
        departureTime: requestedDeparture,
        travelMode: travelMode,
      ),
    );
    if (response == null) return null;
    final seconds =
        double.tryParse(
          (response['duration'] as String? ?? '').replaceFirst(
            RegExp(r's$'),
            '',
          ),
        ) ??
        0;
    return parseGoogleRouteInformation(
      response: {
        'durationMillis': seconds * 1000,
        'distanceMeters': response['distanceMeters'],
      },
      requestedDeparture: requestedDeparture,
      travelMode: travelMode,
    );
  }
}
