import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_travel_mode.dart';
import 'package:taipei_travel_app/services/google_route_planning_response.dart';

void main() {
  test('Google 汽車路線轉成可供排程使用的時間與距離', () {
    final departure = DateTime(2030, 1, 1, 9);
    final route = parseGoogleRouteInformation(
      response: const {'durationMillis': 725000, 'distanceMeters': 3200},
      requestedDeparture: departure,
      travelMode: RouteTravelMode.driving,
    );

    expect(route, isNotNull);
    expect(route!.travelTime, 725);
    expect(route.distanceMeters, 3200);
    expect(route.startTime, departure);
    expect(route.endTime, departure.add(const Duration(seconds: 725)));
    expect(route.sections.single.mode, 'drive');
  });

  test('Google 沒有回傳有效時間時視為沒有路線', () {
    expect(
      parseGoogleRouteInformation(
        response: const {'durationMillis': 0},
        requestedDeparture: DateTime(2030),
        travelMode: RouteTravelMode.walking,
      ),
      isNull,
    );
  });

  test('Google 大眾運輸備援保留車種、路線、站名與轉乘', () {
    final departure = DateTime(2030, 1, 1, 9);
    final route = parseGoogleRouteInformation(
      response: {
        'durationMillis': 3600000,
        'distanceMeters': 8500,
        'steps': [
          {'travelMode': 'WALKING', 'staticDurationMillis': 300000},
          {
            'travelMode': 'TRANSIT',
            'transitDetails': {
              'transitLine': {
                'nameShort': '307',
                'vehicle': {'type': 'BUS'},
              },
              'headsign': '臺北車站',
              'departureStop': {'name': '市政府'},
              'arrivalStop': {'name': '臺北車站'},
              'stopCount': 5,
              'departureTime': '2030-01-01T09:10:00+08:00',
              'arrivalTime': '2030-01-01T09:30:00+08:00',
            },
          },
          {
            'travelMode': 'TRANSIT',
            'transitDetails': {
              'transitLine': {
                'nameShort': '區間車',
                'vehicle': {'type': 'HEAVY_RAIL'},
              },
              'departureStop': {'name': '臺北'},
              'arrivalStop': {'name': '板橋'},
              'departureTime': '2030-01-01T09:40:00+08:00',
              'arrivalTime': '2030-01-01T09:55:00+08:00',
            },
          },
        ],
      },
      requestedDeparture: departure,
      travelMode: RouteTravelMode.transit,
    );

    expect(route, isNotNull);
    expect(route!.transfers, 1);
    expect(route.sections.map((section) => section.mode), [
      'pedestrian',
      'bus',
      'train',
    ]);
    expect(route.sections[1].lineName, '307');
    expect(route.sections[1].departureTitle, '市政府');
    expect(route.sections[1].arrivalTitle, '臺北車站');
    expect(route.sections[1].stopCount, 5);
    expect(route.sections[1].routeId, isNull);
  });

  test('Google 未提供乘車步驟時不能視為大眾運輸備援', () {
    expect(
      parseGoogleRouteInformation(
        response: const {
          'durationMillis': 600000,
          'steps': [
            {'travelMode': 'WALKING', 'staticDurationMillis': 600000},
          ],
        },
        requestedDeparture: DateTime(2030),
        travelMode: RouteTravelMode.transit,
      ),
      isNull,
    );
  });

  test('Google 班次晚於要求時間時不可把實際抵達排成更早', () {
    final departure = DateTime(2030, 1, 1, 9);
    final route = parseGoogleRouteInformation(
      response: {
        'durationMillis': 1200000,
        'steps': [
          {
            'travelMode': 'TRANSIT',
            'transitDetails': {
              'departureTime': '2030-01-01T09:30:00+08:00',
              'arrivalTime': '2030-01-01T09:50:00+08:00',
            },
          },
          {'travelMode': 'WALKING', 'staticDurationMillis': 300000},
        ],
      },
      requestedDeparture: departure,
      travelMode: RouteTravelMode.transit,
    );

    expect(route, isNotNull);
    expect(route!.endTime, DateTime(2030, 1, 1, 9, 55));
    expect(route.travelTime, const Duration(minutes: 55).inSeconds);
  });
}
