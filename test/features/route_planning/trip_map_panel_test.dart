import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:taipei_travel_app/algorithm/route_optimizer.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_day.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_travel_mode.dart';
import 'package:taipei_travel_app/features/route_planning/models/travel_leg.dart';
import 'package:taipei_travel_app/features/route_planning/widgets/trip_map_panel.dart';
import 'package:taipei_travel_app/models/route_geometry_segment.dart';
import 'package:taipei_travel_app/models/scheduled_visit.dart';
import 'package:taipei_travel_app/services/route_geometry_gateway.dart';

class _MapPlatform extends GoogleMapsFlutterPlatform {
  MapObjects objects = const MapObjects();
  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    objects = mapObjects;
    return const SizedBox.expand();
  }
}

class _Gateway implements RouteGeometryGateway {
  final calls = <double>[];
  bool fail = true;
  @override
  Future<List<RouteGeometrySegment>> getRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required DateTime departureTime,
    required RouteTravelMode travelMode,
  }) async {
    calls.add(originLatitude);
    if (originLatitude == 24 && fail) throw StateError('test failure');
    return [
      RouteGeometrySegment(
        travelMode: 'WALKING',
        points: [
          RouteGeometryPoint(
            latitude: originLatitude,
            longitude: originLongitude,
          ),
          RouteGeometryPoint(
            latitude: destinationLatitude,
            longitude: destinationLongitude,
          ),
        ],
      ),
    ];
  }
}

void main() {
  testWidgets('中段失敗保留前後路徑，重試只查失敗段', (tester) async {
    final previous = GoogleMapsFlutterPlatform.instance;
    final platform = _MapPlatform();
    GoogleMapsFlutterPlatform.instance = platform;
    addTearDown(() => GoogleMapsFlutterPlatform.instance = previous);
    final gateway = _Gateway();
    final stops = List.generate(
      4,
      (index) => RouteStop(
        id: '$index',
        name: '站$index',
        latitude: 25.0 - index,
        longitude: 121,
      ),
    );
    final day = RouteDay(
      day: 1,
      date: DateTime(2026),
      origin: stops.first,
      visits: [],
      isValid: true,
      travelLegs: List.generate(
        3,
        (index) => TravelLeg(
          origin: stops[index],
          destination: stops[index + 1],
          requestedDeparture: DateTime(2026),
          schedule: const ScheduledVisit(
            departureMinutes: 0,
            arrivalMinutes: 1,
            visitStartMinutes: 1,
            visitEndMinutes: 2,
            waitingMinutes: 0,
            stayMinutes: 1,
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripMapPanel(day: day, routeGeometryGateway: gateway),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(gateway.calls, [25, 24, 23]);
    expect(platform.objects.polylines.length, 3);
    expect(find.textContaining('2 段已載入，1 段無法取得路徑'), findsOneWidget);
    expect(find.textContaining('Google 參考路線'), findsNothing);
    await tester.tap(find.text('圖例與說明'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Google 參考路線'), findsOneWidget);
    gateway.fail = false;
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(gateway.calls, [25, 24, 23, 24]);
    expect(find.textContaining('3 段已載入，0 段無法取得路徑'), findsOneWidget);
    expect(
      platform.objects.polylines.any(
        (line) => line.polylineId.value.startsWith('unavailable'),
      ),
      isFalse,
    );
  });
}
