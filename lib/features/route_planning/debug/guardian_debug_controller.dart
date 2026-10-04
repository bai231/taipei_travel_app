import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/route_travel_mode.dart';
import '../../../models/tdx_route.dart';
import '../../../services/google_route_planning_gateway.dart';
import '../../../services/location_service.dart';
import '../../../services/tdx_realtime_service.dart';
import '../../../services/tdx_service.dart';
import '../../../services/transit_realtime_monitor.dart';
import '../../../services/trip_notification_service.dart';
import '../../../services/weather_advisory_service.dart';

enum GuardianTransitScenario {
  onTime('準點'),
  delayed('延誤 10 分鐘'),
  cancelled('班次取消'),
  disrupted('營運中斷'),
  stale('過期資料'),
  failed('即時班次查詢失敗'),
  missedTransfer('前段晚到，錯過所選轉乘');

  final String label;
  const GuardianTransitScenario(this.label);
}

enum GuardianWeatherScenario {
  normal('正常'),
  rain('高降雨機率'),
  heat('高溫'),
  uv('高紫外線'),
  failed('天氣查詢失敗');

  final String label;
  const GuardianWeatherScenario(this.label);
}

/// Debug-only proxy for exercising the foreground guardian on a phone.
///
/// When disabled every call is delegated to the production service. In
/// simulation mode, route planning still queries real TDX and Google Maps;
/// location, live vehicle observations and weather remain simulated. Test
/// notifications are sent to the OS with a visible test label.
class GuardianDebugController extends ChangeNotifier
    implements
        LocationTrackingGateway,
        TransitRealtimeGateway,
        TdxRoutingGateway,
        GoogleRoutePlanningGateway,
        WeatherAdvisoryGateway,
        TripNotificationGateway {
  final LocationTrackingGateway realLocation;
  final TransitRealtimeGateway realRealtime;
  final TdxRoutingGateway realRouting;
  final GoogleRoutePlanningGateway realGoogle;
  final WeatherAdvisoryGateway realWeather;
  final TripNotificationGateway realNotifications;
  final DateTime Function() realNow;
  final StreamController<LocationPoint> _locations =
      StreamController<LocationPoint>.broadcast();

  bool enabled = false;
  DateTime simulatedNow;
  LocationPoint simulatedLocation;
  GuardianTransitScenario transitScenario = GuardianTransitScenario.onTime;
  TransitSectionIdentity? transitTarget;
  TransitSectionIdentity? transitIncoming;
  GuardianWeatherScenario weatherScenario = GuardianWeatherScenario.normal;
  final List<String> events = [];

  GuardianDebugController({
    required this.realLocation,
    required this.realRealtime,
    required this.realRouting,
    required this.realGoogle,
    required this.realWeather,
    required this.realNotifications,
    required this.realNow,
    DateTime? initialTime,
    this.simulatedLocation = const LocationPoint(
      latitude: 25.0478,
      longitude: 121.517,
    ),
  }) : simulatedNow = initialTime ?? realNow();

  DateTime now() => enabled ? simulatedNow : realNow();

  void setEnabled(bool value) {
    if (enabled == value) return;
    enabled = value;
    _record(value ? '已啟用模擬模式；請重新開始行程追蹤。' : '已停用模擬模式。');
  }

  void advance(Duration duration) {
    simulatedNow = simulatedNow.add(duration);
    _record('時間前進 ${duration.inMinutes} 分鐘；尚未送出 GPS 更新。');
  }

  void setTime(DateTime value) {
    simulatedNow = value;
    _record('模擬時間已切換到行程日期；尚未送出 GPS 更新。');
  }

  void jumpTo({
    required DateTime time,
    required LocationPoint location,
    required String locationName,
  }) {
    simulatedNow = time;
    simulatedLocation = location;
    _record('模擬時間與位置已切換至 $locationName；尚未送出 GPS 更新。');
  }

  void setLocation(LocationPoint location, {String? label}) {
    simulatedLocation = location;
    _record('位置設為 ${label ?? '${location.latitude}, ${location.longitude}'}。');
  }

  void emitLocation() {
    if (!enabled) return;
    _locations.add(simulatedLocation);
    _record('送出一筆模擬 GPS 更新。');
  }

  void setTransitScenario(GuardianTransitScenario value) {
    if (value == GuardianTransitScenario.missedTransfer &&
        transitIncoming == null) {
      _record('請先選擇有前一段公車或臺鐵的轉乘班次。');
      return;
    }
    transitScenario = value;
    _record('TDX 情境改為「${value.label}」。');
  }

  void setTransitTarget(
    TransitSectionIdentity? target, {
    TransitSectionIdentity? incoming,
  }) {
    transitTarget = target;
    transitIncoming = incoming;
    transitScenario = GuardianTransitScenario.onTime;
    _record(
      target == null
          ? '模擬目標改為當日所有班次。'
          : '模擬目標改為第 ${target.legIndex + 1} 段路程的'
                '${target.section.lineName ?? target.provider.name}班次；其他班次維持準點。',
    );
  }

  void setWeatherScenario(GuardianWeatherScenario value) {
    weatherScenario = value;
    _record('天氣情境改為「${value.label}」。');
  }

  @override
  Future<LocationPoint?> getCurrentLocation() async =>
      enabled ? simulatedLocation : realLocation.getCurrentLocation();

  @override
  Stream<LocationPoint> watchLocation() =>
      enabled ? _locations.stream : realLocation.watchLocation();

  @override
  Future<TransitRealtimeObservation?> load(
    TransitSectionIdentity identity,
  ) async {
    if (!enabled) return realRealtime.load(identity);
    _record('讀取模擬 TDX：${identity.section.lineName ?? identity.provider.name}。');
    final isIncomingForMissedTransfer =
        transitScenario == GuardianTransitScenario.missedTransfer &&
        _sameSection(identity, transitIncoming);
    final scenario = transitScenario == GuardianTransitScenario.missedTransfer
        ? (isIncomingForMissedTransfer
              ? GuardianTransitScenario.missedTransfer
              : GuardianTransitScenario.onTime)
        : transitTarget == null || _sameSection(identity, transitTarget)
        ? transitScenario
        : GuardianTransitScenario.onTime;
    if (scenario == GuardianTransitScenario.failed) {
      throw const TdxRealtimeException(503);
    }
    final baseDeparture = identity.scheduledDeparture ?? simulatedNow;
    final baseArrival =
        identity.scheduledArrival ??
        baseDeparture.add(const Duration(minutes: 20));
    final delay = scenario == GuardianTransitScenario.delayed
        ? const Duration(minutes: 10)
        : Duration.zero;
    var expectedArrival = baseArrival.add(delay);
    if (isIncomingForMissedTransfer) {
      final target = transitTarget!;
      final targetDeparture = target.scheduledDeparture!;
      final boardingBuffer = target.provider == TransitProvider.tra
          ? const Duration(minutes: 10)
          : const Duration(minutes: 3);
      final missedArrival = targetDeparture
          .subtract(target.transferWalkFromPrevious)
          .subtract(boardingBuffer)
          .add(const Duration(minutes: 5));
      if (expectedArrival.isBefore(missedArrival)) {
        expectedArrival = missedArrival;
      }
      final afterNow = simulatedNow.add(const Duration(minutes: 2));
      if (expectedArrival.isBefore(afterNow)) expectedArrival = afterNow;
    }
    return TransitRealtimeObservation(
      expectedDeparture: baseDeparture.add(delay),
      expectedArrival: expectedArrival,
      updatedAt: scenario == GuardianTransitScenario.stale
          ? simulatedNow.subtract(const Duration(minutes: 10))
          : simulatedNow,
      cancelled: scenario == GuardianTransitScenario.cancelled,
      disrupted: scenario == GuardianTransitScenario.disrupted,
      message: switch (scenario) {
        GuardianTransitScenario.delayed => '班次延誤 10 分鐘。',
        GuardianTransitScenario.cancelled => '班次已取消。',
        GuardianTransitScenario.disrupted => '路線營運中斷。',
        GuardianTransitScenario.stale => '班次資訊已過期。',
        GuardianTransitScenario.missedTransfer => '前段班次晚到，可能錯過轉乘。',
        _ => null,
      },
      source: 'Debug TDX',
    );
  }

  bool _sameSection(
    TransitSectionIdentity identity,
    TransitSectionIdentity? selected,
  ) =>
      selected != null &&
      identity.legIndex == selected.legIndex &&
      identity.sectionIndex == selected.sectionIndex &&
      identity.stableKey == selected.stableKey &&
      identity.serviceDate == selected.serviceDate;

  @override
  Future<List<TdxRoute>> getRoutingOptions({
    required String origin,
    required String destination,
    DateTime? departureTime,
  }) async {
    if (enabled) _record('正在向 TDX 查詢真實大眾運輸備案。');
    try {
      final routes = await realRouting.getRoutingOptions(
        origin: origin,
        destination: destination,
        departureTime: departureTime,
      );
      if (enabled) _record('TDX 回傳 ${routes.length} 條真實備案路線。');
      return routes;
    } catch (_) {
      if (enabled) _record('TDX 路線查詢失敗，未使用假路線替代。');
      rethrow;
    }
  }

  @override
  Future<TdxRoute?> getRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required DateTime requestedDeparture,
    required RouteTravelMode travelMode,
  }) async {
    if (enabled) _record('正在向 Google Maps 查詢真實${travelMode.label}路線。');
    try {
      final route = await realGoogle.getRoute(
        originLatitude: originLatitude,
        originLongitude: originLongitude,
        destinationLatitude: destinationLatitude,
        destinationLongitude: destinationLongitude,
        requestedDeparture: requestedDeparture,
        travelMode: travelMode,
      );
      if (enabled) {
        _record(
          route == null
              ? 'Google Maps 查無可用路線。'
              : 'Google Maps 回傳真實${travelMode.label}路線。',
        );
      }
      return route;
    } catch (_) {
      if (enabled) _record('Google Maps 路線查詢失敗，未使用假路線替代。');
      rethrow;
    }
  }

  @override
  bool get isConfigured => enabled || realWeather.isConfigured;

  @override
  Future<WeatherCheckResult?> check(
    LocationPoint position, {
    DateTime? now,
    String? guardianSessionId,
  }) async {
    if (!enabled) {
      return realWeather.check(
        position,
        now: now,
        guardianSessionId: guardianSessionId,
      );
    }
    _record('檢查模擬天氣：${weatherScenario.label}。');
    final advisory = switch (weatherScenario) {
      GuardianWeatherScenario.normal || GuardianWeatherScenario.failed => null,
      GuardianWeatherScenario.rain => const WeatherAdvisory(
        kind: 'rain',
        title: '稍後可能下雨',
        body: '目前位置稍後可能下雨，請備妥雨具。',
        level: WeatherRiskLevel.warning,
      ),
      GuardianWeatherScenario.heat => const WeatherAdvisory(
        kind: 'heat',
        title: '天氣炎熱',
        body: '請補充水分，並注意防曬。',
        level: WeatherRiskLevel.warning,
      ),
      GuardianWeatherScenario.uv => const WeatherAdvisory(
        kind: 'uv',
        title: '紫外線偏強',
        body: '外出請注意防曬。',
        level: WeatherRiskLevel.warning,
      ),
    };
    if (advisory == null) return null;
    await showWeatherAdvisory(
      id: 7901,
      title: advisory.title,
      body: advisory.body,
      payload: guardianSessionId == null
          ? null
          : 'guardian:weather:$guardianSessionId',
    );
    return WeatherCheckResult(
      forecast: const CwaForecast(),
      advisories: [advisory],
    );
  }

  @override
  Future<void> initialize() async {
    await realNotifications.initialize();
  }

  @override
  Future<bool?> androidNotificationsEnabled() async =>
      realNotifications.androidNotificationsEnabled();

  @override
  Future<void> showScheduleAdjusted({
    required int lateMinutes,
    required String nextStopName,
  }) async {
    if (!enabled) {
      return realNotifications.showScheduleAdjusted(
        lateMinutes: lateMinutes,
        nextStopName: nextStopName,
      );
    }
    await showTestNotification(
      title: '行程已調整',
      body: '目前約晚了 $lateMinutes 分鐘；下一站 $nextStopName。',
    );
  }

  @override
  Future<void> showAlternativeAvailable({
    required int lateMinutes,
    required String nextStopName,
  }) async {
    if (!enabled) {
      return realNotifications.showAlternativeAvailable(
        lateMinutes: lateMinutes,
        nextStopName: nextStopName,
      );
    }
    await showTestNotification(
      title: '行程可能延誤',
      body: '目前約晚了 $lateMinutes 分鐘；請開啟 App 檢查 $nextStopName 的備案。',
    );
  }

  @override
  Future<void> showTransitRisk({
    required String reason,
    required String nextStopName,
  }) async {
    if (!enabled) {
      return realNotifications.showTransitRisk(
        reason: reason,
        nextStopName: nextStopName,
      );
    }
    await showTestNotification(
      title: '可能趕不上原班次',
      body: '$reason 請開啟 App 查詢前往 $nextStopName 的備案。',
    );
  }

  @override
  Future<void> showWeatherAdvisory({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!enabled) {
      return realNotifications.showWeatherAdvisory(
        id: id,
        title: title,
        body: body,
        payload: payload,
      );
    }
    await showTestNotification(title: title, body: body);
  }

  @override
  Future<void> showTestNotification({
    required String title,
    required String body,
  }) async {
    await realNotifications.showTestNotification(title: title, body: body);
    _record('已發送測試手機通知：$title。');
  }

  void _record(String message) {
    events.insert(0, message);
    if (events.length > 20) events.removeLast();
    notifyListeners();
  }

  @override
  void dispose() {
    realWeather.dispose();
    _locations.close();
    super.dispose();
  }
}
