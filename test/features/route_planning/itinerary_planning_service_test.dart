import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_place_input.dart';
import 'package:taipei_travel_app/features/route_planning/models/travel_leg.dart';
import 'package:taipei_travel_app/features/route_planning/services/itinerary_planning_service.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/models/tdx_route.dart';
import 'package:taipei_travel_app/models/trip_request.dart';
import 'package:taipei_travel_app/services/tdx_service.dart';
import 'package:taipei_travel_app/services/timed_tdx_route_service.dart';

void main() {
  test('未指定日期的景點會分配到負擔較少的天數', () async {
    final service = ItineraryPlanningService(
      timedRouteService: _FakeTimedTdxRouteService(),
      requestInterval: Duration.zero,
      now: _beforeTrip,
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

  test('輸出景點數量與使用者唯一選擇數量一致', () async {
    final service = ItineraryPlanningService(
      timedRouteService: _FakeTimedTdxRouteService(),
      requestInterval: Duration.zero,
      now: _beforeTrip,
    );

    final itinerary = await service.generate(
      request: _request(days: 1),
      places: [
        RoutePlaceInput(place: _place('first', stayMinutes: 60)),
        RoutePlaceInput(place: _place('second', stayMinutes: 60)),
        RoutePlaceInput(place: _place('second', stayMinutes: 60)),
      ],
    );

    final visits = itinerary.days.expand((day) => day.visits).toList();
    expect(visits, hasLength(2));
    expect(visits.map((visit) => visit.place.id).toSet(), {'first', 'second'});
  });

  test('跨日行程承接前一天終點並將鄰近景點分在連續天數', () async {
    final service = ItineraryPlanningService(
      timedRouteService: _FakeTimedTdxRouteService(),
      requestInterval: Duration.zero,
      now: _beforeTrip,
    );

    final itinerary = await service.generate(
      request: _request(days: 2),
      places: [
        RoutePlaceInput(
          place: _place(
            'taipei-a',
            stayMinutes: 60,
            latitude: 25.04,
            longitude: 121.52,
          ),
        ),
        RoutePlaceInput(
          place: _place(
            'kaohsiung-a',
            stayMinutes: 60,
            latitude: 22.63,
            longitude: 120.30,
          ),
        ),
        RoutePlaceInput(
          place: _place(
            'taipei-b',
            stayMinutes: 60,
            latitude: 25.06,
            longitude: 121.54,
          ),
        ),
        RoutePlaceInput(
          place: _place(
            'kaohsiung-b',
            stayMinutes: 60,
            latitude: 22.65,
            longitude: 120.32,
          ),
        ),
      ],
    );

    final firstDay = itinerary.days.first;
    final secondDay = itinerary.days.last;
    expect(firstDay.visits.map((visit) => visit.place.id).toSet(), {
      'taipei-a',
      'taipei-b',
    });
    expect(secondDay.visits.map((visit) => visit.place.id).toSet(), {
      'kaohsiung-a',
      'kaohsiung-b',
    });
    expect(secondDay.origin.id, firstDay.visits.last.place.id);
    expect(secondDay.travelLegs.first.origin.id, secondDay.origin.id);
  });

  test('三日跨縣市景點會沿大距離邊界分天且每日承接前日終點', () async {
    final service = ItineraryPlanningService(
      timedRouteService: _FakeTimedTdxRouteService(),
      requestInterval: Duration.zero,
      now: _beforeTrip,
    );

    final itinerary = await service.generate(
      request: _request(days: 3),
      places: [
        RoutePlaceInput(
          place: _place(
            'taipei-a',
            stayMinutes: 60,
            latitude: 25.04,
            longitude: 121.52,
          ),
        ),
        RoutePlaceInput(
          place: _place(
            'kaohsiung-a',
            stayMinutes: 60,
            latitude: 22.63,
            longitude: 120.30,
          ),
        ),
        RoutePlaceInput(
          place: _place(
            'taichung-a',
            stayMinutes: 60,
            latitude: 24.15,
            longitude: 120.68,
          ),
        ),
        RoutePlaceInput(
          place: _place(
            'taipei-b',
            stayMinutes: 60,
            latitude: 25.06,
            longitude: 121.54,
          ),
        ),
        RoutePlaceInput(
          place: _place(
            'kaohsiung-b',
            stayMinutes: 60,
            latitude: 22.65,
            longitude: 120.32,
          ),
        ),
        RoutePlaceInput(
          place: _place(
            'taichung-b',
            stayMinutes: 60,
            latitude: 24.17,
            longitude: 120.70,
          ),
        ),
        RoutePlaceInput(
          place: _place(
            'kaohsiung-c',
            stayMinutes: 60,
            latitude: 22.67,
            longitude: 120.34,
          ),
        ),
      ],
    );

    expect(itinerary.days[0].visits.map((visit) => visit.place.id).toSet(), {
      'taipei-a',
      'taipei-b',
    });
    expect(itinerary.days[1].visits.map((visit) => visit.place.id).toSet(), {
      'taichung-a',
      'taichung-b',
    });
    expect(itinerary.days[2].visits.map((visit) => visit.place.id).toSet(), {
      'kaohsiung-a',
      'kaohsiung-b',
      'kaohsiung-c',
    });
    expect(itinerary.days[1].origin.id, itinerary.days[0].visits.last.place.id);
    expect(itinerary.days[2].origin.id, itinerary.days[1].visits.last.place.id);
  });

  test('跨縣市備援估時不會套用市區慢速公式而排到隔天', () async {
    final service = ItineraryPlanningService(
      timedRouteService: _EmptyTimedTdxRouteService(),
      requestInterval: Duration.zero,
      now: _beforeTrip,
    );

    final itinerary = await service.generate(
      request: _request(days: 2),
      places: [
        RoutePlaceInput(
          place: _place(
            'taipei',
            stayMinutes: 60,
            latitude: 25.04,
            longitude: 121.52,
          ),
          day: 1,
        ),
        RoutePlaceInput(
          place: _place(
            'taichung',
            stayMinutes: 60,
            latitude: 24.15,
            longitude: 120.68,
          ),
          day: 2,
        ),
      ],
    );

    final secondDay = itinerary.days[1];
    final schedule = secondDay.travelLegs.single.schedule;
    expect(schedule.arrivalMinutes - schedule.departureMinutes, lessThan(240));
    expect(secondDay.visits.single.endMinutes, lessThan(24 * 60));
  });

  test('每段 TDX 查詢使用上一景點停留完成後的離開時間', () async {
    final fakeTdx = _FakeTimedTdxRouteService();
    final service = ItineraryPlanningService(
      timedRouteService: fakeTdx,
      requestInterval: Duration.zero,
      now: _beforeTrip,
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
      now: _beforeTrip,
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
      now: _beforeTrip,
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

  test('旅程出發時間已經過去時不發送 TDX 查詢', () async {
    final fakeTdx = _FakeTimedTdxRouteService();
    final service = ItineraryPlanningService(
      timedRouteService: fakeTdx,
      requestInterval: Duration.zero,
      now: () => DateTime(2026, 8, 20, 22),
    );

    expect(
      () => service.generate(
        request: _request(days: 1),
        places: [
          RoutePlaceInput(place: _place('past', stayMinutes: 60), day: 1),
        ],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('TDX 不支援查詢已經過去的出發時間'),
        ),
      ),
    );
    expect(fakeTdx.requestedDepartures, isEmpty);
  });

  test('TDX 無可用路線時不因營業時間再次查詢', () async {
    final fakeTdx = _CountingEmptyTimedTdxRouteService();
    final service = ItineraryPlanningService(
      timedRouteService: fakeTdx,
      requestInterval: Duration.zero,
      now: _beforeTrip,
    );

    final itinerary = await service.generate(
      request: _request(days: 1),
      places: [
        RoutePlaceInput(
          place: _place('night-market', stayMinutes: 120, openMinutes: 18 * 60),
          day: 1,
        ),
      ],
    );

    expect(fakeTdx.queryCount, 1);
    expect(itinerary.days.single.travelLegs.single.route, isNull);
  });

  test('收到 429 後等待指定時間並重試同一路段一次', () async {
    final fakeTdx = _RateLimitThenSuccessTimedTdxRouteService();
    final delays = <Duration>[];
    final waitUpdates = <Duration?>[];
    final service = ItineraryPlanningService(
      timedRouteService: fakeTdx,
      requestInterval: Duration.zero,
      now: _beforeTrip,
      delay: (duration) async => delays.add(duration),
    );

    final itinerary = await service.generate(
      request: _request(days: 1),
      places: [
        RoutePlaceInput(place: _place('retry', stayMinutes: 60), day: 1),
      ],
      onRateLimitWait: waitUpdates.add,
    );

    expect(fakeTdx.queryCount, 2);
    expect(delays, hasLength(2));
    expect(waitUpdates, [
      const Duration(seconds: 2),
      const Duration(seconds: 1),
      null,
    ]);
    expect(itinerary.days.single.travelLegs.single.route, isNotNull);
  });

  test('使用者取消 429 等待後，其餘路段直接使用估計時間', () async {
    final control = ItineraryPlanningControl();
    final fakeTdx = _AlwaysRateLimitedTimedTdxRouteService();
    final service = ItineraryPlanningService(
      timedRouteService: fakeTdx,
      requestInterval: Duration.zero,
      now: _beforeTrip,
      delay: (_) async => control.useEstimates(),
    );

    final itinerary = await service.generate(
      request: _request(days: 1),
      places: [
        RoutePlaceInput(place: _place('first', stayMinutes: 60), day: 1),
        RoutePlaceInput(place: _place('second', stayMinutes: 60), day: 1),
      ],
      control: control,
    );

    expect(fakeTdx.queryCount, 1);
    expect(
      itinerary.days.single.travelLegs,
      everyElement(
        isA<TravelLeg>().having(
          (leg) => leg.errorMessage,
          'errorMessage',
          contains('已取消等待'),
        ),
      ),
    );
  });
}

DateTime _beforeTrip() => DateTime(2026, 8, 19);

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

class _EmptyTimedTdxRouteService extends TimedTdxRouteService {
  _EmptyTimedTdxRouteService() : super(requestInterval: Duration.zero);

  @override
  Future<TdxRoute?> getRouteAtOrAfter({
    required String origin,
    required String destination,
    required DateTime requestedDeparture,
    void Function(DateTime queryTime)? onRetry,
  }) async {
    return null;
  }
}

class _CountingEmptyTimedTdxRouteService extends TimedTdxRouteService {
  int queryCount = 0;

  _CountingEmptyTimedTdxRouteService() : super(requestInterval: Duration.zero);

  @override
  Future<TdxRoute?> getRouteAtOrAfter({
    required String origin,
    required String destination,
    required DateTime requestedDeparture,
    void Function(DateTime queryTime)? onRetry,
  }) async {
    queryCount++;
    return null;
  }
}

class _RateLimitThenSuccessTimedTdxRouteService extends TimedTdxRouteService {
  int queryCount = 0;

  _RateLimitThenSuccessTimedTdxRouteService()
    : super(requestInterval: Duration.zero);

  @override
  Future<TdxRoute?> getRouteAtOrAfter({
    required String origin,
    required String destination,
    required DateTime requestedDeparture,
    void Function(DateTime queryTime)? onRetry,
  }) async {
    queryCount++;
    if (queryCount == 1) {
      throw const TdxRateLimitException(retryAfter: Duration(seconds: 2));
    }
    return TdxRoute(
      transfers: 0,
      travelTime: 20 * 60,
      startTime: requestedDeparture,
      endTime: requestedDeparture.add(const Duration(minutes: 20)),
      sections: const [],
    );
  }
}

class _AlwaysRateLimitedTimedTdxRouteService extends TimedTdxRouteService {
  int queryCount = 0;

  _AlwaysRateLimitedTimedTdxRouteService()
    : super(requestInterval: Duration.zero);

  @override
  Future<TdxRoute?> getRouteAtOrAfter({
    required String origin,
    required String destination,
    required DateTime requestedDeparture,
    void Function(DateTime queryTime)? onRetry,
  }) async {
    queryCount++;
    throw const TdxRateLimitException(retryAfter: Duration(seconds: 2));
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
    //priceLevel: 1,
    estimatedCost: 100,
    openMinutes: openMinutes,
    closeMinutes: closeMinutes,
  );
}
