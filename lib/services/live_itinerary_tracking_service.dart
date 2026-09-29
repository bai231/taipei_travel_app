import 'dart:async';
import 'dart:math';

import '../algorithm/route_optimizer.dart';
import '../features/route_planning/models/route_day.dart';
import '../features/route_planning/models/route_itinerary.dart';
import '../features/route_planning/models/route_travel_mode.dart';
import '../features/route_planning/models/route_visit.dart';
import '../features/route_planning/models/travel_leg.dart';
import '../models/scheduled_visit.dart';
import 'location_service.dart';

class TripDelayAlert {
  final int lateMinutes;
  final String nextStopName;

  const TripDelayAlert({required this.lateMinutes, required this.nextStopName});
}

class TripTrackingUpdate {
  final LocationPoint location;
  final List<LocationPoint> route;
  final TripDelayAlert? delayAlert;
  final DateTime observedAt;

  const TripTrackingUpdate({
    required this.location,
    required this.route,
    required this.observedAt,
    this.delayAlert,
  });
}

enum DebugDelayScenario { stayTooLong, farFromNextStop }

/// Tracks an active itinerary while the app is running and raises one alert per
/// 15-minute window when the traveller is materially behind the current plan.
class LiveItineraryTrackingService {
  final LocationTrackingGateway _locationGateway;
  final DateTime Function() _now;
  final StreamController<TripTrackingUpdate> _updates =
      StreamController.broadcast();
  final List<LocationPoint> _route = [];
  StreamSubscription<LocationPoint>? _subscription;
  RouteItinerary? _itinerary;
  DateTime? _lastAlertAt;

  LiveItineraryTrackingService({
    LocationTrackingGateway? locationGateway,
    DateTime Function()? now,
  }) : _locationGateway = locationGateway ?? LocationService(),
       _now = now ?? DateTime.now;

  Stream<TripTrackingUpdate> get updates => _updates.stream;
  bool get isTracking => _subscription != null;

  Future<bool> start(RouteItinerary itinerary) async {
    _itinerary = itinerary;
    final location = await _locationGateway.getCurrentLocation();
    if (location == null) return false;
    _record(location);
    _subscription = _locationGateway.watchLocation().listen(
      _record,
      onError: (_) {},
    );
    return true;
  }

  void updateItinerary(RouteItinerary itinerary) => _itinerary = itinerary;

  void _record(LocationPoint location) {
    _recordAt(location, _now());
  }

  void _recordAt(LocationPoint location, DateTime observedAt) {
    _route.add(location);
    if (_route.length > 500) _route.removeAt(0);
    final alert = _delayFor(location, observedAt);
    if (alert != null) _lastAlertAt = observedAt;
    _updates.add(
      TripTrackingUpdate(
        location: location,
        route: List.unmodifiable(_route),
        observedAt: observedAt,
        delayAlert: alert,
      ),
    );
  }

  /// Sends a synthetic GPS/time update through the same delay detector used by
  /// live tracking. This is intentionally available only to debug callers.
  void simulateDelay({
    required RouteItinerary itinerary,
    required DebugDelayScenario scenario,
    required int delayMinutes,
  }) {
    assert(() {
      if (delayMinutes < 15) {
        throw ArgumentError.value(delayMinutes, 'delayMinutes', 'must be >= 15');
      }
      return true;
    }());

    _itinerary = itinerary;
    final today = DateTime.now();
    final day = itinerary.days
        .where((item) => _sameDate(item.date, today))
        .firstOrNull;
    if (day == null || day.visits.isEmpty) return;

    switch (scenario) {
      case DebugDelayScenario.stayTooLong:
        // Prefer a stop with a remaining visit, so the simulation can show the
        // timetable being rearranged as well as the delay notification.
        final visit = day.visits
            .where((item) => item.endMinutes + delayMinutes < 24 * 60)
            .firstOrNull;
        if (visit == null) return;
        final observedAt = _atMinute(day.date, visit.endMinutes + delayMinutes);
        _recordAt(
          LocationPoint(
            latitude: visit.place.latitude,
            longitude: visit.place.longitude,
          ),
          observedAt,
        );
        break;
      case DebugDelayScenario.farFromNextStop:
        final next = day.visits
            .where((item) => item.startMinutes > 0)
            .firstOrNull;
        if (next == null) return;
        // The live detector defines the next stop as one whose start is still
        // ahead of the clock, so set the fake clock one minute before it.
        final observedAt = _atMinute(day.date, next.startMinutes - 1);
        // At the tracker estimate (18 km/h plus 8 minutes), this is at least
        // the selected delay beyond the next stop's planned start.
        final distanceKm = max(0.1, (delayMinutes + 1 - 8) * 18 / 60 + 0.1);
        final latitudeOffset = distanceKm / 111.0;
        _recordAt(
          LocationPoint(
            latitude: next.place.latitude + latitudeOffset,
            longitude: next.place.longitude,
          ),
          observedAt,
        );
        break;
    }
  }

  TripDelayAlert? _delayFor(LocationPoint location, DateTime now) {
    final itinerary = _itinerary;
    if (itinerary == null ||
        (_lastAlertAt != null &&
            now.difference(_lastAlertAt!) < const Duration(minutes: 15))) {
      return null;
    }
    final day = itinerary.days
        .where((day) => _sameDate(day.date, now))
        .firstOrNull;
    if (day == null || day.visits.isEmpty) return null;
    final minute = now.hour * 60 + now.minute;
    final active = day.visits.where(
      (visit) => minute >= visit.startMinutes && minute >= visit.endMinutes,
    );
    final overdueVisit = active
        .where(
          (visit) =>
              _distanceKm(
                location.latitude,
                location.longitude,
                visit.place.latitude,
                visit.place.longitude,
              ) <=
              .25,
        )
        .firstOrNull;
    if (overdueVisit != null) {
      final late = minute - overdueVisit.endMinutes;
      if (late >= 15) {
        final next = day.visits.skip(overdueVisit.sequence).firstOrNull;
        return TripDelayAlert(
          lateMinutes: late,
          nextStopName: next?.label ?? overdueVisit.label,
        );
      }
    }

    final next = day.visits
        .where((visit) => visit.startMinutes > minute)
        .firstOrNull;
    if (next == null) return null;
    final estimatedArrival = minute + _estimatedTravelMinutes(location, next);
    final late = estimatedArrival - next.startMinutes;
    return late >= 15
        ? TripDelayAlert(lateMinutes: late, nextStopName: next.label)
        : null;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> dispose() async {
    await stop();
    await _updates.close();
  }
}

/// Reorders only the unfinished visits on one day. Completed visits retain their
/// history; the current GPS point becomes the origin of the new remaining route.
class LiveDayItineraryReplanner {
  static const _radians = pi / 180;

  RouteDay replan({
    required RouteDay day,
    required LocationPoint currentLocation,
    required DateTime now,
  }) {
    final minute = now.hour * 60 + now.minute;
    final completed = <RouteVisit>[];
    final remaining = <RouteVisit>[];
    for (final visit in day.visits) {
      final atVisit =
          _distanceKm(
            currentLocation.latitude,
            currentLocation.longitude,
            visit.place.latitude,
            visit.place.longitude,
          ) <=
          .25;
      if (visit.endMinutes <= minute ||
          (atVisit && visit.startMinutes <= minute)) {
        completed.add(visit);
      } else {
        remaining.add(visit);
      }
    }
    if (remaining.isEmpty) return day;

    final origin = RouteStop(
      id: 'live-location-${now.millisecondsSinceEpoch}',
      name: '目前位置',
      latitude: currentLocation.latitude,
      longitude: currentLocation.longitude,
      stayDurationMinutes: 0,
    );
    final ordered = _orderRemaining(remaining, currentLocation);
    final visits = <RouteVisit>[...completed];
    final legs = <TravelLeg>[];
    var previous = origin;
    var cursor = minute;
    for (final original in ordered) {
      final travel = _estimatedTravelMinutesFromStop(previous, original);
      final arrival = cursor + travel;
      final start = original.locked
          ? max(arrival, original.startMinutes)
          : arrival;
      final waiting = start - arrival;
      final end = start + original.stayMinutes;
      final scheduled = ScheduledVisit(
        departureMinutes: cursor,
        arrivalMinutes: arrival,
        visitStartMinutes: start,
        visitEndMinutes: end,
        waitingMinutes: waiting,
        stayMinutes: original.stayMinutes,
      );
      final stop = RouteStop(
        id: original.occurrenceId,
        name: original.label,
        latitude: original.place.latitude,
        longitude: original.place.longitude,
        stayDurationMinutes: original.stayMinutes,
      );
      legs.add(
        TravelLeg(
          origin: previous,
          destination: stop,
          requestedDeparture: DateTime(
            day.date.year,
            day.date.month,
            day.date.day,
          ).add(Duration(minutes: cursor)),
          schedule: scheduled,
          errorMessage: '依目前位置估算的即時交通時間。',
          travelMode: RouteTravelMode.transit,
        ),
      );
      visits.add(
        RouteVisit(
          place: original.place,
          sequence: visits.length + 1,
          arrivalMinutes: arrival,
          startMinutes: start,
          endMinutes: end,
          waitingMinutes: waiting,
          stayMinutes: original.stayMinutes,
          requestedStartMinutes: original.requestedStartMinutes,
          locked: original.locked,
          eventId: original.eventId,
          kind: original.kind,
          preferences: original.preferences,
          mealType: original.mealType,
          information: original.information,
        ),
      );
      previous = stop;
      cursor = end;
    }
    return RouteDay(
      day: day.day,
      date: day.date,
      origin: origin,
      visits: visits,
      travelLegs: legs,
      isValid: true,
      warnings: [
        ...day.warnings,
        '已依 ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} 的目前位置重新安排未完成景點。',
      ],
    );
  }

  List<RouteVisit> _orderRemaining(
    List<RouteVisit> visits,
    LocationPoint origin,
  ) {
    final remaining = List<RouteVisit>.of(visits);
    final result = <RouteVisit>[];
    var latitude = origin.latitude;
    var longitude = origin.longitude;
    while (remaining.isNotEmpty) {
      final locked = remaining.where((visit) => visit.locked).toList();
      final candidates = locked.isNotEmpty ? locked : remaining;
      candidates.sort(
        (a, b) =>
            _distanceKm(
              latitude,
              longitude,
              a.place.latitude,
              a.place.longitude,
            ).compareTo(
              _distanceKm(
                latitude,
                longitude,
                b.place.latitude,
                b.place.longitude,
              ),
            ),
      );
      final next = candidates.first;
      remaining.remove(next);
      result.add(next);
      latitude = next.place.latitude;
      longitude = next.place.longitude;
    }
    return result;
  }

  int _estimatedTravelMinutesFromStop(RouteStop from, RouteVisit to) => max(
    5,
    (_distanceKm(
                  from.latitude,
                  from.longitude,
                  to.place.latitude,
                  to.place.longitude,
                ) /
                18 *
                60 +
            8)
        .ceil(),
  );

  double _distanceKm(double aLat, double aLng, double bLat, double bLng) {
    final latitudeDifference = (bLat - aLat) * _radians;
    final longitudeDifference = (bLng - aLng) * _radians;
    final value =
        sin(latitudeDifference / 2) * sin(latitudeDifference / 2) +
        cos(aLat * _radians) *
            cos(bLat * _radians) *
            sin(longitudeDifference / 2) *
            sin(longitudeDifference / 2);
    return 6371 * 2 * atan2(sqrt(value), sqrt(1 - value));
  }
}

int _estimatedTravelMinutes(LocationPoint from, RouteVisit to) => max(
  5,
  (_distanceKm(
                from.latitude,
                from.longitude,
                to.place.latitude,
                to.place.longitude,
              ) /
              18 *
              60 +
          8)
      .ceil(),
);

double _distanceKm(double aLat, double aLng, double bLat, double bLng) {
  const radians = pi / 180;
  final latitudeDifference = (bLat - aLat) * radians;
  final longitudeDifference = (bLng - aLng) * radians;
  final value =
      sin(latitudeDifference / 2) * sin(latitudeDifference / 2) +
      cos(aLat * radians) *
          cos(bLat * radians) *
          sin(longitudeDifference / 2) *
          sin(longitudeDifference / 2);
  return 6371 * 2 * atan2(sqrt(value), sqrt(1 - value));
}

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _atMinute(DateTime date, int minute) => DateTime(
  date.year,
  date.month,
  date.day,
).add(Duration(minutes: minute));
