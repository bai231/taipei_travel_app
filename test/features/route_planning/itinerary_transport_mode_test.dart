import 'package:flutter/material.dart';
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
  });
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
    estimatedCost: 0,
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
      budget: 1000,
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
