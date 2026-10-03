import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/algorithm/route_optimizer.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_day.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_travel_mode.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_visit.dart';
import 'package:taipei_travel_app/features/route_planning/models/travel_leg.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/models/scheduled_visit.dart';
import 'package:taipei_travel_app/models/tdx_route.dart';
import 'package:taipei_travel_app/services/location_service.dart';
import 'package:taipei_travel_app/services/google_route_planning_gateway.dart';
import 'package:taipei_travel_app/services/tdx_service.dart';
import 'package:taipei_travel_app/services/transit_alternative_service.dart';
import 'package:taipei_travel_app/services/transit_realtime_monitor.dart';

void main() {
  test('TDX 無候選時改查 Google 大眾運輸並標記來源', () async {
    final google = _GoogleFallback();
    final service = TransitAlternativeService(
      routingGateway: _Gateway(),
      googleGateway: google,
    );
    final day = _day();
    final risk = TransitConnectionRisk(
      kind: TransitRiskKind.boarding,
      affectedSection: TransitSectionIdentity(
        provider: TransitProvider.bus,
        legIndex: 0,
        sectionIndex: 0,
        serviceDate: day.date,
        section: RouteSection(
          mode: 'bus',
          travelTime: 600,
          stopCount: 0,
          intermediateStops: const [],
        ),
      ),
      shortageMinutes: 3,
      reason: '來不及上車',
    );
    final now = DateTime(2026, 9, 23, 10);
    final options = await service.options(
      day: day,
      risk: risk,
      currentLocation: const LocationPoint(latitude: 25, longitude: 121),
      now: now,
    );
    expect(google.departure, now);
    expect(google.mode, RouteTravelMode.transit);
    expect(options.single.provider, RouteProvider.google);
  });

  test('轉乘風險從前段到站位置與可轉乘時間查詢', () async {
    final gateway = _Gateway();
    final service = TransitAlternativeService(routingGateway: gateway);
    final day = _day();
    final incoming = TransitSectionIdentity(
      provider: TransitProvider.bus,
      legIndex: 0,
      sectionIndex: 0,
      serviceDate: day.date,
      section: RouteSection(
        mode: 'bus',
        travelTime: 600,
        stopCount: 0,
        intermediateStops: const [],
        arrivalLatitude: 25.0478,
        arrivalLongitude: 121.517,
      ),
    );
    final affected = TransitSectionIdentity(
      provider: TransitProvider.tra,
      legIndex: 0,
      sectionIndex: 2,
      serviceDate: day.date,
      section: RouteSection(
        mode: 'train',
        travelTime: 1200,
        stopCount: 0,
        intermediateStops: const [],
      ),
    );
    final readyAt = DateTime(2026, 9, 23, 10, 15);
    final risk = TransitConnectionRisk(
      kind: TransitRiskKind.transfer,
      affectedSection: affected,
      incomingSection: incoming,
      expectedReadyAt: readyAt,
      shortageMinutes: 5,
      reason: '轉乘時間不足',
    );

    await service.options(
      day: day,
      risk: risk,
      currentLocation: const LocationPoint(latitude: 24, longitude: 120),
      now: DateTime(2026, 9, 23, 10),
    );

    expect(gateway.origin, '25.0478,121.517');
    expect(gateway.departure, readyAt);
  });

  test('一般上車風險從目前 GPS 與現在時間查詢', () async {
    final gateway = _Gateway();
    final service = TransitAlternativeService(routingGateway: gateway);
    final day = _day();
    final risk = TransitConnectionRisk(
      kind: TransitRiskKind.boarding,
      affectedSection: TransitSectionIdentity(
        provider: TransitProvider.bus,
        legIndex: 0,
        sectionIndex: 0,
        serviceDate: day.date,
        section: RouteSection(
          mode: 'bus',
          travelTime: 600,
          stopCount: 0,
          intermediateStops: const [],
        ),
      ),
      shortageMinutes: 2,
      reason: '來不及上車',
    );
    final now = DateTime(2026, 9, 23, 10);
    await service.options(
      day: day,
      risk: risk,
      currentLocation: const LocationPoint(latitude: 25, longitude: 121),
      now: now,
    );
    expect(gateway.origin, '25.0,121.0');
    expect(gateway.departure, now);
  });

  test('未來路段須從前一項結束地點與結束時間查詢', () async {
    final gateway = _Gateway();
    final service = TransitAlternativeService(routingGateway: gateway);
    final original = _day();
    const hotel = RouteStop(
      id: 'hotel',
      name: '住宿',
      latitude: 25.2,
      longitude: 121.2,
    );
    final hotelVisit = RouteVisit(
      place: Place(
        id: 'hotel',
        name: '住宿',
        category: '住宿',
        description: '',
        address: '',
        latitude: 25.2,
        longitude: 121.2,
        image: '',
        stayTime: 30,
        rating: 0,
        tags: const [],
        price_level: 0,
        openMinutes: 0,
        closeMinutes: 1440,
      ),
      sequence: 2,
      arrivalMinutes: 1225,
      startMinutes: 1225,
      endMinutes: 1255,
      waitingMinutes: 0,
      stayMinutes: 30,
      requestedStartMinutes: null,
      locked: false,
    );
    final previous = original.visits.single;
    final laterDinner = RouteVisit(
      place: previous.place,
      sequence: 1,
      arrivalMinutes: 1115,
      startMinutes: 1115,
      endMinutes: 1205,
      waitingMinutes: 0,
      stayMinutes: 90,
      requestedStartMinutes: null,
      locked: false,
    );
    final day = RouteDay(
      day: 1,
      date: original.date,
      origin: original.origin,
      visits: [laterDinner, hotelVisit],
      travelLegs: [
        original.travelLegs.single,
        TravelLeg(
          origin: original.travelLegs.single.destination,
          destination: hotel,
          requestedDeparture: DateTime(2026, 9, 23, 20, 5),
          schedule: const ScheduledVisit(
            departureMinutes: 1205,
            arrivalMinutes: 1225,
            visitStartMinutes: 1225,
            visitEndMinutes: 1255,
            waitingMinutes: 0,
            stayMinutes: 30,
          ),
        ),
      ],
      isValid: true,
    );
    final risk = TransitConnectionRisk(
      kind: TransitRiskKind.boarding,
      affectedSection: TransitSectionIdentity(
        provider: TransitProvider.bus,
        legIndex: 1,
        sectionIndex: 0,
        serviceDate: day.date,
        section: RouteSection(
          mode: 'bus',
          travelTime: 1200,
          stopCount: 0,
          intermediateStops: const [],
        ),
      ),
      shortageMinutes: 5,
      reason: '來不及上車',
    );
    final start = service.startForRisk(
      day: day,
      risk: risk,
      currentLocation: const LocationPoint(latitude: 24, longitude: 120),
      now: DateTime(2026, 9, 23, 18, 15),
    );
    expect(start.origin.latitude, 25.1);
    expect(start.departure, DateTime(2026, 9, 23, 20, 5));
    await service.options(
      day: day,
      risk: risk,
      currentLocation: const LocationPoint(latitude: 24, longitude: 120),
      now: DateTime(2026, 9, 23, 18, 15),
    );
    expect(gateway.origin, '25.1,121.1');
    expect(gateway.departure, DateTime(2026, 9, 23, 20, 5));
  });
}

class _GoogleFallback implements GoogleRoutePlanningGateway {
  DateTime? departure;
  RouteTravelMode? mode;

  @override
  Future<TdxRoute?> getRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required DateTime requestedDeparture,
    required RouteTravelMode travelMode,
  }) async {
    departure = requestedDeparture;
    mode = travelMode;
    return TdxRoute(
      transfers: 0,
      travelTime: 1200,
      provider: RouteProvider.google,
      sections: const [],
    );
  }
}

class _Gateway implements TdxRoutingGateway {
  String? origin;
  DateTime? departure;

  @override
  Future<List<TdxRoute>> getRoutingOptions({
    required String origin,
    required String destination,
    DateTime? departureTime,
  }) async {
    this.origin = origin;
    departure = departureTime;
    return [];
  }
}

RouteDay _day() {
  const origin = RouteStop(id: 'a', name: 'A', latitude: 25, longitude: 121);
  const destination = RouteStop(
    id: 'b',
    name: 'B',
    latitude: 25.1,
    longitude: 121.1,
  );
  final place = Place(
    id: 'b',
    name: 'B',
    category: '景點',
    description: '',
    address: '',
    latitude: destination.latitude,
    longitude: destination.longitude,
    image: '',
    stayTime: 60,
    rating: 0,
    tags: const [],
    price_level: 0,
    openMinutes: 0,
    closeMinutes: 1440,
  );
  final visit = RouteVisit(
    place: place,
    sequence: 1,
    arrivalMinutes: 660,
    startMinutes: 660,
    endMinutes: 720,
    waitingMinutes: 0,
    stayMinutes: 60,
    requestedStartMinutes: null,
    locked: false,
  );
  return RouteDay(
    day: 1,
    date: DateTime(2026, 9, 23),
    origin: origin,
    visits: [visit],
    travelLegs: [
      TravelLeg(
        origin: origin,
        destination: destination,
        requestedDeparture: DateTime(2026, 9, 23, 10),
        schedule: const ScheduledVisit(
          departureMinutes: 600,
          arrivalMinutes: 660,
          visitStartMinutes: 660,
          visitEndMinutes: 720,
          waitingMinutes: 0,
          stayMinutes: 60,
        ),
      ),
    ],
    isValid: true,
  );
}
