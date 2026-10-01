import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/algorithm/route_optimizer.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_day.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_travel_mode.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_visit.dart';
import 'package:taipei_travel_app/features/route_planning/models/travel_leg.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/models/scheduled_visit.dart';
import 'package:taipei_travel_app/models/tdx_route.dart';
import 'package:taipei_travel_app/services/google_route_planning_gateway.dart';
import 'package:taipei_travel_app/services/live_itinerary_alternative_planner.dart';
import 'package:taipei_travel_app/services/location_service.dart';
import 'package:taipei_travel_app/services/tdx_service.dart';

void main() {
  test('當日首站沒有進站路段時，確認首站完成仍可產生備案', () async {
    final day = _dayWithoutFirstLeg();
    final google = _Google();
    final transit = _Transit();
    final result =
        await LiveItineraryAlternativePlanner(
          transit: transit,
          google: google,
        ).plan(
          day: day,
          currentLocation: const LocationPoint(
            latitude: 25.1,
            longitude: 121.1,
          ),
          now: DateTime(2026, 9, 22, 11),
          completedCount: 1,
          strategy: LiveAlternativeStrategy.preserveOrder,
        );
    expect(result.canApply, isTrue);
    expect(result.day!.visits.first, same(day.visits.first));
    expect(result.day!.travelLegs, hasLength(2));
    expect(result.day!.travelLegs.first.travelMode, RouteTravelMode.walking);
    expect(google.departures, hasLength(1));
    expect(transit.departures, hasLength(1));
  });

  test('沒有進站路段的首站若就在目前位置，不必查詢空路線', () async {
    final day = _dayWithoutFirstLeg();
    final result =
        await LiveItineraryAlternativePlanner(
          transit: _Transit(),
          google: _Google(),
        ).plan(
          day: day,
          currentLocation: const LocationPoint(latitude: 25, longitude: 121),
          now: DateTime(2026, 9, 22, 9),
          completedCount: 0,
          strategy: LiveAlternativeStrategy.preserveOrder,
        );
    expect(result.canApply, isTrue);
    expect(result.day!.travelLegs, hasLength(2));
  });

  test('離首站較遠且原本沒有進站路段時，先要求選交通方式', () async {
    final planner = LiveItineraryAlternativePlanner(
      transit: _Transit(),
      google: _Google(),
    );
    final day = _dayWithoutFirstLeg();
    final args = (
      day: day,
      currentLocation: const LocationPoint(latitude: 25.1, longitude: 121.1),
      now: DateTime(2026, 9, 22, 9),
    );
    final missingMode = await planner.plan(
      day: args.day,
      currentLocation: args.currentLocation,
      now: args.now,
      completedCount: 0,
      strategy: LiveAlternativeStrategy.preserveOrder,
    );
    expect(missingMode.canApply, isFalse);
    expect(missingMode.needsNewLegMode, isTrue);

    final withMode = await planner.plan(
      day: args.day,
      currentLocation: args.currentLocation,
      now: args.now,
      completedCount: 0,
      strategy: LiveAlternativeStrategy.preserveOrder,
      newLegMode: RouteTravelMode.walking,
    );
    expect(withMode.canApply, isTrue);
    expect(withMode.day!.travelLegs.first.travelMode, RouteTravelMode.walking);
  });

  test('受影響路段索引以交通段而非景點索引計算', () async {
    final day = _dayWithoutFirstLeg();
    final selected = _route(15);
    final result =
        await LiveItineraryAlternativePlanner(
          transit: _Transit(),
          google: _Google(),
        ).plan(
          day: day,
          currentLocation: const LocationPoint(latitude: 25, longitude: 121),
          now: DateTime(2026, 9, 22, 11),
          completedCount: 2,
          strategy: LiveAlternativeStrategy.preserveOrder,
          affectedLegIndex: 1,
          selectedFirstRoute: selected,
        );
    expect(result.canApply, isTrue);
    expect(result.day!.visits.take(2), day.visits.take(2));
    expect(result.day!.travelLegs.first, same(day.travelLegs.first));
    expect(result.day!.travelLegs.last.route, same(selected));
  });

  test('未結束的前一項必須先完成，不能把後續交通往前排成時間重疊', () async {
    final day = _dayWithoutFirstLeg();
    final earlyRoute = TdxRoute(
      transfers: 0,
      travelTime: 20 * 60,
      startTime: DateTime(2026, 9, 22, 11, 5),
      endTime: DateTime(2026, 9, 22, 11, 25),
      sections: const [],
    );
    final planner = LiveItineraryAlternativePlanner(
      transit: _Transit(),
      google: _Google(),
    );
    final rejected = await planner.plan(
      day: day,
      currentLocation: const LocationPoint(latitude: 25, longitude: 121),
      now: DateTime(2026, 9, 22, 11),
      completedCount: 1,
      strategy: LiveAlternativeStrategy.preserveOrder,
      affectedLegIndex: 1,
      selectedFirstRoute: earlyRoute,
    );
    expect(rejected.canApply, isFalse);
    expect(rejected.failure, contains('已出發'));

    final validRoute = TdxRoute(
      transfers: 0,
      travelTime: 20 * 60,
      startTime: DateTime(2026, 9, 22, 12),
      endTime: DateTime(2026, 9, 22, 12, 20),
      sections: const [],
    );
    final accepted = await planner.plan(
      day: day,
      currentLocation: const LocationPoint(latitude: 25, longitude: 121),
      now: DateTime(2026, 9, 22, 11),
      completedCount: 1,
      strategy: LiveAlternativeStrategy.preserveOrder,
      affectedLegIndex: 1,
      selectedFirstRoute: validRoute,
    );
    expect(accepted.canApply, isTrue);
    expect(accepted.day!.travelLegs.last.schedule.departureMinutes, 720);
    expect(
      accepted.day!.visits.last.startMinutes,
      greaterThanOrEqualTo(day.visits[1].endMinutes),
    );
  });

  test('保留已完成前綴、逐段查詢並保留步行與大眾運輸模式', () async {
    final day = _day();
    final tdx = _Transit();
    final google = _Google();
    final planner = LiveItineraryAlternativePlanner(
      transit: tdx,
      google: google,
    );
    final result = await planner.plan(
      day: day,
      currentLocation: const LocationPoint(latitude: 25.1, longitude: 121.1),
      now: DateTime(2026, 9, 22, 11),
      completedCount: 1,
      strategy: LiveAlternativeStrategy.preserveOrder,
    );
    expect(result.canApply, isTrue);
    expect(result.day!.visits.first, same(day.visits.first));
    expect(result.day!.travelLegs.first, same(day.travelLegs.first));
    expect(result.day!.travelLegs[1].travelMode, RouteTravelMode.walking);
    expect(result.day!.travelLegs[2].travelMode, RouteTravelMode.transit);
    expect(google.departures.single, DateTime(2026, 9, 22, 11));
    expect(tdx.departures.single, DateTime(2026, 9, 22, 12, 30));
    expect(result.day!.travelLegs.every((leg) => leg.route != null), isTrue);
  });

  test('路線查詢失敗不產生假裝已驗證的候選', () async {
    final planner = LiveItineraryAlternativePlanner(
      transit: _Transit(),
      google: _Google(returnNull: true),
    );
    final result = await planner.plan(
      day: _day(),
      currentLocation: const LocationPoint(latitude: 25.1, longitude: 121.1),
      now: DateTime(2026, 9, 22, 11),
      completedCount: 1,
      strategy: LiveAlternativeStrategy.preserveOrder,
    );
    expect(result.canApply, isFalse);
    expect(result.day, isNull);
    expect(result.failure, contains('查不到'));
  });

  test('固定時間來不及時明確拒絕', () async {
    final day = _day(lockSecond: true);
    final planner = LiveItineraryAlternativePlanner(
      transit: _Transit(),
      google: _Google(),
    );
    final result = await planner.plan(
      day: day,
      currentLocation: const LocationPoint(latitude: 25.1, longitude: 121.1),
      now: DateTime(2026, 9, 22, 11),
      completedCount: 1,
      strategy: LiveAlternativeStrategy.preserveOrder,
    );
    expect(result.canApply, isFalse);
    expect(result.failure, contains('固定時間'));
  });

  test('轉乘備案重排時保留已選第一段，只重排其後項目', () async {
    final selected = _route(15);
    final planner = LiveItineraryAlternativePlanner(
      transit: _Transit(),
      google: _Google(),
    );
    final day = _day();
    final result = await planner.plan(
      day: day,
      currentLocation: const LocationPoint(latitude: 25, longitude: 121),
      now: DateTime(2026, 9, 22, 9),
      completedCount: 0,
      strategy: LiveAlternativeStrategy.reorderRemaining,
      selectedFirstRoute: selected,
      newLegMode: RouteTravelMode.walking,
      keepFirstRemaining: true,
    );
    expect(result.canApply, isTrue);
    expect(
      result.day!.visits.first.occurrenceId,
      day.visits.first.occurrenceId,
    );
    expect(result.day!.travelLegs.first.route, same(selected));
    expect(result.day!.travelLegs.first.travelMode, RouteTravelMode.transit);
  });
}

class _Transit implements TdxRoutingGateway {
  final departures = <DateTime>[];

  @override
  Future<List<TdxRoute>> getRoutingOptions({
    required String origin,
    required String destination,
    DateTime? departureTime,
  }) async {
    departures.add(departureTime!);
    return [_route(20)];
  }
}

class _Google implements GoogleRoutePlanningGateway {
  final bool returnNull;
  final departures = <DateTime>[];
  _Google({this.returnNull = false});

  @override
  Future<TdxRoute?> getRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required DateTime requestedDeparture,
    required RouteTravelMode travelMode,
  }) async {
    departures.add(requestedDeparture);
    return returnNull ? null : _route(60);
  }
}

TdxRoute _route(int minutes) =>
    TdxRoute(transfers: 0, travelTime: minutes * 60, sections: []);

RouteDay _day({bool lockSecond = false}) {
  const a = RouteStop(id: 'a', name: 'A', latitude: 25, longitude: 121);
  const b = RouteStop(id: 'b', name: 'B', latitude: 25.1, longitude: 121.1);
  const c = RouteStop(id: 'c', name: 'C', latitude: 25.2, longitude: 121.2);
  const d = RouteStop(id: 'd', name: 'D', latitude: 25.3, longitude: 121.3);
  final first = _visit('b', 600, 660);
  final second = _visit(
    'c',
    690,
    720,
    locked: lockSecond,
    requested: lockSecond ? 690 : null,
  );
  final third = _visit('d', 780, 810);
  return RouteDay(
    day: 1,
    date: DateTime(2026, 9, 22),
    origin: a,
    visits: [first, second, third],
    travelLegs: [
      _leg(a, b, first, RouteTravelMode.transit),
      _leg(b, c, second, RouteTravelMode.walking),
      _leg(c, d, third, RouteTravelMode.transit),
    ],
    isValid: true,
  );
}

RouteDay _dayWithoutFirstLeg() {
  final day = _day();
  return RouteDay(
    day: day.day,
    date: day.date,
    origin: day.travelLegs.first.destination,
    visits: day.visits,
    travelLegs: day.travelLegs.skip(1).toList(),
    isValid: day.isValid,
  );
}

RouteVisit _visit(
  String id,
  int start,
  int end, {
  bool locked = false,
  int? requested,
}) => RouteVisit(
  place: Place(
    id: id,
    name: id,
    category: '景點',
    description: '',
    address: '',
    latitude: 25,
    longitude: 121,
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
  requestedStartMinutes: requested,
  locked: locked,
);

TravelLeg _leg(
  RouteStop origin,
  RouteStop destination,
  RouteVisit visit,
  RouteTravelMode mode,
) => TravelLeg(
  origin: origin,
  destination: destination,
  requestedDeparture: DateTime(2026, 9, 22, 9),
  schedule: ScheduledVisit(
    departureMinutes: 540,
    arrivalMinutes: visit.arrivalMinutes,
    visitStartMinutes: visit.startMinutes,
    visitEndMinutes: visit.endMinutes,
    waitingMinutes: 0,
    stayMinutes: visit.stayMinutes,
  ),
  route: _route(20),
  travelMode: mode,
);
