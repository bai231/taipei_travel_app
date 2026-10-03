import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/algorithm/route_optimizer.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_day.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_itinerary.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_travel_mode.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_visit.dart';
import 'package:taipei_travel_app/features/route_planning/models/travel_leg.dart';
import 'package:taipei_travel_app/features/route_planning/debug/guardian_debug_controller.dart';
import 'package:taipei_travel_app/features/route_planning/pages/itinerary_result_dependencies.dart';
import 'package:taipei_travel_app/features/route_planning/pages/itinerary_result_page.dart';
import 'package:taipei_travel_app/features/route_planning/services/active_guardian_session.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/models/scheduled_visit.dart';
import 'package:taipei_travel_app/models/tdx_route.dart';
import 'package:taipei_travel_app/models/trip_request.dart';
import 'package:taipei_travel_app/services/location_service.dart';
import 'package:taipei_travel_app/services/live_itinerary_tracking_service.dart';
import 'package:taipei_travel_app/services/google_route_planning_gateway.dart';
import 'package:taipei_travel_app/services/tdx_service.dart';
import 'package:taipei_travel_app/services/transit_realtime_monitor.dart';
import 'package:taipei_travel_app/services/trip_notification_service.dart';
import 'package:taipei_travel_app/services/weather_advisory_service.dart';

void main() {
  test('時間前進但 GPS 沒移動也會重新檢查延誤，且不重複記錄路徑', () async {
    var now = DateTime(2026, 9, 22, 10);
    final location = _FakeLocationGateway(
      const LocationPoint(latitude: 25.04, longitude: 121.52),
    );
    final tracker = LiveItineraryTrackingService(
      locationGateway: location,
      now: () => now,
    );
    final updates = <TripTrackingUpdate>[];
    final subscription = tracker.updates.listen(updates.add);
    expect(await tracker.start(_delayedItinerary(now)), isTrue);
    await Future<void>.delayed(Duration.zero);
    now = DateTime(2026, 9, 22, 10, 30);
    tracker.checkNow();
    await Future<void>.delayed(Duration.zero);
    expect(updates.last.delayAlert?.lateMinutes, 30);
    expect(updates.last.route, hasLength(1));
    await subscription.cancel();
    await tracker.dispose();
    await location.close();
  });

  testWidgets('結果頁關閉後守護仍在原地依時間產生提醒', (tester) async {
    var now = DateTime(2026, 9, 22, 10);
    final location = _FakeLocationGateway(
      const LocationPoint(latitude: 25.04, longitude: 121.52),
    );
    final notifications = _FakeNotifications();
    final dependencies = ItineraryResultDependencies(
      locationGateway: location,
      now: () => now,
      realtimeGateway: _FakeRealtimeGateway(),
      routingGateway: const _EmptyRoutingGateway(),
      weatherGateway: _FakeWeatherGateway(),
      notificationGateway: notifications,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ItineraryResultPage(
          itinerary: _delayedItinerary(now),
          dependencies: dependencies,
        ),
      ),
    );
    await tester.tap(find.byTooltip('開始行程'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(ActiveGuardianSession.active, isNotNull);
    expect(ActiveGuardianSession.active!.hasAttachedPage, isFalse);
    now = DateTime(2026, 9, 22, 10, 30);
    ActiveGuardianSession.active!.tracker.checkNow();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(notifications.alternativeCalls, 1);
    expect(ActiveGuardianSession.active!.takePendingRiskUpdate(), isNotNull);
    await tester.runAsync(() async => ActiveGuardianSession.active?.stop());
    await location.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('背景天氣提醒返回正在守護的行程後顯示備案提示', (tester) async {
    final now = DateTime(2026, 9, 22, 10);
    final itinerary = _delayedItinerary(now);
    final location = _FakeLocationGateway(
      const LocationPoint(latitude: 25.04, longitude: 121.52),
    );
    final weather = _FakeWeatherGateway();
    final dependencies = ItineraryResultDependencies(
      locationGateway: location,
      now: () => now,
      realtimeGateway: _FakeRealtimeGateway(),
      routingGateway: const _EmptyRoutingGateway(),
      weatherGateway: weather,
      notificationGateway: _FakeNotifications(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ItineraryResultPage(
          itinerary: itinerary,
          dependencies: dependencies,
        ),
      ),
    );
    await tester.tap(find.byTooltip('開始行程'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    weather.nextResult = const WeatherCheckResult(
      forecast: CwaForecast(precipitationProbability: 60),
      advisories: [
        WeatherAdvisory(
          kind: 'rain',
          title: '稍後可能下雨',
          body: '請準備雨具。',
          level: WeatherRiskLevel.warning,
        ),
      ],
    );
    final session = ActiveGuardianSession.active!;
    session.tracker.checkNow();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(weather.lastGuardianSessionId, session.id);

    await tester.pumpWidget(
      MaterialApp(
        home: ItineraryResultPage(
          itinerary: session.itinerary,
          dependencies: session.dependencies,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('天氣提醒'), findsOneWidget);
    expect(find.textContaining('請準備雨具。'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pump();
    expect(find.text('保母測試'), findsOneWidget);

    await tester.runAsync(() async => ActiveGuardianSession.active?.stop());
    await location.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('注入 GPS 與固定時間後顯示延誤備案且不自動套用', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026, 9, 22, 10, 30);
    final location = _FakeLocationGateway(
      const LocationPoint(latitude: 25.04, longitude: 121.52),
    );
    final weather = _FakeWeatherGateway();
    final notifications = _FakeNotifications();
    final dependencies = _dependencies(
      location: location,
      now: now,
      weather: weather,
      notifications: notifications,
      realtime: _FakeRealtimeGateway(),
      routing: _FakeRoutingGateway(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ItineraryResultPage(
          itinerary: _delayedItinerary(now),
          dependencies: dependencies,
        ),
      ),
    );

    await tester.tap(find.byTooltip('開始行程'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('確認今天的行程進度'), findsOneWidget);
    await tester.tap(find.text('已完成至 第一站'));
    await tester.pump();
    await tester.tap(find.text('確認進度').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('行程備案'), findsOneWidget);
    expect(find.text('原行程 Before'), findsOneWidget);
    expect(find.text('建議行程 After'), findsOneWidget);
    expect(find.textContaining('11:00–12:00 第二站'), findsOneWidget);
    expect(find.text('保留原行程'), findsOneWidget);
    expect(notifications.alternativeCalls, 1);
    expect(weather.checkedAt, [now]);
    expect(weather.positions.single.latitude, 25.04);

    final comparisonDialog = find.ancestor(
      of: find.text('原行程 Before'),
      matching: find.byType(AlertDialog),
    );
    await tester.tap(
      find.descendant(of: comparisonDialog, matching: find.text('保留原行程')),
    );
    await tester.pumpAndSettle();
    expect(find.text('原行程 Before'), findsNothing);
    expect(find.text('建議行程 After'), findsNothing);
    expect(tester.takeException(), isNull);

    // The session deliberately outlives the page; explicitly end it in tests.
    await tester.runAsync(() async => ActiveGuardianSession.active?.stop());
    await location.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('注入取消班次時使用假 TDX 並保留原行程', (tester) async {
    final now = DateTime(2026, 9, 22, 9, 50);
    final location = _FakeLocationGateway(
      const LocationPoint(latitude: 25.04, longitude: 121.52),
    );
    final notifications = _FakeNotifications();
    final realtime = _FakeRealtimeGateway(
      observation: TransitRealtimeObservation(
        updatedAt: now,
        cancelled: true,
        message: '307 公車今日停駛。',
        source: '測試 TDX',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ItineraryResultPage(
          itinerary: _transitOnlyItinerary(now),
          dependencies: _dependencies(
            location: location,
            now: now,
            weather: _FakeWeatherGateway(),
            notifications: notifications,
            realtime: realtime,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('開始行程'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(realtime.calls, 1);
    expect(notifications.transitRiskCalls, 1);
    expect(find.textContaining('查不到可用的即時交通備案'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    location.emit(location.initial);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('暫時無法產生備案'), findsNothing);
    expect(notifications.transitRiskCalls, 1);
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async => ActiveGuardianSession.active?.stop());
    await location.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('交通備案先預覽完整 Before／After，確認後才套用', (tester) async {
    final now = DateTime(2026, 9, 22, 9, 50);
    final location = _FakeLocationGateway(
      const LocationPoint(latitude: 25.04, longitude: 121.52),
    );
    final realtime = _FakeRealtimeGateway(
      observation: TransitRealtimeObservation(
        updatedAt: now,
        cancelled: true,
        message: '307 公車今日停駛。',
        source: '測試 TDX',
      ),
    );
    final routing = _FakeRoutingGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: ItineraryResultPage(
          itinerary: _transitOnlyItinerary(now),
          dependencies: _dependencies(
            location: location,
            now: now,
            weather: _FakeWeatherGateway(),
            notifications: _FakeNotifications(),
            realtime: realtime,
            routing: routing,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('開始行程'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('預覽所選備案'), findsOneWidget);
    expect(find.text('原行程 Before'), findsNothing);

    await tester.tap(find.text('預覽所選備案'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('確認今天的行程進度'), findsOneWidget);
    await tester.tap(find.text('確認進度').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('原行程 Before'), findsOneWidget);
    expect(find.text('建議行程 After'), findsOneWidget);
    final afterPanel = find.ancestor(
      of: find.text('建議行程 After'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: afterPanel, matching: find.textContaining('前往終點')),
      findsOneWidget,
    );
    expect(find.textContaining('Debug 備案'), findsNothing);
    await tester.tap(
      find
          .descendant(of: afterPanel, matching: find.byType(ExpansionTile))
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('路線：Debug 備案'), findsOneWidget);
    expect(routing.calls, 1);

    final previewDialog = find.ancestor(
      of: find.text('原行程 Before'),
      matching: find.byType(AlertDialog),
    );
    await tester.tap(
      find.descendant(of: previewDialog, matching: find.text('保留原行程')),
    );
    await tester.pumpAndSettle();
    expect(find.text('原行程 Before'), findsNothing);
    expect(find.text('建議行程 After'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async => ActiveGuardianSession.active?.stop());
    await location.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('追蹤中可主動重查剩餘行程且仍需確認才套用', (tester) async {
    final now = DateTime(2026, 9, 22, 9, 50);
    final location = _FakeLocationGateway(
      const LocationPoint(latitude: 25.0478, longitude: 121.517),
    );
    final routing = _FakeRoutingGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: ItineraryResultPage(
          itinerary: _transitOnlyItinerary(now),
          dependencies: _dependencies(
            location: location,
            now: now,
            weather: _FakeWeatherGateway(),
            notifications: _FakeNotifications(),
            realtime: _FakeRealtimeGateway(),
            routing: routing,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('開始行程'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byTooltip('GPS 追蹤中'), findsOneWidget);
    expect(find.text('GPS 追蹤中'), findsNothing);
    await tester.tap(find.byTooltip('GPS 追蹤中'));
    await tester.pumpAndSettle();
    expect(find.text('行程追蹤'), findsOneWidget);
    await tester.tap(find.text('關閉'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多行程操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重排剩餘行程'));
    await tester.pump();
    expect(find.text('確認今天的行程進度'), findsOneWidget);
    await tester.tap(find.text('確認進度').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('原行程 Before'), findsOneWidget);
    expect(find.text('建議行程 After'), findsOneWidget);
    expect(routing.calls, 1);
    final dialog = find.ancestor(
      of: find.text('原行程 Before'),
      matching: find.byType(AlertDialog),
    );
    await tester.tap(find.descendant(of: dialog, matching: find.text('保留原行程')));
    await tester.pumpAndSettle();
    expect(find.text('原行程 Before'), findsNothing);
    await tester.runAsync(() async => ActiveGuardianSession.active?.stop());
    await location.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Debug 控制台可啟用模擬模式並顯示醒目標示', (tester) async {
    final now = DateTime(2026, 9, 22, 9, 50);
    final location = _FakeLocationGateway(
      const LocationPoint(latitude: 25.04, longitude: 121.52),
    );
    final weather = _FakeWeatherGateway();
    final notifications = _FakeNotifications();
    final realtime = _FakeRealtimeGateway();
    final realGoogle = _FakeGoogleGateway();
    final routing = _FakeRoutingGateway();
    final debug = GuardianDebugController(
      realLocation: location,
      realRealtime: realtime,
      realRouting: routing,
      realGoogle: realGoogle,
      realWeather: weather,
      realNotifications: notifications,
      realNow: () => now,
      initialTime: now,
    );
    final dependencies = ItineraryResultDependencies(
      locationGateway: debug,
      now: debug.now,
      realtimeGateway: debug,
      routingGateway: debug,
      googleRoutingGateway: debug,
      weatherGateway: debug,
      notificationGateway: debug,
      debugController: debug,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ItineraryResultPage(
          itinerary: _delayedItinerary(now),
          dependencies: dependencies,
        ),
      ),
    );

    await tester.tap(find.byTooltip('保母測試控制台'));
    await tester.pumpAndSettle();
    expect(find.text('保母測試控制台'), findsOneWidget);
    expect(find.textContaining('僅 Debug 版本可用'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('交通備案會查真實 TDX'), findsOneWidget);
    expect(find.text('模擬時間：2026/09/22 09:50'), findsOneWidget);
    expect(find.text('Day 1・2026/09/22'), findsWidgets);
    expect(find.text('原定停留時段：第一站'), findsOneWidget);
    await tester.ensureVisible(find.text('+15 分鐘'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+15 分鐘'));
    await tester.pumpAndSettle();
    expect(debug.simulatedNow, DateTime(2026, 9, 22, 10, 5));
    await tester.scrollUntilVisible(
      find.text('模擬時間：2026/09/22 10:05'),
      -200,
      scrollable: find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(find.text('模擬時間：2026/09/22 10:05'), findsOneWidget);
    expect(find.text('目前是兩項之間的空白／等待時段'), findsOneWidget);
    expect(
      find.textContaining('下一項：Day 1 2026/09/22 10:30 第一站 → 第二站'),
      findsOneWidget,
    );
    debug.setTime(DateTime(2026, 9, 23, 9));
    await tester.pumpAndSettle();
    expect(find.text('未對應到行程日期'), findsOneWidget);
    final realTdxOptions = await debug.getRoutingOptions(
      origin: '25.04,121.52',
      destination: '25.05,121.53',
      departureTime: now,
    );
    expect(routing.calls, 1);
    expect(realTdxOptions.single.sections.single.lineName, 'Debug 備案');
    debug.setTransitScenario(GuardianTransitScenario.failed);
    await debug.getRoutingOptions(
      origin: '25.04,121.52',
      destination: '25.05,121.53',
      departureTime: now,
    );
    expect(routing.calls, 2);
    expect(debug.events.first, contains('TDX 回傳 1 條真實備案路線'));
    final queriedWalking = await debug.getRoute(
      originLatitude: 25.04,
      originLongitude: 121.52,
      destinationLatitude: 25.05,
      destinationLongitude: 121.53,
      requestedDeparture: now,
      travelMode: RouteTravelMode.walking,
    );
    expect(queriedWalking, isNull);
    expect(realGoogle.calls, 1);
    await debug.getRoute(
      originLatitude: 25.04,
      originLongitude: 121.52,
      destinationLatitude: 25.05,
      destinationLongitude: 121.53,
      requestedDeparture: now,
      travelMode: RouteTravelMode.transit,
    );
    expect(realGoogle.modes, [RouteTravelMode.walking, RouteTravelMode.transit]);
    await debug.showAlternativeAvailable(lateMinutes: 15, nextStopName: '測試站');
    expect(notifications.testTitles, ['行程可能延誤']);
    expect(notifications.testBodies.single, contains('測試站'));

    await tester.scrollUntilVisible(
      find.byTooltip('關閉'),
      -200,
      scrollable: find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.tap(find.byTooltip('關閉'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('保母測試控制台'), findsOneWidget);
    expect(find.byIcon(Icons.science), findsOneWidget);
    expect(tester.takeException(), isNull);

    final noRouteDebug = GuardianDebugController(
      realLocation: location,
      realRealtime: realtime,
      realRouting: const _EmptyRoutingGateway(),
      realGoogle: realGoogle,
      realWeather: weather,
      realNotifications: notifications,
      realNow: () => now,
    )..setEnabled(true);
    expect(
      await noRouteDebug.getRoutingOptions(
        origin: '25.04,121.52',
        destination: '25.05,121.53',
        departureTime: now,
      ),
      isEmpty,
    );

    await location.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

ItineraryResultDependencies _dependencies({
  required _FakeLocationGateway location,
  required DateTime now,
  required _FakeWeatherGateway weather,
  required _FakeNotifications notifications,
  required _FakeRealtimeGateway realtime,
  TdxRoutingGateway routing = const _EmptyRoutingGateway(),
  GoogleRoutePlanningGateway? google,
}) => ItineraryResultDependencies(
  locationGateway: location,
  now: () => now,
  realtimeGateway: realtime,
  routingGateway: routing,
  googleRoutingGateway: google ?? _FakeGoogleGateway(),
  weatherGateway: weather,
  notificationGateway: notifications,
);

RouteItinerary _delayedItinerary(DateTime now) {
  final first = _place('first', '第一站', 25.04, 121.52);
  final second = _place('second', '第二站', 25.05, 121.53);
  const origin = RouteStop(
    id: 'origin',
    name: '起點',
    latitude: 25.03,
    longitude: 121.51,
  );
  final firstStop = RouteStop.fromPlace(first);
  final secondStop = RouteStop.fromPlace(second);
  return _itinerary(
    now,
    origin,
    visits: [_visit(first, 1, 540, 600), _visit(second, 2, 660, 720)],
    legs: [
      _leg(origin, firstStop, 520, 540),
      _leg(firstStop, secondStop, 630, 660),
    ],
  );
}

RouteItinerary _transitOnlyItinerary(DateTime now) {
  const origin = RouteStop(
    id: 'origin',
    name: '起點',
    latitude: 25.03,
    longitude: 121.51,
  );
  final place = _place('destination', '終點', 25.05, 121.53);
  final destination = RouteStop.fromPlace(place);
  final route = TdxRoute(
    transfers: 0,
    travelTime: 1200,
    sections: [
      RouteSection(
        mode: 'bus',
        lineName: '307',
        serviceId: 'bus-307',
        routeId: '307',
        city: 'Taipei',
        departureTitle: '臺北車站',
        arrivalTitle: '西門站',
        departureLatitude: 25.0478,
        departureLongitude: 121.517,
        scheduledDeparture: DateTime(2026, 9, 22, 10),
        scheduledArrival: DateTime(2026, 9, 22, 10, 20),
        travelTime: 1200,
        stopCount: 0,
        intermediateStops: const [],
      ),
    ],
  );
  return _itinerary(
    now,
    origin,
    visits: [_visit(place, 1, 620, 680)],
    legs: [_leg(origin, destination, 600, 620, route: route)],
  );
}

RouteItinerary _itinerary(
  DateTime now,
  RouteStop origin, {
  required List<RouteVisit> visits,
  required List<TravelLeg> legs,
}) => RouteItinerary(
  request: TripRequest(
    title: '保母測試',
    startDate: DateTime(now.year, now.month, now.day),
    endDate: DateTime(now.year, now.month, now.day),
    location: '台北市',
    people: 1,
    budget_level: 1000,
    preferences: const [],
    aiPrompt: '',
  ),
  origin: origin,
  generatedAt: now,
  days: [
    RouteDay(
      day: 1,
      date: DateTime(now.year, now.month, now.day),
      origin: origin,
      visits: visits,
      travelLegs: legs,
      isValid: true,
    ),
  ],
);

Place _place(String id, String name, double latitude, double longitude) =>
    Place(
      id: id,
      name: name,
      category: '景點',
      description: '',
      address: '',
      latitude: latitude,
      longitude: longitude,
      image: '',
      stayTime: 60,
      rating: 0,
      tags: const [],
      price_level: 0,
      openMinutes: 0,
      closeMinutes: 1440,
    );

RouteVisit _visit(Place place, int sequence, int start, int end) => RouteVisit(
  place: place,
  sequence: sequence,
  arrivalMinutes: start,
  startMinutes: start,
  endMinutes: end,
  waitingMinutes: 0,
  stayMinutes: end - start,
  requestedStartMinutes: null,
  locked: false,
);

TravelLeg _leg(
  RouteStop origin,
  RouteStop destination,
  int departure,
  int arrival, {
  TdxRoute? route,
}) => TravelLeg(
  origin: origin,
  destination: destination,
  requestedDeparture: DateTime(2026, 9, 22).add(Duration(minutes: departure)),
  schedule: ScheduledVisit(
    departureMinutes: departure,
    arrivalMinutes: arrival,
    visitStartMinutes: arrival,
    visitEndMinutes: arrival + 60,
    waitingMinutes: 0,
    stayMinutes: 60,
  ),
  route: route,
);

class _FakeLocationGateway implements LocationTrackingGateway {
  final LocationPoint initial;
  final StreamController<LocationPoint> _controller =
      StreamController<LocationPoint>.broadcast();

  _FakeLocationGateway(this.initial);

  @override
  Future<LocationPoint?> getCurrentLocation() async => initial;

  @override
  Stream<LocationPoint> watchLocation() => _controller.stream;

  void emit(LocationPoint location) => _controller.add(location);

  Future<void> close() => _controller.close();
}

class _FakeRealtimeGateway implements TransitRealtimeGateway {
  final TransitRealtimeObservation? observation;
  int calls = 0;

  _FakeRealtimeGateway({this.observation});
  @override
  Future<TransitRealtimeObservation?> load(
    TransitSectionIdentity identity,
  ) async {
    calls++;
    return observation;
  }
}

class _EmptyRoutingGateway implements TdxRoutingGateway {
  const _EmptyRoutingGateway();

  @override
  Future<List<TdxRoute>> getRoutingOptions({
    required String origin,
    required String destination,
    DateTime? departureTime,
  }) async => const [];
}

class _FakeGoogleGateway implements GoogleRoutePlanningGateway {
  int calls = 0;
  final List<RouteTravelMode> modes = [];

  @override
  Future<TdxRoute?> getRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required DateTime requestedDeparture,
    required RouteTravelMode travelMode,
  }) async {
    calls++;
    modes.add(travelMode);
    return null;
  }
}

class _FakeRoutingGateway implements TdxRoutingGateway {
  int calls = 0;

  @override
  Future<List<TdxRoute>> getRoutingOptions({
    required String origin,
    required String destination,
    DateTime? departureTime,
  }) async {
    calls++;
    return [
      TdxRoute(
        transfers: 0,
        travelTime: 20 * 60,
        sections: [
          RouteSection(
            mode: 'bus',
            lineName: 'Debug 備案',
            travelTime: 20 * 60,
            stopCount: 0,
            intermediateStops: const [],
          ),
        ],
      ),
    ];
  }
}

class _FakeWeatherGateway implements WeatherAdvisoryGateway {
  final List<LocationPoint> positions = [];
  final List<DateTime> checkedAt = [];
  WeatherCheckResult? nextResult;
  String? lastGuardianSessionId;

  @override
  bool get isConfigured => true;

  @override
  Future<WeatherCheckResult?> check(
    LocationPoint position, {
    DateTime? now,
    String? guardianSessionId,
  }) async {
    positions.add(position);
    if (now != null) checkedAt.add(now);
    lastGuardianSessionId = guardianSessionId;
    final result = nextResult;
    nextResult = null;
    return result;
  }

  @override
  void dispose() {}
}

class _FakeNotifications implements TripNotificationGateway {
  int alternativeCalls = 0;
  int transitRiskCalls = 0;
  final List<String> testTitles = [];
  final List<String> testBodies = [];

  @override
  Future<bool?> androidNotificationsEnabled() async => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> showAlternativeAvailable({
    required int lateMinutes,
    required String nextStopName,
  }) async {
    alternativeCalls++;
  }

  @override
  Future<void> showScheduleAdjusted({
    required int lateMinutes,
    required String nextStopName,
  }) async {}

  @override
  Future<void> showTransitRisk({
    required String reason,
    required String nextStopName,
  }) async {
    transitRiskCalls++;
  }

  @override
  Future<void> showWeatherAdvisory({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Future<void> showTestNotification({
    required String title,
    required String body,
  }) async {
    testTitles.add(title);
    testBodies.add(body);
  }
}
