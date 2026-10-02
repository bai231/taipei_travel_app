import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/route_planning/models/route_itinerary.dart';
import '../features/route_planning/models/route_place_input.dart';
import '../features/route_planning/models/route_travel_mode.dart';
import '../features/route_planning/pages/itinerary_result_page.dart';
import '../features/route_planning/services/itinerary_planning_service.dart';
import '../features/route_planning/services/itinerary_place_resolver.dart';
import '../models/place.dart';
import '../models/trip_place_constraint.dart';
import '../services/itinerary_snapshot_reader.dart';
import '../services/place_service.dart';
import '../services/saved_itinerary_service.dart';
import 'trip_planner_page.dart';

/// A saved result is displayed from its snapshot; route APIs are only called
/// after the user explicitly generates a new preview in the planner.
class SavedItineraryResultPage extends StatefulWidget {
  final String id;
  const SavedItineraryResultPage({super.key, required this.id});

  @override
  State<SavedItineraryResultPage> createState() =>
      _SavedItineraryResultPageState();
}

class _SavedItineraryResultPageState extends State<SavedItineraryResultPage> {
  late Future<RouteItinerary> _itinerary;
  Future<List<Place>>? _catalog;

  Future<List<Place>> _loadCatalog() =>
      _catalog ??= PlaceService().getTripCatalog();

  SavedItineraryService get _service =>
      SavedItineraryService(Supabase.instance.client);

  Future<RouteItinerary> _load() async =>
      itineraryFromSnapshot(await _service.read(widget.id));

  @override
  void initState() {
    super.initState();
    _itinerary = _load();
  }

  Future<void> _edit(RouteItinerary itinerary) async {
    try {
      final catalog = await _loadCatalog();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TripPlannerPage(
            request: itinerary.request,
            places: catalog,
            initialInputs: itinerary.inputs,
            initialTravelModeOverrides: itinerary.travelModeOverrides,
            savedItineraryId: widget.id,
          ),
        ),
      );
      if (mounted) setState(() => _itinerary = _load());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('無法開啟行程編輯：$error')));
    }
  }

  Future<RouteItinerary> _recalculate(
    List<TripPlaceConstraint> constraints,
    Map<RouteLegKey, RouteTravelMode> modes,
    RouteItinerary previous,
  ) => ItineraryPlanningService().generate(
    request: previous.request,
    places: [
      for (final item in constraints)
        RoutePlaceInput(
          place: item.place,
          day: item.day,
          startMinutes: item.startMinutes,
          locked: item.locked,
          preferences: item.preferences,
          kind: item.kind,
          suggestedMealType: item.suggestedMealType,
        ),
    ],
    travelModeOverrides: modes,
    reusableItinerary: previous,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<RouteItinerary>(
    future: _itinerary,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Scaffold(
          appBar: AppBar(title: const Text('我的行程')),
          body: Center(
            child: snapshot.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('讀取已儲存行程失敗'),
                      TextButton(
                        onPressed: () => setState(() => _itinerary = _load()),
                        child: const Text('重試'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          ),
        );
      }
      return ItineraryResultPage(
        key: ValueKey('${widget.id}:${snapshot.data!.generatedAt}'),
        itinerary: snapshot.data!,
        savedItineraryId: widget.id,
        onEditItinerary: _edit,
        onRecalculate: _recalculate,
        onResolvePlaceQuery: (query, excludedIds) async {
          final catalog = await _loadCatalog();
          return const ItineraryPlaceResolver().search(
            query: query,
            places: catalog,
            excludedPlaceIds: excludedIds,
            preferredLocation: snapshot.data!.request.location,
          );
        },
      );
    },
  );
}
