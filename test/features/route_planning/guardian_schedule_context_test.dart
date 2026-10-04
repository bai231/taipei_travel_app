import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/algorithm/route_optimizer.dart';
import 'package:taipei_travel_app/features/route_planning/debug/guardian_schedule_context.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_day.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_itinerary.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_visit.dart';
import 'package:taipei_travel_app/features/route_planning/models/travel_leg.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/models/scheduled_visit.dart';
import 'package:taipei_travel_app/models/trip_request.dart';

void main() {
  test('distinguishes travel, visit, and end without marking complete', () {
    final itinerary = _itinerary([
      _day(1, DateTime(2026, 9, 22), start: 9 * 60, end: 10 * 60),
    ]);

    final travel = guardianScheduleContext(
      itinerary,
      DateTime(2026, 9, 22, 8, 45),
    );
    expect(travel.day?.day, 1);
    expect(travel.phase, GuardianSchedulePhase.travel);
    expect(travel.current?.label, '起點 → Day 1 景點');
    expect(travel.current?.location.latitude, 25.03);
    expect(travel.current?.locationName, '起點');

    final visit = guardianScheduleContext(
      itinerary,
      DateTime(2026, 9, 22, 9, 30),
    );
    expect(visit.phase, GuardianSchedulePhase.visit);
    expect(visit.current?.label, 'Day 1 景點');
    expect(visit.current?.location.latitude, 25.04);
    expect(visit.current?.locationName, 'Day 1 景點');

    final after = guardianScheduleContext(itinerary, DateTime(2026, 9, 22, 10));
    expect(after.phase, GuardianSchedulePhase.afterLast);
    expect(after.current, isNull);
  });

  test(
    'selects the correct day, including a previous-day cross-midnight visit',
    () {
      final itinerary = _itinerary([
        _day(1, DateTime(2026, 9, 22), start: 23 * 60 + 30, end: 24 * 60 + 30),
        _day(2, DateTime(2026, 9, 23), start: 9 * 60, end: 10 * 60),
      ]);

      final overnight = guardianScheduleContext(
        itinerary,
        DateTime(2026, 9, 23, 0, 10),
      );
      expect(overnight.day?.day, 1);
      expect(overnight.phase, GuardianSchedulePhase.visit);

      final morning = guardianScheduleContext(
        itinerary,
        DateTime(2026, 9, 23, 8),
      );
      expect(morning.day?.day, 2);
      expect(morning.phase, GuardianSchedulePhase.beforeFirst);
      expect(morning.next?.label, '起點 → Day 2 景點');

      final outside = guardianScheduleContext(
        itinerary,
        DateTime(2026, 9, 24, 8),
      );
      expect(outside.day, isNull);
      expect(outside.phase, GuardianSchedulePhase.outsideTrip);
    },
  );

  test('gap points to the next original segment', () {
    final day = _day(1, DateTime(2026, 9, 22), start: 9 * 60, end: 10 * 60);
    final later = _visit('第二站', 12 * 60, 13 * 60);
    final itinerary = _itinerary([
      RouteDay(
        day: 1,
        date: day.date,
        origin: day.origin,
        visits: [...day.visits, later],
        travelLegs: day.travelLegs,
        isValid: true,
      ),
    ]);

    final gap = guardianScheduleContext(itinerary, DateTime(2026, 9, 22, 11));
    expect(gap.phase, GuardianSchedulePhase.gap);
    expect(gap.next?.label, '第二站');
  });
}

RouteItinerary _itinerary(List<RouteDay> days) => RouteItinerary(
  request: TripRequest(
    title: '保母時間測試',
    startDate: days.first.date,
    endDate: days.last.date,
    location: '臺北市',
    people: 1,
    budget_level: 1000,
    preferences: const [],
    aiPrompt: '',
  ),
  origin: days.first.origin,
  days: days,
  generatedAt: days.first.date,
);

RouteDay _day(
  int dayNumber,
  DateTime date, {
  required int start,
  required int end,
}) {
  const origin = RouteStop(
    id: 'origin',
    name: '起點',
    latitude: 25.03,
    longitude: 121.51,
  );
  final visit = _visit('Day $dayNumber 景點', start, end);
  return RouteDay(
    day: dayNumber,
    date: date,
    origin: origin,
    visits: [visit],
    travelLegs: [
      TravelLeg(
        origin: origin,
        destination: RouteStop.fromPlace(visit.place),
        requestedDeparture: date.add(Duration(minutes: start - 30)),
        schedule: ScheduledVisit(
          departureMinutes: start - 30,
          arrivalMinutes: start,
          visitStartMinutes: start,
          visitEndMinutes: end,
          waitingMinutes: 0,
          stayMinutes: end - start,
        ),
      ),
    ],
    isValid: true,
  );
}

RouteVisit _visit(String name, int start, int end) => RouteVisit(
  place: Place(
    id: name,
    name: name,
    category: '景點',
    description: '',
    address: '',
    latitude: 25.04,
    longitude: 121.52,
    image: '',
    stayTime: end - start,
    rating: 0,
    tags: const [],
    price_level: 0,
    openMinutes: 0,
    closeMinutes: 1440,
  ),
  sequence: 1,
  arrivalMinutes: start,
  startMinutes: start,
  endMinutes: end,
  waitingMinutes: 0,
  stayMinutes: end - start,
  requestedStartMinutes: null,
  locked: false,
);
