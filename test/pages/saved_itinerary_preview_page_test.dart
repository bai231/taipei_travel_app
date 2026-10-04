import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/algorithm/route_optimizer.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_day.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_itinerary.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_visit.dart';
import 'package:taipei_travel_app/features/route_planning/models/travel_leg.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_travel_mode.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/models/scheduled_visit.dart';
import 'package:taipei_travel_app/models/trip_request.dart';
import 'package:taipei_travel_app/pages/saved_itinerary_preview_page.dart';
import 'package:taipei_travel_app/services/itinerary_snapshot.dart';
import 'package:taipei_travel_app/services/itinerary_snapshot_reader.dart';

void main() {
  testWidgets(
    'saved preview displays snapshot without saving or recalculating',
    (tester) async {
      final date = DateTime(2026, 10, 4);
      final place = Place.fromJson({
        'id': 'place-1',
        'name': '測試景點',
        'latitude': 25.0,
        'longitude': 121.0,
      });
      final origin = RouteStop(
        id: 'origin',
        name: '出發點',
        latitude: 25.0,
        longitude: 121.0,
      );
      final destination = RouteStop(
        id: place.id,
        name: place.name,
        latitude: place.latitude,
        longitude: place.longitude,
      );
      final itinerary = RouteItinerary(
        request: TripRequest(
          title: '已儲存旅程',
          startDate: date,
          endDate: date,
          location: '臺北市',
          people: 1,
          budget_level: 2,
          preferences: const [],
          aiPrompt: '',
        ),
        origin: origin,
        generatedAt: date,
        days: [
          RouteDay(
            day: 1,
            date: date,
            origin: origin,
            isValid: true,
            visits: [
              RouteVisit(
                place: place,
                sequence: 1,
                arrivalMinutes: 540,
                startMinutes: 550,
                endMinutes: 610,
                waitingMinutes: 10,
                stayMinutes: 60,
                requestedStartMinutes: null,
                locked: false,
                information: const ['適合早上參觀'],
              ),
            ],
            travelLegs: [
              TravelLeg(
                origin: origin,
                destination: destination,
                requestedDeparture: date,
                travelMode: RouteTravelMode.walking,
                schedule: const ScheduledVisit(
                  departureMinutes: 520,
                  arrivalMinutes: 540,
                  visitStartMinutes: 550,
                  visitEndMinutes: 610,
                  waitingMinutes: 10,
                  stayMinutes: 60,
                ),
              ),
            ],
          ),
        ],
      );
      final restored = itineraryFromSnapshot(itinerarySnapshot(itinerary));
      var editCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: SavedItineraryPreviewPage(
            itinerary: restored,
            onEdit: () => editCount++,
          ),
        ),
      );

      expect(find.text('已儲存旅程'), findsOneWidget);
      expect(find.text('Day 1・10/4'), findsOneWidget);
      expect(find.text('測試景點'), findsOneWidget);
      expect(find.text('純步行・20 分鐘・估計'), findsOneWidget);
      expect(find.text('儲存行程'), findsNothing);

      await tester.tap(find.text('查看推薦理由'));
      await tester.pump();
      expect(find.text('適合早上參觀'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('open-editable-itinerary')));
      expect(editCount, 1);
    },
  );
}
