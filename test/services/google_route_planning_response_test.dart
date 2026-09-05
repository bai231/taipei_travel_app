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
}
