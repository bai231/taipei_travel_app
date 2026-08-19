import 'package:flutter/material.dart';

import 'features/route_planning/models/route_itinerary.dart';
import 'features/route_planning/models/route_place_input.dart';
import 'features/route_planning/pages/itinerary_result_page.dart';
import 'features/route_planning/services/itinerary_planning_service.dart';
import 'models/trip_request.dart';
import 'services/place_service.dart';

void main() {
  runApp(const RoutePlanningDemoApp());
}

class RoutePlanningDemoApp extends StatelessWidget {
  const RoutePlanningDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '路線規劃 Demo',
      theme: ThemeData(useMaterial3: true),
      home: const _RoutePlanningDemoLoader(),
    );
  }
}

class _RoutePlanningDemoLoader extends StatefulWidget {
  const _RoutePlanningDemoLoader();

  @override
  State<_RoutePlanningDemoLoader> createState() =>
      _RoutePlanningDemoLoaderState();
}

class _RoutePlanningDemoLoaderState extends State<_RoutePlanningDemoLoader> {
  late Future<RouteItinerary> _itinerary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tripDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    final places = (await PlaceService().getPlaces()).take(3).toList();
    _itinerary = ItineraryPlanningService().generate(
      request: TripRequest(
        title: '台北一日路線 Demo',
        startDate: tripDate,
        endDate: tripDate,
        location: '台北市',
        people: 2,
        budget: 3000,
        preferences: const ['攝影'],
        aiPrompt: '',
      ),
      places: places
          .map((place) => RoutePlaceInput(place: place, day: 1))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RouteItinerary>(
      future: _itinerary,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ItineraryResultPage(itinerary: snapshot.requireData);
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('路線規劃 Demo')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('建立行程失敗：${snapshot.error}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(_load),
                    child: const Text('重新嘗試'),
                  ),
                ],
              ),
            ),
          );
        }
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在依實際時間查詢 TDX 路線…'),
              ],
            ),
          ),
        );
      },
    );
  }
}
