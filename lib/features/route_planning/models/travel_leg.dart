import '../../../algorithm/route_optimizer.dart';
import '../../../models/scheduled_visit.dart';
import '../../../models/tdx_route.dart';

class TravelLeg {
  final RouteStop origin;
  final RouteStop destination;
  final DateTime requestedDeparture;
  final ScheduledVisit schedule;
  final TdxRoute? route;
  final String? errorMessage;

  const TravelLeg({
    required this.origin,
    required this.destination,
    required this.requestedDeparture,
    required this.schedule,
    this.route,
    this.errorMessage,
  });

  bool get usesEstimatedTravelTime => route == null;
}
