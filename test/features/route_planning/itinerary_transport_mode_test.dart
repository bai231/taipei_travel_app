import 'package:flutter/material.dart';
import 'package:taipei_travel_app/models/tdx_route.dart';
import 'package:taipei_travel_app/features/route_planning/widgets/travel_leg_card.dart';
import 'package:flutter/foundation.dart';
import 'package:taipei_travel_app/features/route_planning/widgets/android_day_itinerary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/algorithm/route_optimizer.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_day.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_itinerary.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_travel_mode.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_visit.dart';
import 'package:taipei_travel_app/features/route_planning/models/travel_leg.dart';
import 'package:taipei_travel_app/features/route_planning/pages/itinerary_result_page.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/models/scheduled_visit.dart';
import 'package:taipei_travel_app/models/trip_request.dart';

void main() {
  testWidgets('Android 交通大項常駐，站名各段獨立展開且字體較小', (tester) async {
    final base = _itinerary(
      RouteTravelMode.transit,
    ).days.first.travelLegs.first;
    final leg = TravelLeg(
      origin: base.origin,
      destination: base.destination,
      requestedDeparture: base.requestedDeparture,
      schedule: base.schedule,
      route: TdxRoute(
        transfers: 1,
        travelTime: 1200,
        sections: [
          RouteSection(
            mode: 'walking',
            travelTime: 120,
            stopCount: 0,
            intermediateStops: [],
            departureTitle: 'place',
            arrivalTitle: '車站入口',
          ),
          RouteSection(
            mode: 'waiting',
            travelTime: 180,
            stopCount: 0,
            intermediateStops: [],
          ),
          RouteSection(
            mode: 'train',
            travelTime: 600,
            stopCount: 3,
            intermediateStops: ['中途站甲'],
            departureTitle: '台北站',
            arrivalTitle: '松山站',
          ),
          RouteSection(
            mode: 'bus',
            lineName: '公車123',
            travelTime: 480,
            stopCount: 2,
            intermediateStops: ['公車中途站'],
            departureTitle: '公車站',
            arrivalTitle: 'place',
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: TravelLegCard(leg: leg)),
        ),
      ),
    );
    expect(find.text('步行'), findsOneWidget);
    expect(find.text('台鐵／火車'), findsOneWidget);
    expect(find.text('公車・公車123'), findsOneWidget);
    expect(find.textContaining('台北站 → 松山站'), findsNothing);
    await tester.tap(find.text('台鐵／火車'));
    await tester.pumpAndSettle();
    expect(find.textContaining('台北站 → 松山站'), findsOneWidget);
    expect(find.textContaining('步行起點 →'), findsNothing);
    final title = tester.widget<Text>(find.text('台鐵／火車'));
    final detailStyle = DefaultTextStyle.of(
      tester.element(find.text('台北站 → 松山站')),
    ).style;
    expect(title.style!.fontSize, greaterThan(detailStyle.fontSize!));
    await tester.tap(find.text('台鐵／火車'));
    await tester.pumpAndSettle();
    expect(find.textContaining('台北站 → 松山站'), findsNothing);
    expect(find.text('台鐵／火車'), findsOneWidget);
    expect(find.text('waiting'), findsNothing);
    expect(find.byType(ExpansionTile), findsNWidgets(3));
    await tester.tap(find.text('步行'));
    await tester.pumpAndSettle();
    expect(find.text('${base.origin.name} → 車站入口'), findsOneWidget);
    await tester.tap(find.text('步行'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('公車・公車123'));
    await tester.pumpAndSettle();
    expect(find.text('公車站 → ${base.destination.name}'), findsOneWidget);
    await tester.tap(find.text('公車・公車123'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('展開細項'));
    await tester.pumpAndSettle();
    expect(find.textContaining('等候時間：約 3 分鐘'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  testWidgets('Android 交通次要資訊預設隱藏並可展開收合', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TravelLegCard(
              leg: _itinerary(
                RouteTravelMode.transit,
              ).days.first.travelLegs.first,
              onTravelModeChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('尚未取得實際路線'), findsOneWidget);
    expect(find.textContaining('資料來源：'), findsNothing);
    await tester.tap(find.text('展開細項'));
    await tester.pumpAndSettle();
    expect(find.textContaining('資料來源：'), findsOneWidget);
    await tester.tap(find.text('收合細項'));
    await tester.pumpAndSettle();
    expect(find.textContaining('資料來源：'), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  testWidgets('Android 預設單日列表，總覽縮小仍保留名稱', (tester) async {
    int? droppedMinutes;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.5)),
          child: child!,
        ),
        home: ItineraryResultPage(
          itinerary: _itinerary(RouteTravelMode.transit),
          onRecalculate: (constraints, modes, previous) async {
            droppedMinutes = constraints.first.startMinutes;
            return previous;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AndroidDayItinerary), findsOneWidget);
    expect(find.byTooltip('匯出行程'), findsNothing);
    expect(find.text('測試景點'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final gap = find.textContaining('空白 · 點開／拖曳停留');
    expect(gap, findsOneWidget);
    final hover = await tester.startGesture(
      tester.getCenter(find.text('測試景點')),
    );
    await tester.pump(const Duration(milliseconds: 650));
    await hover.moveTo(tester.getCenter(gap));
    await tester.pump(const Duration(milliseconds: 600));
    expect(gap, findsNothing);
    await hover.up();
    await tester.pumpAndSettle();
    expect(gap, findsOneWidget);
    final start = tester.getCenter(find.text('測試景點'));
    await tester.tap(find.text('展開全部時段'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 650));
    await gesture.moveTo(start + const Offset(0, 150));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(droppedMinutes, isNotNull);
    expect(droppedMinutes, greaterThan(20));
    await tester.tap(find.text('多日總覽'));
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.byTooltip('縮小行程表')).dy,
      tester.getCenter(find.byTooltip('放大行程表')).dy,
    );
    await tester.tap(find.byTooltip('縮小行程表'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('縮小行程表'));
    await tester.pumpAndSettle();
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('測試景點'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('單日課表'));
    await tester.pumpAndSettle();
    expect(find.byType(AndroidDayItinerary), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  testWidgets('手機大字體行程表可縮放且提醒預設收合', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = _itinerary(RouteTravelMode.transit);
    final itinerary = RouteItinerary(
      request: original.request,
      origin: original.origin,
      days: original.days,
      generatedAt: original.generatedAt,
      warnings: ['景點 已超出當天時間', '景點 已超出當天時間', '景點 重複出現，已只保留一次。'],
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.5)),
          child: child!,
        ),
        home: ItineraryResultPage(itinerary: itinerary),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('1 項行程提醒 · 查看'), findsOneWidget);
    expect(find.text('景點 已超出當天時間'), findsNothing);
    await tester.tap(find.byTooltip('縮小行程表'));
    await tester.pumpAndSettle();
    expect(find.text('80%'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('放大行程表'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    await tester.tap(find.text('1 項行程提醒 · 查看'));
    await tester.pumpAndSettle();
    expect(find.text('景點 已超出當天時間'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  testWidgets('只切換使用者選取的交通路段', (tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<RouteLegKey, RouteTravelMode>? requestedOverrides;

    await tester.pumpWidget(
      MaterialApp(
        home: ItineraryResultPage(
          itinerary: _itinerary(RouteTravelMode.transit),
          onRecalculate:
              (constraints, travelModeOverrides, previousItinerary) async {
                requestedOverrides = travelModeOverrides;
                return _itinerary(RouteTravelMode.walking);
              },
        ),
      ),
    );

    expect(find.byType(DropdownButton<RouteTravelMode>), findsNothing);
    expect(find.byType(AndroidDayItinerary), findsNothing);
    await tester.tap(find.byTooltip('交通方式'));
    await tester.pumpAndSettle();
    expect(find.text('起點 → 測試景點'), findsOneWidget);
    await tester.tap(find.text('純步行'));
    await tester.pumpAndSettle();

    expect(requestedOverrides, {
      routeLegKey(day: 1, originId: 'origin', destinationId: 'place'):
          RouteTravelMode.walking,
    });
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}

RouteItinerary _itinerary(RouteTravelMode travelMode) {
  final place = Place(
    id: 'place',
    name: '測試景點',
    category: '景點',
    description: '',
    address: '台北市',
    latitude: 25.04,
    longitude: 121.52,
    image: '',
    stayTime: 60,
    rating: 0,
    tags: const [],
    //estimatedCost: 0,
    price_level: 1,
    openMinutes: 0,
    closeMinutes: 1440,
  );
  const origin = RouteStop(
    id: 'origin',
    name: '起點',
    latitude: 25.03,
    longitude: 121.51,
  );
  final destination = RouteStop.fromPlace(place);
  final leg = TravelLeg(
    origin: origin,
    destination: destination,
    requestedDeparture: DateTime(2030, 1, 1),
    schedule: const ScheduledVisit(
      departureMinutes: 0,
      arrivalMinutes: 20,
      visitStartMinutes: 20,
      visitEndMinutes: 80,
      waitingMinutes: 0,
      stayMinutes: 60,
    ),
    travelMode: travelMode,
  );
  final overrides = travelMode == RouteTravelMode.transit
      ? <RouteLegKey, RouteTravelMode>{}
      : {
          routeLegKey(day: 1, originId: 'origin', destinationId: 'place'):
              travelMode,
        };
  return RouteItinerary(
    request: TripRequest(
      title: '交通模式測試',
      startDate: DateTime(2030, 1, 1),
      endDate: DateTime(2030, 1, 1),
      location: '台北市',
      people: 1,
      budget_level: 1000,
      preferences: const [],
      aiPrompt: '',
    ),
    origin: origin,
    generatedAt: DateTime(2030, 1, 1),
    travelModeOverrides: overrides,
    days: [
      RouteDay(
        day: 1,
        date: DateTime(2030, 1, 1),
        origin: origin,
        isValid: true,
        travelLegs: [leg],
        visits: [
          RouteVisit(
            place: place,
            sequence: 1,
            arrivalMinutes: 20,
            startMinutes: 20,
            endMinutes: 80,
            waitingMinutes: 0,
            stayMinutes: 60,
            requestedStartMinutes: null,
            locked: false,
          ),
        ],
      ),
    ],
  );
}
