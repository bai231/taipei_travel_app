import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_place_input.dart';
import 'package:taipei_travel_app/features/route_planning/services/itinerary_planning_service.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/models/tdx_route.dart';
import 'package:taipei_travel_app/models/trip_request.dart';
import 'package:taipei_travel_app/services/timed_tdx_route_service.dart';

void main() {
  test('未指定日期的景點會分配到負擔較少的天數', () async {
    final service = ItineraryPlanningService(
      timedRouteService: _FakeTimedTdxRouteService(),
      requestInterval: Duration.zero,
    );

    final itinerary = await service.generate(
      request: _request(days: 2),
      places: [
        RoutePlaceInput(place: _place('first', stayMinutes: 120), day: 1),
        RoutePlaceInput(place: _place('second', stayMinutes: 60)),
      ],
    );

    expect(itinerary.days, hasLength(2));
    expect(itinerary.days[0].visits.single.place.id, 'first');
    expect(itinerary.days[1].visits.single.place.id, 'second');
  });

  test('每段 TDX 查詢使用上一景點停留完成後的離開時間', () async {
    final fakeTdx = _FakeTimedTdxRouteService();
    final service = ItineraryPlanningService(
      timedRouteService: fakeTdx,
      requestInterval: Duration.zero,
    );

    final itinerary = await service.generate(
      request: _request(days: 1),
      places: [
        RoutePlaceInput(place: _place('near', stayMinutes: 60), day: 1),
        RoutePlaceInput(
          place: _place(
            'far',
            stayMinutes: 90,
            latitude: 25.08,
            longitude: 121.56,
          ),
          day: 1,
        ),
      ],
    );

    expect(fakeTdx.requestedDepartures, hasLength(2));
    expect(fakeTdx.requestedDepartures.first.hour, 9);
    expect(fakeTdx.requestedDepartures.first.minute, 0);
    expect(fakeTdx.requestedDepartures.last.hour, 10);
    expect(fakeTdx.requestedDepartures.last.minute, 20);
    expect(itinerary.days.single.travelLegs, hasLength(2));
    expect(itinerary.days.single.visits.last.startMinutes, 10 * 60 + 40);
  });

  test('首站固定 09:00 時會重查較早班次並準時開始', () async {
    final progressMessages = <String>[];
    final fakeTdx = _FakeTimedTdxRouteService();
    final service = ItineraryPlanningService(
      timedRouteService: fakeTdx,
      requestInterval: Duration.zero,
    );

    final itinerary = await service.generate(
      request: _request(days: 1),
      places: [
        RoutePlaceInput(
          place: _place('appointment', stayMinutes: 60),
          day: 1,
          startMinutes: 9 * 60,
          locked: true,
        ),
      ],
      onProgress: progressMessages.add,
    );

    final visit = itinerary.days.single.visits.single;
    expect(fakeTdx.requestedDepartures.length, greaterThan(1));
    expect(fakeTdx.requestedDepartures.last.hour, 8);
    expect(visit.arrivalMinutes, lessThanOrEqualTo(9 * 60));
    expect(visit.startMinutes, 9 * 60);
    expect(itinerary.days.single.warnings, isEmpty);
    expect(progressMessages, contains('正在查詢 Day 1 第 1/1 段交通…'));
    expect(progressMessages, contains('首站可能遲到，正在重新查詢更早的 TDX 班次…'));
  });

  test('下一站尚未開放時會延後出發而不是提早抵達久候', () async {
    final fakeTdx = _FakeTimedTdxRouteService();
    final service = ItineraryPlanningService(
      timedRouteService: fakeTdx,
      requestInterval: Duration.zero,
    );

    final itinerary = await service.generate(
      request: _request(days: 1),
      places: [
        RoutePlaceInput(
          place: _place('morning', stayMinutes: 60),
          day: 1,
          startMinutes: 9 * 60,
          locked: true,
        ),
        RoutePlaceInput(
          place: _place('night-market', stayMinutes: 120, openMinutes: 18 * 60),
          day: 1,
        ),
      ],
    );

    final secondLeg = itinerary.days.single.travelLegs[1];
    final secondVisit = itinerary.days.single.visits[1];
    expect(secondLeg.schedule.departureMinutes, greaterThan(17 * 60));
    expect(secondVisit.waitingMinutes, lessThanOrEqualTo(15));
    expect(secondVisit.startMinutes, greaterThanOrEqualTo(18 * 60));
  });
}

class _FakeTimedTdxRouteService extends TimedTdxRouteService {
  final List<DateTime> requestedDepartures = [];

  _FakeTimedTdxRouteService() : super(requestInterval: Duration.zero);

  @override
  Future<TdxRoute?> getRouteAtOrAfter({
    required String origin,
    required String destination,
    required DateTime requestedDeparture,
    void Function(DateTime queryTime)? onRetry,
  }) async {
    requestedDepartures.add(requestedDeparture);
    return TdxRoute(
      transfers: 0,
      travelTime: 20 * 60,
      startTime: requestedDeparture,
      endTime: requestedDeparture.add(const Duration(minutes: 20)),
      sections: const [],
    );
  }
}

TripRequest _request({required int days}) {
  return TripRequest(
    title: '台北測試行程',
    startDate: DateTime(2026, 8, 20),
    endDate: DateTime(2026, 8, 20 + days - 1),
    location: '台北市',
    people: 2,
    budget: 5000,
    preferences: const ['攝影'],
    aiPrompt: '',
  );
}

Place _place(
  String id, {
  required int stayMinutes,
  double latitude = 25.05,
  double longitude = 121.52,
  int openMinutes = 8 * 60,
  int closeMinutes = 22 * 60,
}) {
  return Place(
    id: id,
    name: id,
    category: '景點',
    description: '測試景點',
    address: '台北市',
    latitude: latitude,
    longitude: longitude,
    image: '',
    stayTime: stayMinutes,
    rating: 4.5,
    tags: const [],
    priceLevel: 1,
    estimatedCost: 100,
    openMinutes: openMinutes,
    closeMinutes: closeMinutes,
  );
}
