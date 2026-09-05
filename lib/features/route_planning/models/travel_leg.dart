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

  const TravelLeg({
    required this.origin,
    required this.destination,
    required this.requestedDeparture,
    required this.schedule,
    this.route,
    this.errorMessage,
    this.travelMode = RouteTravelMode.transit,
  });

  bool get usesEstimatedTravelTime => route == null;

  String get routeSourceLabel =>
      usesEstimatedTravelTime ? '估計' : travelMode.sourceLabel;
}
