import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:taipei_travel_app/algorithm/route_optimizer.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_day.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_travel_mode.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_visit.dart';
import 'package:taipei_travel_app/features/route_planning/models/travel_leg.dart';
import 'package:taipei_travel_app/features/route_planning/widgets/trip_map_panel.dart';
import 'package:taipei_travel_app/models/route_geometry_segment.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/models/scheduled_visit.dart';
import 'package:taipei_travel_app/services/route_geometry_gateway.dart';
import 'package:taipei_travel_app/services/location_service.dart';

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
  testWidgets('GPS、景點、餐廳與住宿使用不同標記，首站起點不遮住分類', (tester) async {
    final previous = GoogleMapsFlutterPlatform.instance;
    final platform = _MapPlatform();
    GoogleMapsFlutterPlatform.instance = platform;
    addTearDown(() => GoogleMapsFlutterPlatform.instance = previous);
    final visits = [
      _visit('meal', PlaceType.restaurant, 25.0),
      _visit('spot', PlaceType.attraction, 25.01),
      _visit('hotel', PlaceType.accommodation, 25.02),
    ];
    final day = RouteDay(
      day: 1,
      date: DateTime(2026),
      origin: const RouteStop(
        id: 'meal',
        name: '餐廳',
        latitude: 25.0,
        longitude: 121.0,
      ),
      visits: visits,
      travelLegs: const [],
      isValid: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripMapPanel(
            day: day,
            currentLocation: const LocationPoint(
              latitude: 25.005,
              longitude: 121.0,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final markers = {
      for (final marker in platform.objects.markers)
        marker.markerId.value: marker,
    };
    expect(
      markers.keys,
      containsAll([
        'day-1-meal',
        'day-1-spot',
        'day-1-hotel',
        'current-location',
      ]),
    );
    expect(markers, isNot(contains('day-1-origin')));
    expect(markers['day-1-meal']!.infoWindow.snippet, contains('當日起點'));
    expect(markers['day-1-meal']!.infoWindow.title, contains('餐廳'));
    expect(markers['day-1-spot']!.infoWindow.title, contains('景點'));
    expect(markers['day-1-hotel']!.infoWindow.title, contains('住宿'));
    expect(
      (markers['current-location']!.icon.toJson() as List)[1],
      BitmapDescriptor.hueAzure,
    );
    expect(
      (markers['day-1-spot']!.icon.toJson() as List)[1],
      BitmapDescriptor.hueRose,
    );
    expect(
      (markers['day-1-meal']!.icon.toJson() as List)[1],
      BitmapDescriptor.hueOrange,
    );
    expect(
      (markers['day-1-hotel']!.icon.toJson() as List)[1],
      BitmapDescriptor.hueGreen,
    );
    expect(
      platform.objects.circles.single.circleId.value,
      'current-location-halo',
    );

    await tester.tap(find.text('圖例與說明'));
    await tester.pumpAndSettle();
    expect(find.text('目前 GPS'), findsOneWidget);
    expect(find.text('景點'), findsOneWidget);
    expect(find.text('餐廳'), findsOneWidget);
    expect(find.text('住宿'), findsOneWidget);
  });

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

RouteVisit _visit(String id, PlaceType type, double latitude) => RouteVisit(
  place: Place(
    id: id,
    name: id,
    category: '測試',
    description: '',
    address: '測試地址',
    latitude: latitude,
    longitude: 121.0,
    image: '',
    type: type,
    stayTime: 30,
    rating: 0,
    tags: const [],
    price_level: 0,
    openMinutes: 0,
    closeMinutes: 1440,
  ),
  sequence: type.index + 1,
  arrivalMinutes: 0,
  startMinutes: 0,
  endMinutes: 30,
  waitingMinutes: 0,
  stayMinutes: 30,
  requestedStartMinutes: null,
  locked: false,
);
