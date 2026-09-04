import '../../../algorithm/route_optimizer.dart';
import '../../../models/trip_request.dart';
import 'route_day.dart';
import 'route_place_input.dart';

class RouteItinerary {
  final TripRequest request;
  final RouteStop origin;
  final List<RouteDay> days;
  final DateTime generatedAt;
  final List<String> warnings;
  final List<RoutePlaceInput> inputs;

  RouteItinerary({
    required this.request,
    required this.origin,
    required List<RouteDay> days,
    required this.generatedAt,
    List<String> warnings = const [],
    List<RoutePlaceInput> inputs = const [],
  }) : days = List.unmodifiable(days),
       warnings = List.unmodifiable(warnings),
       inputs = List.unmodifiable(inputs);

  RouteDay day(int dayNumber) {
    return days.firstWhere((day) => day.day == dayNumber);
  }
}
