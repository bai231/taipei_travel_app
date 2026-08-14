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
    openMinutes: 8 * 60,
    closeMinutes: 22 * 60,
  );
}
