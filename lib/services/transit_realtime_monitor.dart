import 'dart:math';

import '../features/route_planning/models/route_day.dart';
import '../models/tdx_route.dart';
import 'location_service.dart';

enum TransitProvider { bus, tra }

enum TransitRiskKind { boarding, transfer, cancelled, disrupted }

class TransitSectionIdentity {
  final TransitProvider provider;
  final int legIndex;
  final int sectionIndex;
  final DateTime serviceDate;
  final RouteSection section;
  final Duration transferWalkFromPrevious;

  const TransitSectionIdentity({
    required this.provider,
    required this.legIndex,
    required this.sectionIndex,
    required this.serviceDate,
    required this.section,
    this.transferWalkFromPrevious = Duration.zero,
  });

  String get stableKey => [
    provider.name,
    section.serviceId ?? '',
    section.routeId ?? '',
    section.departureStopId ?? section.departureTitle ?? '',
    section.arrivalStopId ?? section.arrivalTitle ?? '',
    scheduledDeparture?.toIso8601String() ?? '',
  ].join('|');

  DateTime? get scheduledDeparture =>
      section.scheduledDeparture ?? _timeOnDate(section.departureTime);

  DateTime? get scheduledArrival =>
      section.scheduledArrival ?? _timeOnDate(section.arrivalTime);

  DateTime? _timeOnDate(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(
      serviceDate.year,
      serviceDate.month,
      serviceDate.day,
      hour,
      minute,
    );
  }

  static TransitProvider? providerFor(RouteSection section) {
    final values = [
      section.operatorCode,
      section.mode,
    ].whereType<String>().join(' ').toLowerCase();
    if (values.contains('tra') || section.mode == 'train') {
      return TransitProvider.tra;
    }
    if (values.contains('bus') || section.mode == 'bus') {
      return TransitProvider.bus;
    }
    return null;
  }
}

class TransitRealtimeObservation {
  final DateTime? expectedDeparture;
  final DateTime? expectedArrival;
  final DateTime updatedAt;
  final bool cancelled;
  final bool disrupted;
  final String? message;
  final String source;

  const TransitRealtimeObservation({
    this.expectedDeparture,
    this.expectedArrival,
    required this.updatedAt,
    this.cancelled = false,
    this.disrupted = false,
    this.message,
    required this.source,
  });

  bool isStaleAt(
    DateTime now, {
    Duration maximumAge = const Duration(minutes: 5),
  }) => now.difference(updatedAt).abs() > maximumAge;
}

abstract interface class TransitRealtimeGateway {
  Future<TransitRealtimeObservation?> load(TransitSectionIdentity identity);
}

class TransitConnectionRisk {
  final TransitRiskKind kind;
  final TransitSectionIdentity affectedSection;
  final TransitSectionIdentity? incomingSection;
  final DateTime? expectedReadyAt;
  final DateTime? expectedDeparture;
  final int shortageMinutes;
  final String reason;
  final TransitRealtimeObservation? observation;

  const TransitConnectionRisk({
    required this.kind,
    required this.affectedSection,
    this.incomingSection,
    this.expectedReadyAt,
    this.expectedDeparture,
    required this.shortageMinutes,
    required this.reason,
    this.observation,
  });
}

/// Evaluates only the next relevant bus/TRA boarding or transfer. Completed
/// sections are never changed here; this service reports risk and leaves route
/// replacement to the explicit user-confirmation flow.
class TransitRealtimeMonitor {
  final TransitRealtimeGateway gateway;
  final int walkingMetersPerMinute;
  final Duration busBoardingBuffer;
  final Duration traBoardingBuffer;

  const TransitRealtimeMonitor({
    required this.gateway,
    this.walkingMetersPerMinute = 75,
    this.busBoardingBuffer = const Duration(minutes: 3),
    this.traBoardingBuffer = const Duration(minutes: 10),
  });

  Future<TransitConnectionRisk?> check({
    required RouteDay day,
    required LocationPoint location,
    required DateTime now,
  }) async {
    final sections = _sections(day);
    final observations = <String, TransitRealtimeObservation?>{};
    Future<TransitRealtimeObservation?> observationFor(
      TransitSectionIdentity identity,
    ) async {
      if (observations.containsKey(identity.stableKey)) {
        return observations[identity.stableKey];
      }
      final value = await gateway.load(identity);
      observations[identity.stableKey] = value;
      return value;
    }

    for (var index = 0; index < sections.length; index++) {
      final current = sections[index];
      final departure = current.scheduledDeparture;
      final arrival = current.scheduledArrival;
      if (arrival != null && arrival.isBefore(now)) continue;

      final currentRealtime = await observationFor(current);
      final freshCurrent =
          currentRealtime != null && !currentRealtime.isStaleAt(now)
          ? currentRealtime
          : null;
      if (freshCurrent?.cancelled == true) {
        return TransitConnectionRisk(
          kind: TransitRiskKind.cancelled,
          affectedSection: current,
          expectedDeparture: freshCurrent?.expectedDeparture ?? departure,
          shortageMinutes: 0,
          reason: freshCurrent?.message ?? '原訂班次已取消。',
          observation: freshCurrent,
        );
      }
      if (freshCurrent?.disrupted == true) {
        return TransitConnectionRisk(
          kind: TransitRiskKind.disrupted,
          affectedSection: current,
          expectedDeparture: freshCurrent?.expectedDeparture ?? departure,
          shortageMinutes: 0,
          reason: freshCurrent?.message ?? '原訂路線目前有營運異常。',
          observation: freshCurrent,
        );
      }

      final expectedDeparture = freshCurrent?.expectedDeparture ?? departure;
      if (expectedDeparture == null) continue;

      final expectedArrival =
          freshCurrent?.expectedArrival ?? current.scheduledArrival;
      if (expectedDeparture.isBefore(now) &&
          expectedArrival != null &&
          expectedArrival.isAfter(now) &&
          _isAwayFromBoardingStop(current, location)) {
        // 已離開上車站且仍在該路段預計行駛時間內，視為正在搭乘；
        // 下一輪會以這段的即時抵達時間評估後續轉乘。
        continue;
      }

      final connection = _previousTransitConnection(sections, index);
      if (connection != null) {
        final incomingRealtime = await observationFor(connection.identity);
        final freshIncoming =
            incomingRealtime != null && !incomingRealtime.isStaleAt(now)
            ? incomingRealtime
            : null;
        final incomingArrival =
            freshIncoming?.expectedArrival ??
            connection.identity.scheduledArrival;
        if (incomingArrival != null && !incomingArrival.isBefore(now)) {
          final readyAt = incomingArrival
              .add(connection.walkingDuration)
              .add(_bufferFor(current.provider));
          if (readyAt.isAfter(expectedDeparture)) {
            final shortage = readyAt.difference(expectedDeparture).inMinutes;
            return TransitConnectionRisk(
              kind: TransitRiskKind.transfer,
              affectedSection: current,
              incomingSection: connection.identity,
              expectedReadyAt: readyAt,
              expectedDeparture: expectedDeparture,
              shortageMinutes: max(1, shortage),
              reason:
                  '預計 ${_hm(readyAt)} 才能抵達轉乘月台，原班次預計 ${_hm(expectedDeparture)} 離站。',
              observation: freshCurrent,
            );
          }
          return null;
        }
      }

      final stationLat = current.section.departureLatitude;
      final stationLng = current.section.departureLongitude;
      if (stationLat == null || stationLng == null) continue;
      final walkingMinutes = max(
        1,
        (_distanceMeters(
                  location.latitude,
                  location.longitude,
                  stationLat,
                  stationLng,
                ) /
                walkingMetersPerMinute)
            .ceil(),
      );
      final readyAt = now
          .add(Duration(minutes: walkingMinutes))
          .add(_bufferFor(current.provider));
      if (readyAt.isAfter(expectedDeparture)) {
        final shortage = readyAt.difference(expectedDeparture).inMinutes;
        return TransitConnectionRisk(
          kind: TransitRiskKind.boarding,
          affectedSection: current,
          expectedReadyAt: readyAt,
          expectedDeparture: expectedDeparture,
          shortageMinutes: max(1, shortage),
          reason:
              '依目前位置預計 ${_hm(readyAt)} 才能完成上車準備，原班次預計 ${_hm(expectedDeparture)} 離站。',
          observation: freshCurrent,
        );
      }
      return null;
    }
    return null;
  }

  List<TransitSectionIdentity> _sections(RouteDay day) {
    final result = <TransitSectionIdentity>[];
    for (var legIndex = 0; legIndex < day.travelLegs.length; legIndex++) {
      final route = day.travelLegs[legIndex].route;
      if (route == null) continue;
      for (
        var sectionIndex = 0;
        sectionIndex < route.sections.length;
        sectionIndex++
      ) {
        final section = route.sections[sectionIndex];
        final provider = TransitSectionIdentity.providerFor(section);
        if (provider == null) continue;
        var transferWalk = Duration.zero;
        for (var index = sectionIndex - 1; index >= 0; index--) {
          final previous = route.sections[index];
          if (TransitSectionIdentity.providerFor(previous) != null) break;
          if (_isWalking(previous.mode)) {
            transferWalk += Duration(seconds: previous.travelTime);
          }
        }
        result.add(
          TransitSectionIdentity(
            provider: provider,
            legIndex: legIndex,
            sectionIndex: sectionIndex,
            serviceDate: day.date,
            section: section,
            transferWalkFromPrevious: transferWalk,
          ),
        );
      }
    }
    return result;
  }

  _IncomingConnection? _previousTransitConnection(
    List<TransitSectionIdentity> sections,
    int currentIndex,
  ) {
    if (currentIndex <= 0) return null;
    final incoming = sections[currentIndex - 1];
    if (incoming.legIndex != sections[currentIndex].legIndex) return null;
    return _IncomingConnection(
      incoming,
      sections[currentIndex].transferWalkFromPrevious,
    );
  }

  Duration _bufferFor(TransitProvider provider) =>
      provider == TransitProvider.tra ? traBoardingBuffer : busBoardingBuffer;

  bool _isAwayFromBoardingStop(
    TransitSectionIdentity identity,
    LocationPoint location,
  ) {
    final latitude = identity.section.departureLatitude;
    final longitude = identity.section.departureLongitude;
    if (latitude == null || longitude == null) return false;
    return _distanceMeters(
          location.latitude,
          location.longitude,
          latitude,
          longitude,
        ) >
        400;
  }
}

class ForegroundTransitGuardian {
  final TransitRealtimeMonitor monitor;
  final Duration minimumCheckInterval;
  final Duration repeatedAlertCooldown;
  DateTime? _lastCheckedAt;
  final Map<String, DateTime> _lastAlertAt = {};

  ForegroundTransitGuardian({
    required this.monitor,
    this.minimumCheckInterval = const Duration(seconds: 30),
    this.repeatedAlertCooldown = const Duration(minutes: 15),
  });

  Future<TransitConnectionRisk?> check({
    required RouteDay day,
    required LocationPoint location,
    required DateTime now,
  }) async {
    if (_lastCheckedAt != null &&
        now.difference(_lastCheckedAt!) < minimumCheckInterval) {
      return null;
    }
    _lastCheckedAt = now;
    TransitConnectionRisk? risk;
    try {
      risk = await monitor.check(day: day, location: location, now: now);
    } catch (_) {
      return null;
    }
    if (risk == null) return null;
    final key = '${risk.kind.name}|${risk.affectedSection.stableKey}';
    final previous = _lastAlertAt[key];
    if (previous != null && now.difference(previous) < repeatedAlertCooldown) {
      return null;
    }
    _lastAlertAt[key] = now;
    return risk;
  }
}

bool _isWalking(String mode) {
  final normalized = mode.toLowerCase();
  return normalized == 'pedestrian' ||
      normalized == 'walking' ||
      normalized == 'walk';
}

class _IncomingConnection {
  final TransitSectionIdentity identity;
  final Duration walkingDuration;
  const _IncomingConnection(this.identity, this.walkingDuration);
}

String _hm(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

double _distanceMeters(double aLat, double aLng, double bLat, double bLng) {
  const radians = pi / 180;
  final latitudeDifference = (bLat - aLat) * radians;
  final longitudeDifference = (bLng - aLng) * radians;
  final value =
      sin(latitudeDifference / 2) * sin(latitudeDifference / 2) +
      cos(aLat * radians) *
          cos(bLat * radians) *
          sin(longitudeDifference / 2) *
          sin(longitudeDifference / 2);
  return 6371000 * 2 * atan2(sqrt(value), sqrt(1 - value));
}
