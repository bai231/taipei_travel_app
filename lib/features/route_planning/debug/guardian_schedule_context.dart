import '../models/route_day.dart';
import '../models/route_itinerary.dart';
import '../models/travel_leg.dart';
import '../../../services/location_service.dart';

enum GuardianSchedulePhase {
  outsideTrip,
  emptyDay,
  beforeFirst,
  travel,
  visit,
  gap,
  afterLast,
}

/// A planned interval, not proof that the traveller has completed it.
class GuardianScheduledSegment {
  final RouteDay day;
  final DateTime start;
  final DateTime end;
  final String label;
  final GuardianSchedulePhase phase;
  final String? detail;
  final LocationPoint location;
  final String locationName;

  const GuardianScheduledSegment({
    required this.day,
    required this.start,
    required this.end,
    required this.label,
    required this.phase,
    required this.location,
    required this.locationName,
    this.detail,
  });
}

class GuardianScheduleContext {
  final RouteDay? day;
  final GuardianSchedulePhase phase;
  final GuardianScheduledSegment? current;
  final GuardianScheduledSegment? next;
  final List<GuardianScheduledSegment> daySegments;

  const GuardianScheduleContext({
    required this.day,
    required this.phase,
    required this.current,
    required this.next,
    required this.daySegments,
  });
}

GuardianScheduleContext guardianScheduleContext(
  RouteItinerary itinerary,
  DateTime now,
) {
  final all = <GuardianScheduledSegment>[
    for (final day in itinerary.days) ...guardianDaySegments(day),
  ]..sort(_compareSegments);
  final active =
      [
        for (final segment in all)
          if (!now.isBefore(segment.start) && now.isBefore(segment.end))
            segment,
      ]..sort((a, b) {
        // If yesterday runs past midnight, prefer an active item belonging to
        // today's own schedule when both days genuinely overlap.
        final aToday = _sameDate(a.day.date, now);
        final bToday = _sameDate(b.day.date, now);
        if (aToday != bToday) return aToday ? -1 : 1;
        if (a.phase != b.phase) {
          return a.phase == GuardianSchedulePhase.visit ? -1 : 1;
        }
        return a.start.compareTo(b.start);
      });
  final current = active.isEmpty ? null : active.first;
  final day =
      current?.day ??
      _firstWhereOrNull(itinerary.days, (item) => _sameDate(item.date, now));
  final next = _firstWhereOrNull(all, (item) => item.start.isAfter(now));
  if (day == null) {
    return GuardianScheduleContext(
      day: null,
      phase: GuardianSchedulePhase.outsideTrip,
      current: null,
      next: next,
      daySegments: const [],
    );
  }
  final segments = all.where((item) => identical(item.day, day)).toList();
  GuardianSchedulePhase phase;
  if (current != null) {
    phase = current.phase;
  } else if (segments.isEmpty) {
    phase = GuardianSchedulePhase.emptyDay;
  } else if (now.isBefore(segments.first.start)) {
    phase = GuardianSchedulePhase.beforeFirst;
  } else if (next != null && identical(next.day, day)) {
    phase = GuardianSchedulePhase.gap;
  } else {
    phase = GuardianSchedulePhase.afterLast;
  }
  return GuardianScheduleContext(
    day: day,
    phase: phase,
    current: current,
    next: next,
    daySegments: segments,
  );
}

List<GuardianScheduledSegment> guardianDaySegments(RouteDay day) {
  final midnight = DateTime(day.date.year, day.date.month, day.date.day);
  DateTime at(int minute) => midnight.add(Duration(minutes: minute));
  final segments = <GuardianScheduledSegment>[
    for (final leg in day.travelLegs)
      if (leg.schedule.arrivalMinutes > leg.schedule.departureMinutes)
        GuardianScheduledSegment(
          day: day,
          start: at(leg.schedule.departureMinutes),
          end: at(leg.schedule.arrivalMinutes),
          label: '${leg.origin.name} → ${leg.destination.name}',
          phase: GuardianSchedulePhase.travel,
          detail: leg.travelMode.label,
          location: _travelStartLocation(leg),
          locationName: _travelStartName(leg),
        ),
    for (final visit in day.visits)
      if (visit.endMinutes > visit.startMinutes)
        GuardianScheduledSegment(
          day: day,
          start: at(visit.startMinutes),
          end: at(visit.endMinutes),
          label: visit.label,
          phase: GuardianSchedulePhase.visit,
          location: LocationPoint(
            latitude: visit.place.latitude,
            longitude: visit.place.longitude,
          ),
          locationName: visit.place.name,
        ),
  ]..sort(_compareSegments);
  return segments;
}

LocationPoint _travelStartLocation(TravelLeg leg) {
  for (final section in leg.route?.sections ?? const []) {
    if (section.departureLatitude != null &&
        section.departureLongitude != null) {
      return LocationPoint(
        latitude: section.departureLatitude!,
        longitude: section.departureLongitude!,
      );
    }
  }
  return LocationPoint(
    latitude: leg.origin.latitude,
    longitude: leg.origin.longitude,
  );
}

String _travelStartName(TravelLeg leg) {
  for (final section in leg.route?.sections ?? const []) {
    if (section.departureLatitude != null &&
        section.departureLongitude != null) {
      return section.departureTitle ?? leg.origin.name;
    }
  }
  return leg.origin.name;
}

int _compareSegments(GuardianScheduledSegment a, GuardianScheduledSegment b) {
  final byStart = a.start.compareTo(b.start);
  if (byStart != 0) return byStart;
  if (a.phase == b.phase) return a.end.compareTo(b.end);
  return a.phase == GuardianSchedulePhase.visit ? -1 : 1;
}

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) matches) {
  for (final item in items) {
    if (matches(item)) return item;
  }
  return null;
}

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
