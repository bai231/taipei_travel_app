import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/algorithm/route_optimizer.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_day.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_itinerary.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_place_input.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_visit.dart';
import 'package:taipei_travel_app/features/route_planning/models/travel_leg.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_travel_mode.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/models/scheduled_visit.dart';
import 'package:taipei_travel_app/models/tdx_route.dart';
import 'package:taipei_travel_app/models/trip_request.dart';
import 'package:taipei_travel_app/models/travel_preference.dart';
import 'package:taipei_travel_app/models/visit_preferences.dart';
import 'package:taipei_travel_app/services/itinerary_snapshot.dart';
import 'package:taipei_travel_app/services/itinerary_snapshot_reader.dart';
import 'package:taipei_travel_app/services/saved_itinerary_service.dart';
import 'package:taipei_travel_app/widgets/trip/save_itinerary_button.dart';

class FakeSaveGateway implements SavedItineraryGateway {
  @override
  String? currentUserId = 'a';
  final ids = <String>[];
  final snapshots = <Map<String, dynamic>>[];
  Completer<void>? pending;
  bool fail = false;
  @override
  Future<void> save({
    required String id,
    required String userId,
    required String title,
    required Map<String, dynamic> snapshot,
  }) async {
    ids.add(id);
    snapshots.add(snapshot);
    if (pending != null) await pending!.future;
    if (fail) throw StateError('test failure');
  }
  // 不知道為什麼的錯誤就先修了
  // 🌟 將 list 簽名修正為接受可選具名參數 limit 與 offset，並回傳明確的 Map 型別
  @override
  Future<List<Map<String, dynamic>>> list({int? limit, int? offset}) async {
    return []; // 測試預設回傳空列表，或回傳你的 mock 資料
  }

  // 順便確認 read 方法的簽名（如果是需要 id 的話）：
  @override
  Future<Map<String, dynamic>> read(String id) async {
    return <String, dynamic>{}; 
  }
}

RouteItinerary sample({bool withPreference = false}) {
  final date = DateTime(2026, 9, 12);
  final place = Place.fromJson({
    'id': 42,
    'name': '測試景點',
    'latitude': 25.0,
    'longitude': 121.0,
    'priceLevel': 3,
  });
  final stop = RouteStop(
    id: '42',
    name: place.name,
    latitude: 25,
    longitude: 121,
    stayDurationMinutes: 60,
  );
  return RouteItinerary(
    request: TripRequest(
      title: '兩日行程',
      startDate: date,
      endDate: date.add(const Duration(days: 1)),
      location: '台北市',
      people: 2,
      budget_level: 2,
      preferences: ['自然'],
      aiPrompt: '',
      parsedPreference: withPreference
          ? TravelPreference.fromJson({
              'preferredCategories': ['nature'],
              'dailyBudget': 2000,
              'summary': '喜歡自然景點',
            })
          : null,
    ),
    origin: stop,
    generatedAt: date,
    days: [
      for (var day = 1; day <= 2; day++)
        RouteDay(
          day: day,
          date: date.add(Duration(days: day - 1)),
          origin: stop,
          isValid: true,
          visits: [
            RouteVisit(
              place: place,
              sequence: 1,
              arrivalMinutes: 1450,
              startMinutes: 1450,
              endMinutes: 1510,
              waitingMinutes: 0,
              stayMinutes: 60,
              requestedStartMinutes: null,
              locked: false,
              eventId: '42:day:$day',
            ),
          ],
          travelLegs: [
            TravelLeg(
              origin: stop,
              destination: stop,
              requestedDeparture: date,
              travelMode: RouteTravelMode.walking,
              schedule: const ScheduledVisit(
                departureMinutes: 1440,
                arrivalMinutes: 1450,
                visitStartMinutes: 1450,
                visitEndMinutes: 1510,
                waitingMinutes: 0,
                stayMinutes: 60,
              ),
            ),
          ],
        ),
    ],
  );
}

void main() {
  test('v2 restores editable meal choices and transport override', () {
    final base = sample();
    final restaurant = Place.fromJson({
      'id': 'restaurant-1',
      'name': '測試餐廳',
      'latitude': 25.0,
      'longitude': 121.0,
    }, forcedType: PlaceType.restaurant);
    final legKey = routeLegKey(
      day: 1,
      originId: '42',
      destinationId: restaurant.id,
    );
    final itinerary = RouteItinerary(
      request: base.request,
      origin: base.origin,
      days: base.days,
      generatedAt: base.generatedAt,
      inputs: [
        RoutePlaceInput(
          place: restaurant,
          day: 1,
          startMinutes: 720,
          locked: true,
          preferences: const VisitPreferences(
            mealType: MealType.lunch,
            durationMinutes: 75,
          ),
          suggestedMealType: MealType.lunch,
        ),
      ],
      travelModeOverrides: {legKey: RouteTravelMode.walking},
    );
    final restored = itineraryFromSnapshot(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(itinerarySnapshot(itinerary))) as Map,
      ),
    );
    expect(restored.inputs.single.place.type, PlaceType.restaurant);
    expect(restored.inputs.single.locked, isTrue);
    expect(restored.inputs.single.startMinutes, 720);
    expect(restored.inputs.single.preferences.durationMinutes, 75);
    expect(restored.inputs.single.suggestedMealType, MealType.lunch);
    expect(restored.travelModeOverrides[legKey], RouteTravelMode.walking);
  });

  test(
    'v2 snapshot restores displayed days and route modes without replanning',
    () {
      final raw = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(itinerarySnapshot(sample(withPreference: true))))
            as Map,
      );
      final restored = itineraryFromSnapshot(raw);
      expect(restored.days, hasLength(2));
      expect(restored.days.first.visits.first.startMinutes, 1450);
      expect(restored.days.last.visits.first.occurrenceId, '42:day:2');
      expect(
        restored.days.first.travelLegs.first.travelMode,
        RouteTravelMode.walking,
      );
      expect(restored.request.parsedPreference?.dailyBudget, 2000);
    },
  );

  test('v2 snapshot retains Google transit fallback provenance', () {
    final base = sample();
    final firstDay = base.days.first;
    final oldLeg = firstDay.travelLegs.first;
    final fallbackLeg = TravelLeg(
      origin: oldLeg.origin,
      destination: oldLeg.destination,
      requestedDeparture: oldLeg.requestedDeparture,
      schedule: oldLeg.schedule,
      travelMode: RouteTravelMode.transit,
      routeProvider: RouteProvider.google,
      route: TdxRoute(
        transfers: 0,
        travelTime: 1200,
        sections: [
          RouteSection(
            mode: 'bus',
            lineName: '307',
            travelTime: 1200,
            stopCount: 3,
            intermediateStops: const [],
          ),
        ],
      ),
    );
    final itinerary = RouteItinerary(
      request: base.request,
      origin: base.origin,
      generatedAt: base.generatedAt,
      days: [
        RouteDay(
          day: firstDay.day,
          date: firstDay.date,
          origin: firstDay.origin,
          isValid: firstDay.isValid,
          visits: firstDay.visits,
          travelLegs: [fallbackLeg],
        ),
        base.days.last,
      ],
    );
    final snapshot = itinerarySnapshot(itinerary);
    expect(snapshot['days'][0]['travelLegs'][0]['routeProvider'], 'google');
    final restored = itineraryFromSnapshot(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(snapshot)) as Map),
    );
    expect(
      restored.days.first.travelLegs.first.routeSourceLabel,
      'Google Maps（TDX 備援）',
    );
  });

  test('v2 keeps parsed monetary daily budget separate from budget level', () {
    final data = jsonDecode(
      jsonEncode(itinerarySnapshot(sample(withPreference: true))),
    );
    expect(data['request']['budgetLevel'], 2);
    expect(data['request']['parsedPreference']['dailyBudget'], 2000);
    expect(data['request']['parsedPreference']['preferredCategories'], [
      'nature',
    ]);
    expect(decodeItinerarySnapshot(Map<String, dynamic>.from(data)), data);
  });

  test('v1, missing, string and unknown versions fail; days are required', () {
    final legacy = <String, dynamic>{
      'schemaVersion': 1,
      'request': {'budget': 2000},
      'days': [],
    };
    expect(() => decodeItinerarySnapshot(legacy), throwsFormatException);
    expect(() => decodeItinerarySnapshot({'days': []}), throwsFormatException);
    expect(
      () => decodeItinerarySnapshot({'schemaVersion': '2', 'days': []}),
      throwsFormatException,
    );
    expect(
      () => decodeItinerarySnapshot({'schemaVersion': 99, 'days': []}),
      throwsFormatException,
    );
    expect(
      () => decodeItinerarySnapshot({'schemaVersion': 2}),
      throwsFormatException,
    );
  });

  test(
    'JSON snapshot preserves days, occurrences, cross-midnight time and modes',
    () {
      final data = jsonDecode(jsonEncode(itinerarySnapshot(sample())));
      expect(data['schemaVersion'], 2);
      expect(data['request']['budgetLevel'], 2);
      expect(data['request'].containsKey('budget'), isFalse);
      expect(data['request']['parsedPreference'], isNull);
      expect(data['days'][0]['visits'][0]['place']['priceLevel'], 3);
      expect(
        data['days'][0]['visits'][0]['place'].containsKey('estimatedCost'),
        isFalse,
      );
      expect(data['days'].length, 2);
      expect(data['days'][0]['visits'][0]['startMinutes'], 1450);
      expect(data['days'][1]['visits'][0]['occurrenceId'], '42:day:2');
      expect(data['days'][0]['travelLegs'][0]['travelMode'], 'walking');
      expect(data['days'][0]['travelLegs'][0]['usesEstimatedTravelTime'], true);
      expect(data['days'][0]['visits'][0]['place']['name'], '測試景點');
    },
  );

  Widget app(FakeSaveGateway gateway, {bool enabled = true}) => MaterialApp(
    home: Scaffold(
      body: SaveItineraryButton(
        itinerary: sample(),
        gateway: gateway,
        enabled: enabled,
      ),
    ),
  );

  testWidgets('signed out prompts login without writing', (tester) async {
    final gateway = FakeSaveGateway()..currentUserId = null;
    await tester.pumpWidget(app(gateway));
    await tester.tap(find.byTooltip('儲存行程'));
    await tester.pump();
    expect(gateway.ids, isEmpty);
    expect(find.text('請先登入，再儲存行程'), findsOneWidget);
  });

  testWidgets(
    'no automatic write, busy blocks clicks, repeated saves share id',
    (tester) async {
      final gateway = FakeSaveGateway()..pending = Completer<void>();
      await tester.pumpWidget(app(gateway));
      expect(gateway.ids, isEmpty);
      await tester.tap(find.byTooltip('儲存行程'));
      await tester.pump();
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      expect(gateway.ids.length, 1);
      gateway.pending!.complete();
      await tester.pumpAndSettle();
      gateway.pending = null;
      await tester.tap(find.byTooltip('儲存行程'));
      await tester.pumpAndSettle();
      expect(gateway.ids.length, 2);
      expect(gateway.ids.toSet().length, 1);
      expect(gateway.snapshots.first['days'], hasLength(2));
    },
  );

  testWidgets('failure retry keeps id, another account gets a different id', (
    tester,
  ) async {
    final gateway = FakeSaveGateway()..fail = true;
    await tester.pumpWidget(app(gateway));
    await tester.tap(find.byTooltip('儲存行程'));
    await tester.pumpAndSettle();
    expect(find.textContaining('儲存失敗'), findsOneWidget);
    gateway.fail = false;
    await tester.tap(find.byTooltip('儲存行程'));
    await tester.pumpAndSettle();
    expect(gateway.ids[0], gateway.ids[1]);
    gateway.currentUserId = 'b';
    await tester.tap(find.byTooltip('儲存行程'));
    await tester.pumpAndSettle();
    expect(gateway.ids[2], isNot(gateway.ids[0]));
  });

  testWidgets('pending or empty itinerary may disable saving', (tester) async {
    final gateway = FakeSaveGateway();
    await tester.pumpWidget(app(gateway, enabled: false));
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    expect(gateway.ids, isEmpty);
  });

  testWidgets('editing a saved trip upserts the original id only on click', (
    tester,
  ) async {
    final gateway = FakeSaveGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaveItineraryButton(
            itinerary: sample(),
            gateway: gateway,
            savedItineraryId: '0123456789abcdef0123456789abcdef',
          ),
        ),
      ),
    );
    expect(gateway.ids, isEmpty);
    await tester.tap(find.byTooltip('儲存行程'));
    await tester.pumpAndSettle();
    expect(gateway.ids, ['0123456789abcdef0123456789abcdef']);
  });

  testWidgets('a first save returns its id for later edits', (tester) async {
    final gateway = FakeSaveGateway();
    String? savedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaveItineraryButton(
            itinerary: sample(),
            gateway: gateway,
            onSaved: (id) => savedId = id,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('儲存行程'));
    await tester.pumpAndSettle();
    expect(savedId, gateway.ids.single);
  });
}
