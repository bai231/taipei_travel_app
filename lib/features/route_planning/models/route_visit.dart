import '../../../models/place.dart';

class RouteVisit {
  final Place place;
  final int sequence;
  final int arrivalMinutes;
  final int startMinutes;
  final int endMinutes;
  final int waitingMinutes;
  final int stayMinutes;
  final int? requestedStartMinutes;
  final bool locked;

  const RouteVisit({
    required this.place,
    required this.sequence,
    required this.arrivalMinutes,
    required this.startMinutes,
    required this.endMinutes,
    required this.waitingMinutes,
    required this.stayMinutes,
    required this.requestedStartMinutes,
    required this.locked,
  });
}
