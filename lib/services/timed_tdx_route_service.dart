import '../models/tdx_route.dart';
import 'itinerary_schedule_service.dart';
import 'tdx_service.dart';

class TimedTdxRouteService {
  final TdxRoutingGateway _gateway;
  final ItineraryScheduleService _scheduleService;
  final Duration requestInterval;
  final List<int> searchOffsetsMinutes;
  final Map<String, List<TdxRoute>> _cache = {};

  TimedTdxRouteService({
    TdxRoutingGateway? gateway,
    this.requestInterval = const Duration(seconds: 2),
    this.searchOffsetsMinutes = const [0, 15, 30],
  }) : _gateway = gateway ?? TdxService(),
       _scheduleService = const ItineraryScheduleService();

  Future<TdxRoute?> getRouteAtOrAfter({
    required String origin,
    required String destination,
    required DateTime requestedDeparture,
    void Function(DateTime queryTime)? onRetry,
  }) async {
    for (var index = 0; index < searchOffsetsMinutes.length; index++) {
      final queryTime = requestedDeparture.add(
        Duration(minutes: searchOffsetsMinutes[index]),
      );
      if (index > 0) {
        onRetry?.call(queryTime);
        await Future<void>.delayed(requestInterval);
      }
      final routes = await _loadRoutes(
        origin: origin,
        destination: destination,
        departureTime: queryTime,
      );
      final route = _scheduleService.selectRouteForDeparture(
        routes: routes,
        requestedDeparture: requestedDeparture,
      );
      if (route != null) return route;
    }
    return null;
  }

  Future<List<TdxRoute>> _loadRoutes({
    required String origin,
    required String destination,
    required DateTime departureTime,
  }) async {
    final cacheKey = '$origin->$destination@${departureTime.toIso8601String()}';
    final cachedRoutes = _cache[cacheKey];
    if (cachedRoutes != null) return cachedRoutes;
    final routes = await _gateway.getRoutingOptions(
      origin: origin,
      destination: destination,
      departureTime: departureTime,
    );
    _cache[cacheKey] = routes;
    return routes;
  }
}
