import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../../../services/live_itinerary_tracking_service.dart';
import '../../../services/transit_realtime_monitor.dart';
import '../../../services/weather_advisory_service.dart';
import '../models/route_itinerary.dart';
import '../pages/itinerary_result_dependencies.dart';

/// Keeps a started trip alive after its result page is removed from the tree.
/// This is an in-process session, not an Android process-restart mechanism.
class ActiveGuardianSession with WidgetsBindingObserver {
  static ActiveGuardianSession? active;
  static int _nextSessionId = 0;
  static final _ActiveGuardianNotifier _activeListenable =
      _ActiveGuardianNotifier();
  static ValueListenable<ActiveGuardianSession?> get activeListenable =>
      _activeListenable;

  final LiveItineraryTrackingService tracker;
  final ItineraryResultDependencies dependencies;
  final String id =
      '${DateTime.now().microsecondsSinceEpoch}-${++_nextSessionId}';
  RouteItinerary itinerary;
  final ForegroundTransitGuardian _transitGuardian;
  StreamSubscription<TripTrackingUpdate>? _updates;
  Timer? _clock;
  bool _pageAttached = false;
  bool _appVisible = true;
  bool _evaluating = false;
  DateTime? _lastRealtimeCheck;
  final Map<String, DateTime> _lastRiskNotice = {};
  TripTrackingUpdate? _pendingRiskUpdate;
  List<WeatherAdvisory> _pendingWeatherAdvisories = const [];
  TripTrackingUpdate? latestUpdate;
  VoidCallback? onForeground;

  ActiveGuardianSession({
    required this.tracker,
    required this.dependencies,
    required this.itinerary,
  }) : _transitGuardian = ForegroundTransitGuardian(
         monitor: TransitRealtimeMonitor(gateway: dependencies.realtimeGateway),
       );

  bool get isForegroundVisible => _pageAttached && _appVisible;
  bool get hasAttachedPage => _pageAttached;

  Future<void> activate() async {
    if (active != null && !identical(active, this)) {
      await active!.stop();
    }
    active = this;
    _activeListenable.value = this;
    WidgetsBinding.instance.addObserver(this);
    _updates = tracker.updates.listen(_onUpdate);
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      // Simulation evaluates only on the explicit GPS submit action. Live
      // tracking still checks the last location as time advances.
      if (dependencies.debugController?.enabled != true) tracker.checkNow();
    });
  }

  void attachPage({VoidCallback? onResume}) {
    _pageAttached = true;
    onForeground = onResume;
    _refreshActiveEntryAfterFrame();
  }

  void detachPage() {
    _pageAttached = false;
    onForeground = null;
    _refreshActiveEntryAfterFrame();
  }

  void _refreshActiveEntryAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(active, this)) _activeListenable.refresh();
    });
  }

  void updateItinerary(RouteItinerary value) {
    itinerary = value;
    tracker.updateItinerary(value);
  }

  TripTrackingUpdate? takePendingRiskUpdate() {
    final value = _pendingRiskUpdate;
    _pendingRiskUpdate = null;
    return value;
  }

  List<WeatherAdvisory> takePendingWeatherAdvisories() {
    final value = _pendingWeatherAdvisories;
    _pendingWeatherAdvisories = const [];
    return value;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = state == AppLifecycleState.resumed;
    if (_appVisible) onForeground?.call();
  }

  void _onUpdate(TripTrackingUpdate update) {
    latestUpdate = update;
    if (dependencies.debugController?.enabled == true &&
        !update.isLocationStreamUpdate) {
      return;
    }
    if (!isForegroundVisible) unawaited(_evaluateHeadless(update));
  }

  Future<void> _evaluateHeadless(TripTrackingUpdate update) async {
    if (_evaluating || !identical(active, this)) return;
    _evaluating = true;
    try {
      final now = dependencies.now();
      final day = itinerary.days
          .where(
            (candidate) =>
                candidate.date.year == now.year &&
                candidate.date.month == now.month &&
                candidate.date.day == now.day,
          )
          .firstOrNull;
      if (day == null) return;

      try {
        final weather = await dependencies.weatherGateway.check(
          update.location,
          now: now,
          guardianSessionId: id,
        );
        if (weather != null && weather.advisories.isNotEmpty) {
          _pendingWeatherAdvisories = List.unmodifiable(weather.advisories);
        }
      } catch (_) {
        // Weather cannot interrupt trip monitoring.
      }

      // GPS and clock ticks may be frequent. Do not spend TDX quota on each.
      final checkRealtime =
          _lastRealtimeCheck == null ||
          now.isBefore(_lastRealtimeCheck!) ||
          now.difference(_lastRealtimeCheck!) >= const Duration(minutes: 2);
      if (checkRealtime) {
        _lastRealtimeCheck = now;
        try {
          final risk = await _transitGuardian.check(
            day: day,
            location: update.location,
            now: now,
          );
          if (risk != null) {
            final key = '${risk.kind.name}|${risk.affectedSection.stableKey}';
            if (_shouldNotify(key, now)) {
              _pendingRiskUpdate = update;
              await dependencies.notificationGateway.showTransitRisk(
                reason: risk.reason,
                nextStopName:
                    risk.affectedSection.section.arrivalTitle ?? '下一個目的地',
              );
            }
            return;
          }
        } catch (_) {
          // Retry at the next permitted check; never claim a route was verified.
        }
      }

      final alert = update.delayAlert;
      if (alert != null) {
        _pendingRiskUpdate = update;
        await dependencies.notificationGateway.showAlternativeAvailable(
          lateMinutes: alert.lateMinutes,
          nextStopName: alert.nextStopName,
        );
      }
    } catch (_) {
      // A notification failure must not end the location foreground service.
    } finally {
      _evaluating = false;
    }
  }

  bool _shouldNotify(String key, DateTime now) {
    final previous = _lastRiskNotice[key];
    if (previous != null &&
        !now.isBefore(previous) &&
        now.difference(previous) < const Duration(minutes: 15)) {
      return false;
    }
    _lastRiskNotice[key] = now;
    return true;
  }

  Future<void> stop() async {
    _clock?.cancel();
    _clock = null;
    await _updates?.cancel();
    _updates = null;
    WidgetsBinding.instance.removeObserver(this);
    await tracker.stop();
    if (!_pageAttached) {
      await tracker.dispose();
      dependencies.weatherGateway.dispose();
      dependencies.disposeRealtimeGateway?.call();
    }
    if (identical(active, this)) {
      active = null;
      _activeListenable.value = null;
    }
  }
}

class _ActiveGuardianNotifier extends ValueNotifier<ActiveGuardianSession?> {
  _ActiveGuardianNotifier() : super(null);

  void refresh() => notifyListeners();
}
