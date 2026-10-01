import 'package:flutter/foundation.dart';

import '../../../services/location_service.dart';
import '../../../services/google_route_planning_gateway.dart';
import '../../../services/google_route_planning_service.dart';
import '../../../services/tdx_realtime_service.dart';
import '../../../services/tdx_service.dart';
import '../../../services/transit_realtime_monitor.dart';
import '../../../services/trip_notification_service.dart';
import '../../../services/weather_advisory_service.dart';
import '../debug/guardian_debug_controller.dart';

/// External services used by the itinerary result page.
///
/// Production callers normally omit this object. Tests and the debug guardian
/// console can provide deterministic location, time, TDX, weather and
/// notification implementations without touching device services.
class ItineraryResultDependencies {
  final LocationTrackingGateway locationGateway;
  final DateTime Function() now;
  final TransitRealtimeGateway realtimeGateway;
  final TdxRoutingGateway routingGateway;
  final GoogleRoutePlanningGateway? googleRoutingGateway;
  final WeatherAdvisoryGateway weatherGateway;
  final WeatherAdvisoryService? productionWeatherService;
  final TripNotificationGateway notificationGateway;
  final void Function()? disposeRealtimeGateway;
  final GuardianDebugController? debugController;

  const ItineraryResultDependencies({
    required this.locationGateway,
    required this.now,
    required this.realtimeGateway,
    required this.routingGateway,
    this.googleRoutingGateway,
    required this.weatherGateway,
    this.productionWeatherService,
    required this.notificationGateway,
    this.disposeRealtimeGateway,
    this.debugController,
  });

  factory ItineraryResultDependencies.production() {
    final notifications = TripNotificationService();
    final realtime = TdxRealtimeService();
    const location = LocationService();
    final routing = TdxService();
    final weather = WeatherAdvisoryService(
      apiKey: const String.fromEnvironment('CWA_API_KEY'),
      notifications: notifications,
    );
    if (kDebugMode) {
      final debug = GuardianDebugController(
        realLocation: location,
        realRealtime: realtime,
        realRouting: routing,
        realGoogle: const GoogleRoutePlanningService(),
        realWeather: weather,
        realNotifications: notifications,
        realNow: DateTime.now,
      );
      return ItineraryResultDependencies(
        locationGateway: debug,
        now: debug.now,
        realtimeGateway: debug,
        routingGateway: debug,
        googleRoutingGateway: debug,
        weatherGateway: debug,
        productionWeatherService: weather,
        notificationGateway: debug,
        disposeRealtimeGateway: realtime.dispose,
        debugController: debug,
      );
    }
    return ItineraryResultDependencies(
      locationGateway: location,
      now: DateTime.now,
      realtimeGateway: realtime,
      routingGateway: routing,
      googleRoutingGateway: const GoogleRoutePlanningService(),
      weatherGateway: weather,
      productionWeatherService: weather,
      notificationGateway: notifications,
      disposeRealtimeGateway: realtime.dispose,
    );
  }
}
