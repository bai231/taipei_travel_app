import '../../../algorithm/route_optimizer.dart';
import '../../../models/trip_request.dart';
import 'route_day.dart';
import 'route_place_input.dart';
import 'route_travel_mode.dart';

class RouteItinerary {
  final TripRequest request;
  final RouteStop origin;
  final List<RouteDay> days;
  final DateTime generatedAt;
  final List<String> warnings;
  final List<RoutePlaceInput> inputs;
  final Map<RouteLegKey, RouteTravelMode> travelModeOverrides;

  RouteItinerary({
    required this.request,
    required this.origin,
    required List<RouteDay> days,
    required this.generatedAt,
    List<String> warnings = const [],
    List<RoutePlaceInput> inputs = const [],
    Map<RouteLegKey, RouteTravelMode> travelModeOverrides = const {},
  }) : days = List.unmodifiable(days),
       warnings = List.unmodifiable(warnings),
       inputs = List.unmodifiable(inputs),
       travelModeOverrides = Map.unmodifiable(travelModeOverrides);

  RouteDay day(int dayNumber) {
    return days.firstWhere((day) => day.day == dayNumber);
  }
}
