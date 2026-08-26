import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/algorithm/route_optimizer.dart';
import 'package:taipei_travel_app/features/route_planning/models/travel_leg.dart';
import 'package:taipei_travel_app/models/scheduled_visit.dart';
import 'package:taipei_travel_app/services/google_maps_navigation_service.dart';
import 'package:taipei_travel_app/services/location_service.dart';

void main() {
  test('有 GPS 時使用目前位置作為 Google Maps 起點', () async {
    Uri? launchedUri;
    final service = GoogleMapsNavigationService(
      locationGateway: const _FakeLocationGateway(
        LocationPoint(latitude: 25.04, longitude: 121.51),
      ),
      launcher: (uri) async {
        launchedUri = uri;
        return true;
      },
    );

    final result = await service.openTravelLeg(_leg());

    expect(result.usedCurrentLocation, isTrue);
    expect(launchedUri?.queryParameters['origin'], '25.04,121.51');
    expect(launchedUri?.queryParameters['destination'], '25.03,121.56');
    expect(launchedUri?.queryParameters['travelmode'], 'transit');
    expect(launchedUri?.queryParameters['dir_action'], 'navigate');
  });

  test('沒有 GPS 時使用前一站作為 Google Maps 起點', () async {
    Uri? launchedUri;
    final service = GoogleMapsNavigationService(
      locationGateway: const _FakeLocationGateway(null),
      launcher: (uri) async {
        launchedUri = uri;
        return true;
      },
    );

    final result = await service.openTravelLeg(_leg());

    expect(result.usedCurrentLocation, isFalse);
    expect(launchedUri?.queryParameters['origin'], '25.0478,121.517');
    expect(launchedUri?.queryParameters['destination'], '25.03,121.56');
  });
}

class _FakeLocationGateway implements CurrentLocationGateway {
  final LocationPoint? location;

  const _FakeLocationGateway(this.location);

  @override
  Future<LocationPoint?> getCurrentLocation() async => location;
}

TravelLeg _leg() {
  return TravelLeg(
    origin: const RouteStop(
      id: 'origin',
      name: '前一站',
      latitude: 25.0478,
      longitude: 121.517,
    ),
    destination: const RouteStop(
      id: 'destination',
      name: '下一站',
      latitude: 25.03,
      longitude: 121.56,
    ),
    requestedDeparture: DateTime(2026, 8, 21, 9),
    schedule: const ScheduledVisit(
      departureMinutes: 540,
      arrivalMinutes: 570,
      visitStartMinutes: 570,
      visitEndMinutes: 630,
      waitingMinutes: 0,
      stayMinutes: 60,
    ),
  );
}
