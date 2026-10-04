import '../../../algorithm/route_optimizer.dart';
import '../../../models/scheduled_visit.dart';
import '../../../models/tdx_route.dart';
import 'route_travel_mode.dart';

class TravelLeg {
  final RouteStop origin;
  final RouteStop destination;
  final DateTime requestedDeparture;
  final ScheduledVisit schedule;
  final TdxRoute? route;
  final String? errorMessage;
  final RouteTravelMode travelMode;
  final RouteProvider? routeProvider;

  const TravelLeg({
    required this.origin,
    required this.destination,
    required this.requestedDeparture,
    required this.schedule,
    this.route,
    this.errorMessage,
    this.travelMode = RouteTravelMode.transit,
    this.routeProvider,
  });

  bool get usesEstimatedTravelTime => route == null;

  RouteProvider? get effectiveRouteProvider => route == null
      ? null
      : routeProvider ??
            route?.provider ??
            (travelMode == RouteTravelMode.transit
                ? RouteProvider.tdx
                : RouteProvider.google);

  String get routeSourceLabel => switch (effectiveRouteProvider) {
    null => '估計',
    RouteProvider.tdx => 'TDX',
    RouteProvider.google when travelMode == RouteTravelMode.transit =>
      'Google Maps（TDX 備援）',
    RouteProvider.google => 'Google Maps',
  };
}
