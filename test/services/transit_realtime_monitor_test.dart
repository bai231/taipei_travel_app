import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/algorithm/route_optimizer.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_day.dart';
import 'package:taipei_travel_app/features/route_planning/models/travel_leg.dart';
import 'package:taipei_travel_app/models/scheduled_visit.dart';
import 'package:taipei_travel_app/models/tdx_route.dart';
import 'package:taipei_travel_app/services/location_service.dart';
import 'package:taipei_travel_app/services/transit_realtime_monitor.dart';

void main() {
  final date = DateTime(2026, 9, 22);

  test('依目前位置判斷來不及搭上第一段公車', () async {
    final bus = _section(
      mode: 'bus',
      serviceId: 'bus-1',
      departure: DateTime(2026, 9, 22, 10),
      arrival: DateTime(2026, 9, 22, 10, 20),
      departureLatitude: 25,
      departureLongitude: 121,
    );
    final monitor = TransitRealtimeMonitor(gateway: _FakeGateway({}));

    final risk = await monitor.check(
      day: _day(date, [bus]),
      location: const LocationPoint(latitude: 25.02, longitude: 121),
      now: DateTime(2026, 9, 22, 9, 55),
    );

    expect(risk?.kind, TransitRiskKind.boarding);
    expect(risk?.affectedSection.section.serviceId, 'bus-1');
    expect(risk!.shortageMinutes, greaterThan(0));
  });

  test('多段轉乘只回報趕不上的中間臺鐵段', () async {
    final incomingBus = _section(
      mode: 'bus',
      serviceId: 'bus-1',
      departure: DateTime(2026, 9, 22, 9, 40),
      arrival: DateTime(2026, 9, 22, 10, 5),
      departureLatitude: 25,
      departureLongitude: 121,
      arrivalLatitude: 25.05,
      arrivalLongitude: 121.5,
    );
    final walk = RouteSection(
      mode: 'pedestrian',
      travelTime: 4 * 60,
      stopCount: 0,
      intermediateStops: const [],
    );
    final train = _section(
      mode: 'train',
      operatorCode: 'TRA',
      serviceId: 'train-123',
      departure: DateTime(2026, 9, 22, 10, 10),
      arrival: DateTime(2026, 9, 22, 11),
      departureLatitude: 25.05,
      departureLongitude: 121.5,
    );
    final gateway = _FakeGateway({
      'bus-1': TransitRealtimeObservation(
        expectedDeparture: DateTime(2026, 9, 22, 9, 40),
        expectedArrival: DateTime(2026, 9, 22, 10, 7),
        updatedAt: DateTime(2026, 9, 22, 9, 50),
        source: 'TDX Bus',
      ),
      'train-123': TransitRealtimeObservation(
        expectedDeparture: DateTime(2026, 9, 22, 10, 10),
        expectedArrival: DateTime(2026, 9, 22, 11),
        updatedAt: DateTime(2026, 9, 22, 9, 50),
        source: 'TDX TRA',
      ),
    });

    final risk = await TransitRealtimeMonitor(gateway: gateway).check(
      day: _day(date, [incomingBus, walk, train]),
      location: const LocationPoint(latitude: 25.03, longitude: 121.3),
      now: DateTime(2026, 9, 22, 9, 50),
    );

    expect(risk?.kind, TransitRiskKind.transfer);
    expect(risk?.incomingSection?.section.serviceId, 'bus-1');
    expect(risk?.affectedSection.section.serviceId, 'train-123');
    expect(risk?.shortageMinutes, 11);
  });

  test('班次取消時直接回報取消，不修改行程', () async {
    final train = _section(
      mode: 'train',
      operatorCode: 'TRA',
      serviceId: 'train-123',
      departure: DateTime(2026, 9, 22, 10, 30),
      arrival: DateTime(2026, 9, 22, 11, 20),
      departureLatitude: 25,
      departureLongitude: 121,
    );
    final gateway = _FakeGateway({
      'train-123': TransitRealtimeObservation(
        updatedAt: DateTime(2026, 9, 22, 10),
        cancelled: true,
        message: '123 次列車已取消。',
        source: 'TDX TRA',
      ),
    });

    final risk = await TransitRealtimeMonitor(gateway: gateway).check(
      day: _day(date, [train]),
      location: const LocationPoint(latitude: 25, longitude: 121),
      now: DateTime(2026, 9, 22, 10),
    );

    expect(risk?.kind, TransitRiskKind.cancelled);
    expect(risk?.reason, contains('取消'));
  });
}

class _FakeGateway implements TransitRealtimeGateway {
  final Map<String, TransitRealtimeObservation> values;
  const _FakeGateway(this.values);

  @override
  Future<TransitRealtimeObservation?> load(
    TransitSectionIdentity identity,
  ) async => values[identity.section.serviceId];
}

RouteSection _section({
  required String mode,
  String? operatorCode,
  required String serviceId,
  required DateTime departure,
  required DateTime arrival,
  required double departureLatitude,
  required double departureLongitude,
  double? arrivalLatitude,
  double? arrivalLongitude,
}) => RouteSection(
  mode: mode,
  operatorCode: operatorCode,
  serviceId: serviceId,
  departureTitle: '上車站',
  arrivalTitle: '下車站',
  departureTime:
      '${departure.hour.toString().padLeft(2, '0')}:'
      '${departure.minute.toString().padLeft(2, '0')}',
  arrivalTime:
      '${arrival.hour.toString().padLeft(2, '0')}:'
      '${arrival.minute.toString().padLeft(2, '0')}',
  scheduledDeparture: departure,
  scheduledArrival: arrival,
  departureLatitude: departureLatitude,
  departureLongitude: departureLongitude,
  arrivalLatitude: arrivalLatitude,
  arrivalLongitude: arrivalLongitude,
  travelTime: arrival.difference(departure).inSeconds,
  stopCount: 0,
  intermediateStops: const [],
);

RouteDay _day(DateTime date, List<RouteSection> sections) {
  const origin = RouteStop(
    id: 'origin',
    name: 'A',
    latitude: 25,
    longitude: 121,
  );
  const destination = RouteStop(
    id: 'destination',
    name: 'B',
    latitude: 24.8,
    longitude: 121,
  );
  return RouteDay(
    day: 1,
    date: date,
    origin: origin,
    visits: const [],
    travelLegs: [
      TravelLeg(
        origin: origin,
        destination: destination,
        requestedDeparture: DateTime(2026, 9, 22, 9, 30),
        schedule: const ScheduledVisit(
          departureMinutes: 570,
          arrivalMinutes: 680,
          visitStartMinutes: 680,
          visitEndMinutes: 740,
          waitingMinutes: 0,
          stayMinutes: 60,
        ),
        route: TdxRoute(transfers: 1, travelTime: 6600, sections: sections),
      ),
    ],
    isValid: true,
  );
}
