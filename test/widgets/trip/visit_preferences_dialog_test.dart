import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/algorithm/route_optimizer.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_day.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_itinerary.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_place_input.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_visit.dart';
import 'package:taipei_travel_app/features/route_planning/pages/itinerary_result_page.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/models/trip_place_constraint.dart';
import 'package:taipei_travel_app/models/trip_request.dart';
import 'package:taipei_travel_app/models/visit_preferences.dart';
import 'package:taipei_travel_app/pages/trip_planner_page.dart';
import 'package:taipei_travel_app/widgets/trip/visit_preferences_dialog.dart';

void main() {
  testWidgets('停留時間先顯示預設，未修改時仍保存為預估', (tester) async {
    VisitPreferences? saved;
    await _open(tester, _place(PlaceType.restaurant), (value) => saved = value);
    final durationField = tester.widget<TextField>(_field('停留／用餐時間（分鐘）'));
    expect(durationField.controller?.text, '60');
    expect(find.textContaining('系統預設，會直接用於排程'), findsOneWidget);
    await tester.tap(find.text('套用設定'));
    await tester.pumpAndSettle();
    expect(saved?.durationMinutes, isNull);
    expect(saved?.durationFor(_place(PlaceType.restaurant)), 60);
  });

  testWidgets('安排頁可從餐廳卡片開啟設定且不溢位', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: TripPlannerPage(
          request: _request(),
          places: [_place(PlaceType.restaurant)],
        ),
      ),
    );
    await tester.tap(find.text('安排餐廳'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新增餐廳'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.text('套用選擇'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('時段、停留與資訊來源'));
    await tester.pumpAndSettle();
    expect(find.text('餐別'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('餐廳自訂時段及停留可儲存，設定不等於訂位', (tester) async {
    VisitPreferences? saved;
    await _open(tester, _place(PlaceType.restaurant), (value) => saved = value);
    await tester.tap(find.byType(DropdownButtonFormField<MealType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('晚餐').last);
    await tester.pumpAndSettle();
    await tester.enterText(_field('偏好開始（HH:mm）'), '18:00');
    await tester.enterText(_field('偏好結束（HH:mm）'), '21:00');
    await tester.enterText(_field('停留／用餐時間（分鐘）'), '80');
    await tester.tap(find.text('套用設定'));
    await tester.pumpAndSettle();
    expect(saved?.mealType, MealType.dinner);
    expect(saved?.mealWindowStart, 1080);
    expect(saved?.mealWindowEnd, 1260);
    expect(saved?.durationMinutes, 80);
    expect(tester.takeException(), isNull);
  });

  testWidgets('用餐時段只填一端會要求補齊', (tester) async {
    VisitPreferences? saved;
    await _open(tester, _place(PlaceType.restaurant), (value) => saved = value);
    await tester.enterText(_field('偏好開始（HH:mm）'), '11:00');
    await tester.tap(find.text('套用設定'));
    await tester.pumpAndSettle();
    expect(find.text('用餐時段需同時設定開始與結束時間。'), findsOneWidget);
    expect(saved, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('飯店設定說明每日最後一站與隔日出發', (tester) async {
    VisitPreferences? saved;
    await _open(
      tester,
      _place(PlaceType.accommodation),
      (value) => saved = value,
      day: 3,
    );
    expect(find.textContaining('這不代表已完成訂房'), findsOneWidget);
    expect(find.textContaining('不會在隔日早上重複顯示'), findsOneWidget);
    expect(find.text('最晚完成退房（HH:mm）'), findsNothing);
    await tester.tap(find.text('套用設定'));
    await tester.pumpAndSettle();
    expect(saved?.hotelStay?.checkInDay, 3);
    expect(saved?.hotelStay?.checkOutDay, 4);
    expect(saved?.hotelStay?.checkInFromMinutes, isNull);
    expect(saved?.hotelStay?.effectiveCheckInFrom, 900);
    expect(tester.takeException(), isNull);
  });

  testWidgets('結果页短時段卡片不溢位且修改設定不重複產生住宿輸入', (tester) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final hotel = _place(PlaceType.accommodation);
    final meal = _place(PlaceType.restaurant);
    const hotelPreferences = VisitPreferences(
      hotelStay: HotelStay(checkInDay: 1, checkOutDay: 2),
    );
    const mealPreferences = VisitPreferences(
      mealType: MealType.lunch,
      durationMinutes: 45,
    );
    final origin = RouteStop.fromPlace(hotel);
    final itinerary = RouteItinerary(
      request: _request(),
      origin: origin,
      generatedAt: DateTime(2030),
      inputs: [
        RoutePlaceInput(place: hotel, day: 1, preferences: hotelPreferences),
        RoutePlaceInput(place: meal, day: 1, preferences: mealPreferences),
      ],
      days: [
        RouteDay(
          day: 1,
          date: DateTime(2030, 1, 1),
          origin: origin,
          isValid: true,
          travelLegs: const [],
          visits: [
            RouteVisit(
              place: hotel,
              sequence: 1,
              arrivalMinutes: 0,
              startMinutes: 0,
              endMinutes: 30,
              waitingMinutes: 0,
              stayMinutes: 30,
              requestedStartMinutes: null,
              locked: false,
              kind: VisitKind.hotelStay,
              eventId: 'hotel:hotelStay:1',
              preferences: hotelPreferences,
            ),
            RouteVisit(
              place: meal,
              sequence: 2,
              arrivalMinutes: 60,
              startMinutes: 60,
              endMinutes: 105,
              waitingMinutes: 0,
              stayMinutes: 45,
              requestedStartMinutes: null,
              locked: false,
              preferences: mealPreferences,
              mealType: MealType.lunch,
              information: const ['營業時間未知'],
            ),
          ],
        ),
      ],
    );
    List<TripPlaceConstraint>? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: ItineraryResultPage(
          itinerary: itinerary,
          onRecalculate:
              (inputs, travelModeOverrides, previousItinerary) async {
                captured = inputs;
                return itinerary;
              },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.textContaining('restaurant・午餐').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('營業時間未知'), findsWidgets);
    await tester.enterText(_field('停留／用餐時間（分鐘）'), '80');
    await tester.tap(find.text('套用設定'));
    await tester.pumpAndSettle();
    expect(captured, hasLength(2));
    final updatedMeal = captured!.singleWhere(
      (item) => item.place.type == PlaceType.restaurant,
    );
    expect(updatedMeal.day, 1);
    expect(updatedMeal.preferences.mealType, MealType.lunch);
    expect(updatedMeal.stayMinutes, 80);
    final updatedHotel = captured!.singleWhere(
      (item) => item.place.type == PlaceType.accommodation,
    );
    expect(updatedHotel.preferences.hotelStay?.checkOutDay, 2);
    expect(tester.takeException(), isNull);
  });
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _open(
  WidgetTester tester,
  Place place,
  void Function(VisitPreferences?) saved, {
  int? day,
}) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => saved(
              await showVisitPreferencesDialog(
                context: context,
                place: place,
                request: _request(),
                initial: const VisitPreferences(),
                day: day,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

TripRequest _request() => TripRequest(
  title: '旅程',
  startDate: DateTime(2030, 1, 1),
  endDate: DateTime(2030, 1, 3),
  location: '',
  people: 2,
  budget: 5000,
  preferences: const [],
  aiPrompt: '',
);
Place _place(PlaceType type) => Place(
  id: type.name,
  name: type.name,
  category: '',
  description: '',
  address: '',
  latitude: 25.05,
  longitude: 121.52,
  type: type,
  image: '',
  stayTime: 60,
  rating: 0,
  tags: const [],
  estimatedCost: 0,
  openMinutes: 0,
  closeMinutes: 1440,
);
