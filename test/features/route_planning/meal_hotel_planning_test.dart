import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_place_input.dart';
import 'package:taipei_travel_app/features/route_planning/services/itinerary_planning_service.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/models/tdx_route.dart';
import 'package:taipei_travel_app/models/trip_request.dart';
import 'package:taipei_travel_app/models/visit_preferences.dart';
import 'package:taipei_travel_app/services/timed_tdx_route_service.dart';

void main() {
  late _Transport transport;
  late ItineraryPlanningService planner;
  setUp(() {
    transport = _Transport();
    planner = ItineraryPlanningService(
      timedRouteService: transport,
      requestInterval: Duration.zero,
      now: () => DateTime(2029, 12, 31),
    );
  });

  test('餐別控制用餐開始時段、停留長度並保留資訊來源', () async {
    final result = await planner.generate(
      request: _request(),
      places: [
        RoutePlaceInput(
          place: _place('dinner', type: PlaceType.restaurant),
          preferences: const VisitPreferences(mealType: MealType.dinner),
        ),
        RoutePlaceInput(
          place: _place('lunch', type: PlaceType.restaurant),
          preferences: const VisitPreferences(mealType: MealType.lunch),
        ),
      ],
    );
    final visits = result.days.single.visits;
    expect(visits.map((visit) => visit.place.id), ['lunch', 'dinner']);
    expect(visits.first.startMinutes, 660);
    expect(visits.first.stayMinutes, 60);
    expect(visits.last.startMinutes, inInclusiveRange(1020, 1230));
    expect(visits.last.stayMinutes, 90);
    expect(visits.first.information.join(), contains('營業時間未知'));
    expect(visits.first.information.join(), contains('非訂位'));
    expect(visits.last.information.join(), contains('來自 TDX'));
    expect(result.inputs.first.preferences.mealType, MealType.dinner);
  });

  test('未指定餐別是建議而非使用者已確認設定', () async {
    final input = RoutePlaceInput(
      place: _place('meal', type: PlaceType.restaurant),
    );
    final result = await planner.generate(request: _request(), places: [input]);
    final visit = result.days.single.visits.single;
    expect(visit.mealType, MealType.lunch);
    expect(visit.information.join(), contains('演算法建議餐別'));
    expect(result.inputs.single.preferences.mealType, MealType.unspecified);
  });

  test('手動凌晨用餐時間不被預設餐別時段覆蓋', () async {
    final result = await planner.generate(
      request: _request(),
      places: [
        RoutePlaceInput(
          place: _place('late-meal', type: PlaceType.restaurant),
          day: 1,
          startMinutes: 30,
          locked: true,
          preferences: const VisitPreferences(
            mealType: MealType.dinner,
            durationMinutes: 35,
          ),
        ),
      ],
    );
    final visit = result.days.single.visits.single;
    expect(visit.startMinutes, 30);
    expect(visit.endMinutes, 65);
    expect(visit.information.join(), contains('偏離偏好時段'));
    expect(visit.information.join(), contains('已確認的使用者安排'));
  });

  test('自訂用餐開始時段優先於餐別預設', () async {
    final result = await planner.generate(
      request: _request(),
      places: [
        RoutePlaceInput(
          place: _place('brunch', type: PlaceType.restaurant),
          preferences: const VisitPreferences(
            mealType: MealType.lunch,
            mealWindowStart: 600,
            mealWindowEnd: 630,
            durationMinutes: 75,
          ),
        ),
      ],
    );
    expect(result.days.single.visits.single.startMinutes, 600);
    expect(result.days.single.visits.single.endMinutes, 675);
  });

  for (final scenario in [
    (meal: MealType.lunch, start: 660, end: 840),
    (meal: MealType.dinner, start: 1020, end: 1230),
  ]) {
    test('跨城前往${scenario.meal.label}時會提前出發並維持合理時段', () async {
      transport.travelMinutes = 13 * 60;
      final result = await planner.generate(
        request: _request(days: 2),
        places: [
          RoutePlaceInput(
            place: _place(
              'taipei-hotel',
              type: PlaceType.accommodation,
              county: '台北市',
              latitude: 25.04,
              longitude: 121.56,
            ),
            preferences: const VisitPreferences(
              hotelStay: HotelStay(checkInDay: 1, checkOutDay: 2),
            ),
          ),
          RoutePlaceInput(
            place: _place(
              '${scenario.meal.name}-restaurant',
              type: PlaceType.restaurant,
              county: '高雄市',
              latitude: 22.63,
              longitude: 120.30,
            ),
            day: 2,
            preferences: VisitPreferences(mealType: scenario.meal),
          ),
        ],
      );

      final meal = result.days[1].visits.single;
      expect(meal.startMinutes, inInclusiveRange(scenario.start, scenario.end));
      expect(
        result.days[1].travelLegs.single.requestedDeparture.hour,
        lessThan(9),
      );
    });
  }

  test('連住兩晚每天以飯店收尾，隔日起點為前一晚飯店', () async {
    final hotel = _place(
      'hotel',
      type: PlaceType.accommodation,
      latitude: 25.06,
    );
    final result = await planner.generate(
      request: _request(days: 3),
      places: [
        RoutePlaceInput(
          place: hotel,
          preferences: const VisitPreferences(
            hotelStay: HotelStay(checkInDay: 1, checkOutDay: 3),
          ),
        ),
        RoutePlaceInput(place: _place('first'), day: 1),
        RoutePlaceInput(place: _place('second'), day: 2),
        RoutePlaceInput(place: _place('third'), day: 3),
      ],
    );
    final hotelVisits = result.days
        .expand((day) => day.visits)
        .where((visit) => visit.place.id == 'hotel')
        .toList();
    expect(hotelVisits, hasLength(2));
    expect(
      hotelVisits.every((visit) => visit.kind == VisitKind.hotelStay),
      isTrue,
    );
    expect(
      hotelVisits.map((visit) => visit.occurrenceId).toSet(),
      hasLength(2),
    );
    expect(result.days[0].visits.last.kind, VisitKind.hotelStay);
    expect(result.days[1].origin.id, hotel.id);
    expect(result.days[1].visits.first.place.id, 'second');
    expect(result.days[1].travelLegs.first.origin.id, hotel.id);
    expect(result.days[1].travelLegs.first.destination.id, 'second');
    expect(result.days[1].visits.last.kind, VisitKind.hotelStay);
    expect(result.days[1].travelLegs.last.destination.id, 'hotel:hotelStay:2');
    expect(result.days[2].origin.id, hotel.id);
    expect(result.days[2].visits.first.kind, VisitKind.activity);
    expect(result.days[2].travelLegs.first.origin.id, hotel.id);
    expect(result.inputs, hasLength(4));
    expect(hotelVisits.first.information.join(), contains('最早抵達時間未知'));
  });

  test('飯店固定排在晚餐後並包含前往飯店的交通', () async {
    final result = await planner.generate(
      request: _request(days: 2),
      places: [
        RoutePlaceInput(
          place: _place(
            'hotel',
            type: PlaceType.accommodation,
            latitude: 25.06,
          ),
          preferences: const VisitPreferences(
            hotelStay: HotelStay(checkInDay: 1, checkOutDay: 2),
          ),
        ),
        RoutePlaceInput(
          place: _place('dinner', type: PlaceType.restaurant),
          day: 1,
          preferences: const VisitPreferences(mealType: MealType.dinner),
        ),
      ],
    );
    expect(result.days.first.visits.map((visit) => visit.kind), [
      VisitKind.activity,
      VisitKind.hotelStay,
    ]);
    expect(result.days.first.travelLegs, hasLength(1));
    expect(result.days.first.travelLegs.last.origin.id, 'dinner');
    expect(
      result.days.first.travelLegs.last.destination.id,
      'hotel:hotelStay:1',
    );
  });

  test('更換飯店時從前一晚飯店前往新飯店', () async {
    final result = await planner.generate(
      request: _request(days: 3),
      places: [
        RoutePlaceInput(
          place: _place('hotel-a', type: PlaceType.accommodation),
          preferences: const VisitPreferences(
            hotelStay: HotelStay(checkInDay: 1, checkOutDay: 2),
          ),
        ),
        RoutePlaceInput(
          place: _place(
            'hotel-b',
            type: PlaceType.accommodation,
            latitude: 25.07,
          ),
          preferences: const VisitPreferences(
            hotelStay: HotelStay(checkInDay: 2, checkOutDay: 3),
          ),
        ),
      ],
    );
    expect(result.days[1].origin.id, 'hotel-a');
    expect(result.days[1].visits.single.occurrenceId, 'hotel-b:hotelStay:2');
    expect(result.days[1].travelLegs.single.origin.id, 'hotel-a');
    expect(
      result.days[1].travelLegs.single.destination.id,
      'hotel-b:hotelStay:2',
    );
    expect(result.days[2].origin.id, 'hotel-b');
  });

  test('連住期間整天空白仍以飯店收尾，不產生同座標假交通', () async {
    final result = await planner.generate(
      request: _request(days: 3),
      places: [
        RoutePlaceInput(
          place: _place('hotel', type: PlaceType.accommodation),
          preferences: const VisitPreferences(
            hotelStay: HotelStay(checkInDay: 1, checkOutDay: 3),
          ),
        ),
      ],
    );
    expect(result.days[1].visits.single.kind, VisitKind.hotelStay);
    expect(result.days[1].origin.id, 'hotel');
    expect(transport.calls, isEmpty);
  });

  test('住宿可延續到旅程結束隔日且不建立額外旅遊日', () async {
    final result = await planner.generate(
      request: _request(),
      places: [
        RoutePlaceInput(
          place: _place('hotel', type: PlaceType.accommodation),
          preferences: const VisitPreferences(
            hotelStay: HotelStay(checkInDay: 1, checkOutDay: 2),
          ),
        ),
      ],
    );
    expect(result.days, hasLength(1));
    expect(result.days.single.visits.single.kind, VisitKind.hotelStay);
    expect(
      result.days.single.visits.single.information.join(),
      allOf(contains('至 Day 2'), contains('每天最後一站')),
    );
  });

  test('缺座標與同晚住宿重疊都在交通查詢前拒絕', () async {
    for (final inputs in <List<RoutePlaceInput>>[
      [
        RoutePlaceInput(
          place: _place('missing', latitude: 0, type: PlaceType.accommodation),
          preferences: const VisitPreferences(
            hotelStay: HotelStay(checkInDay: 1, checkOutDay: 2),
          ),
        ),
      ],
      [
        for (final name in ['first', 'second'])
          RoutePlaceInput(
            place: _place(name, type: PlaceType.accommodation),
            preferences: const VisitPreferences(
              hotelStay: HotelStay(checkInDay: 1, checkOutDay: 2),
            ),
          ),
      ],
    ]) {
      await expectLater(
        planner.generate(request: _request(days: 2), places: inputs),
        throwsStateError,
      );
    }
    expect(transport.calls, isEmpty);
  });

  test('未設定住宿日期會自動涵蓋旅程住宿夜晚', () async {
    final result = await planner.generate(
      request: _request(days: 3),
      places: [
        RoutePlaceInput(place: _place('hotel', type: PlaceType.accommodation)),
      ],
    );
    final stay = result.inputs.single.preferences.hotelStay;
    expect(stay?.checkInDay, 1);
    expect(stay?.checkOutDay, 3);
    expect(
      result.days
          .take(2)
          .every((day) => day.visits.last.kind == VisitKind.hotelStay),
      isTrue,
    );
    expect(result.days.last.visits, isEmpty);
    expect(result.days.first.origin.id, 'hotel:hotelStay:1');
    expect(
      result.days.skip(1).map((day) => day.origin.id),
      everyElement('hotel'),
    );
    expect(transport.calls, isEmpty);
  });

  test('多間未設定住宿會依旅程夜晚自動分段', () async {
    final result = await planner.generate(
      request: _request(days: 3),
      places: [
        RoutePlaceInput(
          place: _place('hotel-a', type: PlaceType.accommodation),
        ),
        RoutePlaceInput(
          place: _place(
            'hotel-b',
            type: PlaceType.accommodation,
            latitude: 25.07,
          ),
        ),
      ],
    );
    final stays = {
      for (final input in result.inputs)
        input.place.id: input.preferences.hotelStay,
    };
    expect(stays['hotel-a']?.checkInDay, 1);
    expect(stays['hotel-a']?.checkOutDay, 2);
    expect(stays['hotel-b']?.checkInDay, 2);
    expect(stays['hotel-b']?.checkOutDay, 3);
    expect(result.days[0].visits.single.kind, VisitKind.hotelStay);
    expect(result.days[1].visits.single.kind, VisitKind.hotelStay);
    expect(result.days[2].visits, isEmpty);
  });

  test('自動依飯店縣市分配前兩天，無住宿城市保留最後一天', () async {
    final result = await planner.generate(
      request: _request(days: 3),
      places: [
        RoutePlaceInput(
          place: _place(
            'taipei-hotel',
            type: PlaceType.accommodation,
            county: '台北市',
            latitude: 25.04,
            longitude: 121.56,
          ),
        ),
        RoutePlaceInput(
          place: _place(
            'taichung-hotel',
            type: PlaceType.accommodation,
            county: '台中市',
            latitude: 24.15,
            longitude: 120.68,
          ),
        ),
        RoutePlaceInput(
          place: _place(
            'taipei-place',
            county: '台北市',
            latitude: 25.05,
            longitude: 121.52,
          ),
        ),
        RoutePlaceInput(
          place: _place(
            'taichung-place',
            county: '台中市',
            latitude: 24.16,
            longitude: 120.67,
          ),
        ),
        RoutePlaceInput(
          place: _place(
            'kaohsiung-place',
            county: '高雄市',
            latitude: 22.63,
            longitude: 120.30,
          ),
        ),
      ],
    );

    expect(result.days[0].visits.map((visit) => visit.place.id), [
      'taipei-place',
      'taipei-hotel',
    ]);
    expect(result.days[1].visits.map((visit) => visit.place.id), [
      'taichung-place',
      'taichung-hotel',
    ]);
    expect(result.days[2].visits.map((visit) => visit.place.id), [
      'kaohsiung-place',
    ]);
    expect(result.days[1].origin.id, 'taipei-hotel');
    expect(result.days[2].origin.id, 'taichung-hotel');
    expect(result.days[2].visits.last.kind, VisitKind.activity);
  });

  test('手動指定日期時間與住宿日期不被自動分配覆蓋', () async {
    final result = await planner.generate(
      request: _request(days: 2),
      places: [
        RoutePlaceInput(
          place: _place(
            'taipei-hotel',
            type: PlaceType.accommodation,
            county: '台北市',
          ),
          day: 1,
          preferences: const VisitPreferences(
            hotelStay: HotelStay(checkInDay: 1, checkOutDay: 2),
          ),
        ),
        RoutePlaceInput(
          place: _place(
            'manual-kaohsiung',
            county: '高雄市',
            latitude: 22.63,
            longitude: 120.30,
          ),
          day: 1,
          startMinutes: 480,
          locked: true,
        ),
        RoutePlaceInput(place: _place('automatic-taipei', county: '台北市')),
      ],
    );

    final manualVisit = result.days[0].visits.firstWhere(
      (visit) => visit.place.id == 'manual-kaohsiung',
    );
    expect(manualVisit.startMinutes, 480);
    expect(result.days[0].visits.last.place.id, 'taipei-hotel');
    expect(result.days[0].visits.last.kind, VisitKind.hotelStay);
    expect(result.days[1].visits.single.place.id, 'automatic-taipei');
  });

  test('同日跨縣市無法避免時，優先讓飯店同縣市景點接近當日尾端', () async {
    final result = await planner.generate(
      request: _request(),
      places: [
        RoutePlaceInput(
          place: _place(
            'taipei-hotel',
            type: PlaceType.accommodation,
            county: '台北市',
            latitude: 25.04,
            longitude: 121.56,
          ),
          day: 1,
          preferences: const VisitPreferences(
            hotelStay: HotelStay(checkInDay: 1, checkOutDay: 2),
          ),
        ),
        RoutePlaceInput(
          place: _place(
            'taipei-place',
            county: '台北市',
            latitude: 25.05,
            longitude: 121.52,
          ),
          day: 1,
        ),
        RoutePlaceInput(
          place: _place(
            'kaohsiung-place',
            county: '高雄市',
            latitude: 22.63,
            longitude: 120.30,
          ),
          day: 1,
        ),
      ],
    );

    expect(result.days.single.visits.map((visit) => visit.place.id), [
      'kaohsiung-place',
      'taipei-place',
      'taipei-hotel',
    ]);
  });

  test('明確營業時間與指定餐廳時間衝突時保留安排並警告', () async {
    final result = await planner.generate(
      request: _request(),
      places: [
        RoutePlaceInput(
          place: _place(
            'closed',
            type: PlaceType.restaurant,
            open: 600,
            close: 1080,
          ),
          day: 1,
          startMinutes: 1200,
          locked: true,
          preferences: const VisitPreferences(mealType: MealType.dinner),
        ),
      ],
    );
    expect(result.days.single.visits.single.startMinutes, 1200);
    expect(result.days.single.isValid, isFalse);
    expect(result.warnings.join(), contains('營業時間'));
  });

  test('交通延誤使餐廳固定時間遲到，會由共同衝突檢查指出', () async {
    transport.travelMinutes = 120;
    final result = await planner.generate(
      request: _request(),
      places: [
        RoutePlaceInput(
          place: _place('museum'),
          day: 1,
          startMinutes: 600,
          locked: true,
        ),
        RoutePlaceInput(
          place: _place('meal', type: PlaceType.restaurant),
          day: 1,
          startMinutes: 720,
          locked: true,
          preferences: const VisitPreferences(mealType: MealType.lunch),
        ),
      ],
    );
    expect(result.days.single.visits.last.startMinutes, greaterThan(720));
    expect(result.warnings.join(), contains('晚於指定時間'));
  });

  test('前一天超過午夜，隔天不得倒退時間到前一天活動完成之前', () async {
    final result = await planner.generate(
      request: _request(days: 2),
      places: [
        RoutePlaceInput(
          place: _place('late'),
          day: 1,
          startMinutes: 1380,
          locked: true,
          preferences: const VisitPreferences(durationMinutes: 240),
        ),
        RoutePlaceInput(
          place: _place('early'),
          day: 2,
          startMinutes: 60,
          locked: true,
        ),
      ],
    );
    expect(result.days[0].visits.last.endMinutes, 1620);
    expect(result.days[1].visits.first.startMinutes, greaterThanOrEqualTo(180));
    expect(
      result.days[1].travelLegs.first.requestedDeparture.isBefore(
        DateTime(2030, 1, 2, 3),
      ),
      isFalse,
    );
    expect(result.warnings.join(), contains('超出當天時間'));
  });

  test('交通查不到時不假装班次已確認', () async {
    transport.empty = true;
    final result = await planner.generate(
      request: _request(),
      places: [
        RoutePlaceInput(
          place: _place('first'),
          day: 1,
          startMinutes: 600,
          locked: true,
        ),
        RoutePlaceInput(
          place: _place('meal', type: PlaceType.restaurant),
          day: 1,
        ),
      ],
    );
    expect(
      result.days.single.travelLegs.single.usesEstimatedTravelTime,
      isTrue,
    );
    expect(
      result.days.single.visits.last.information.join(),
      contains('未確認實際可搭乘路線'),
    );
  });

  test('手動抵達飯店早於設定時間會明確警告', () async {
    final result = await planner.generate(
      request: _request(),
      places: [
        RoutePlaceInput(
          place: _place('hotel', type: PlaceType.accommodation),
          day: 1,
          startMinutes: 600,
          locked: true,
          preferences: const VisitPreferences(
            hotelStay: HotelStay(
              checkInDay: 1,
              checkOutDay: 2,
              checkInFromMinutes: 900,
            ),
          ),
        ),
      ],
    );
    expect(result.days.single.visits.first.startMinutes, 600);
    expect(result.warnings.join(), contains('抵達時間早於'));
  });

  test('同日重複餐別不擅自刪除使用者選擇', () async {
    final result = await planner.generate(
      request: _request(),
      places: [
        for (final id in ['lunch-a', 'lunch-b'])
          RoutePlaceInput(
            place: _place(id, type: PlaceType.restaurant),
            preferences: const VisitPreferences(mealType: MealType.lunch),
          ),
      ],
    );
    expect(result.days.single.visits, hasLength(2));
    expect(
      result.days.single.visits.first.information.join(),
      contains('同一天有多筆午餐'),
    );
  });
}

class _Transport extends TimedTdxRouteService {
  final List<DateTime> calls = [];
  int travelMinutes = 20;
  bool empty = false;
  _Transport() : super(requestInterval: Duration.zero);

  @override
  Future<TdxRoute?> getRouteAtOrAfter({
    required String origin,
    required String destination,
    required DateTime requestedDeparture,
    void Function(DateTime queryTime)? onRetry,
  }) async {
    calls.add(requestedDeparture);
    if (empty) return null;
    return TdxRoute(
      transfers: 0,
      travelTime: travelMinutes * 60,
      startTime: requestedDeparture,
      endTime: requestedDeparture.add(Duration(minutes: travelMinutes)),
      sections: const [],
    );
  }
}

TripRequest _request({int days = 1}) => TripRequest(
  title: '測試旅程',
  startDate: DateTime(2030, 1, 1),
  endDate: DateTime(2030, 1, days),
  location: '',
  people: 2,
  budget: 5000,
  preferences: const [],
  aiPrompt: '',
);

Place _place(
  String id, {
  PlaceType type = PlaceType.attraction,
  double latitude = 25.05,
  double longitude = 121.52,
  String county = '',
  int open = 0,
  int close = 1440,
}) => Place(
  id: id,
  name: id,
  category: '',
  description: '',
  address: '',
  latitude: latitude,
  longitude: longitude,
  type: type,
  county: county,
  image: '',
  stayTime: 60,
  rating: 0,
  tags: const [],
  estimatedCost: 0,
  openMinutes: open,
  closeMinutes: close,
);
