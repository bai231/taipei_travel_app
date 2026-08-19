import '../algorithm/route_optimizer.dart';
import '../models/scheduled_visit.dart';
import '../models/tdx_route.dart';

class ItineraryScheduleService {
  const ItineraryScheduleService();

  ScheduledVisit scheduleVisit({
    required int departureMinutes,
    required int travelMinutes,
    required RouteStop destination,
  }) {
    final arrivalMinutes = departureMinutes + travelMinutes;
    final visitStartMinutes = destination.earliestTimeMinutes == null
        ? arrivalMinutes
        : arrivalMinutes < destination.earliestTimeMinutes!
        ? destination.earliestTimeMinutes!
        : arrivalMinutes;
    final waitingMinutes = visitStartMinutes - arrivalMinutes;
    final visitEndMinutes = visitStartMinutes + destination.stayDurationMinutes;

    return ScheduledVisit(
      departureMinutes: departureMinutes,
      arrivalMinutes: arrivalMinutes,
      visitStartMinutes: visitStartMinutes,
      visitEndMinutes: visitEndMinutes,
      waitingMinutes: waitingMinutes,
      stayMinutes: destination.stayDurationMinutes,
    );
  }

  TdxRoute? selectRouteForDeparture({
    required List<TdxRoute> routes,
    required DateTime requestedDeparture,
  }) {
    final availableRoutes = routes.where((route) {
      return route.startTime == null ||
          !route.startTime!.isBefore(requestedDeparture);
    }).toList();
    if (availableRoutes.isEmpty) return null;
    availableRoutes.sort((first, second) {
      final firstArrival = first.endTime;
      final secondArrival = second.endTime;
      if (firstArrival == null && secondArrival == null) {
        return first.travelTime.compareTo(second.travelTime);
      }
      if (firstArrival == null) return 1;
      if (secondArrival == null) return -1;
      return firstArrival.compareTo(secondArrival);
    });
    return availableRoutes.first;
  }

  int travelMinutesFromTdx({
    required TdxRoute route,
    required DateTime requestedDeparture,
  }) {
    final endTime = route.endTime;
    if (endTime == null || !endTime.isAfter(requestedDeparture)) {
      return (route.travelTime / 60).ceil().clamp(1, 1 << 30).toInt();
    }
    return (endTime.difference(requestedDeparture).inSeconds / 60)
        .ceil()
        .clamp(1, 1 << 30)
        .toInt();
  }
}
