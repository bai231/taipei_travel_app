import '../features/route_planning/models/route_travel_mode.dart';
import '../models/tdx_route.dart';

TdxRoute? parseGoogleRouteInformation({
  required Map<String, dynamic>? response,
  required DateTime requestedDeparture,
  required RouteTravelMode travelMode,
}) {
  if (response == null) return null;
  final durationMillis = (response['durationMillis'] as num?)?.toInt() ?? 0;
  if (durationMillis <= 0) return null;
  final travelSeconds = (durationMillis / 1000).ceil();
  final distanceMeters = (response['distanceMeters'] as num?)?.toInt();
  return TdxRoute(
    transfers: 0,
    travelTime: travelSeconds,
    startTime: requestedDeparture,
    endTime: requestedDeparture.add(Duration(seconds: travelSeconds)),
    distanceMeters: distanceMeters,
    sections: [
      RouteSection(
        mode: travelMode.sectionMode,
        travelTime: travelSeconds,
        stopCount: 0,
        intermediateStops: const [],
      ),
    ],
  );
}
