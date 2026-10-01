import '../features/route_planning/models/route_day.dart';
import '../models/tdx_route.dart';
import 'location_service.dart';
import 'tdx_service.dart';
import 'transit_realtime_monitor.dart';

/// Locates the correct live origin for a transit risk and queries selectable
/// TDX options. Candidate rebuilding is centralized in
/// [LiveItineraryAlternativePlanner].
class TransitAlternativeService {
  final TdxRoutingGateway routingGateway;

  const TransitAlternativeService({required this.routingGateway});

  ({LocationPoint origin, DateTime departure}) startForRisk({
    required RouteDay day,
    required TransitConnectionRisk risk,
    required LocationPoint currentLocation,
    required DateTime now,
  }) {
    final leg = day.travelLegs[risk.affectedSection.legIndex];
    final previousVisit = day.visits.where(
      (visit) => visit.occurrenceId == leg.origin.id,
    );
    if (risk.incomingSection == null && previousVisit.isNotEmpty) {
      final visit = previousVisit.first;
      final visitEnd = DateTime(
        day.date.year,
        day.date.month,
        day.date.day,
      ).add(Duration(minutes: visit.endMinutes));
      if (visitEnd.isAfter(now)) {
        // A future leg begins where the preceding visit finishes, not at the
        // user's current GPS position while that visit is still scheduled.
        return (
          origin: LocationPoint(
            latitude: leg.origin.latitude,
            longitude: leg.origin.longitude,
          ),
          departure: visitEnd,
        );
      }
    }
    return (
      origin: originForRisk(risk, currentLocation),
      departure: departureForRisk(risk, now),
    );
  }

  LocationPoint originForRisk(
    TransitConnectionRisk risk,
    LocationPoint currentLocation,
  ) {
    final incoming = risk.incomingSection?.section;
    if (incoming?.arrivalLatitude == null ||
        incoming?.arrivalLongitude == null ||
        risk.expectedReadyAt == null) {
      return currentLocation;
    }
    return LocationPoint(
      latitude: incoming!.arrivalLatitude!,
      longitude: incoming.arrivalLongitude!,
    );
  }

  DateTime departureForRisk(TransitConnectionRisk risk, DateTime now) {
    final readyAt = risk.expectedReadyAt;
    return risk.incomingSection != null &&
            readyAt != null &&
            readyAt.isAfter(now)
        ? readyAt
        : now;
  }

  Future<List<TdxRoute>> options({
    required RouteDay day,
    required TransitConnectionRisk risk,
    required LocationPoint currentLocation,
    required DateTime now,
  }) {
    final leg = day.travelLegs[risk.affectedSection.legIndex];
    final start = startForRisk(
      day: day,
      risk: risk,
      currentLocation: currentLocation,
      now: now,
    );
    return routingGateway.getRoutingOptions(
      origin: '${start.origin.latitude},${start.origin.longitude}',
      destination: '${leg.destination.latitude},${leg.destination.longitude}',
      departureTime: start.departure,
    );
  }
}
