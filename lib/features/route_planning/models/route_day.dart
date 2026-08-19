import '../../../algorithm/route_optimizer.dart';
import 'route_visit.dart';
import 'travel_leg.dart';

class RouteDay {
  final int day;
  final DateTime date;
  final RouteStop origin;
  final List<RouteVisit> visits;
  final List<TravelLeg> travelLegs;
  final bool isValid;
  final List<String> warnings;

  RouteDay({
    required this.day,
    required this.date,
    required this.origin,
    required List<RouteVisit> visits,
    required List<TravelLeg> travelLegs,
    required this.isValid,
    List<String> warnings = const [],
  }) : visits = List.unmodifiable(visits),
       travelLegs = List.unmodifiable(travelLegs),
       warnings = List.unmodifiable(warnings);
}
