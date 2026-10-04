import 'dart:math';

import '../algorithm/route_optimizer.dart';
import '../features/route_planning/models/route_day.dart';
import '../features/route_planning/models/route_travel_mode.dart';
import '../features/route_planning/models/route_visit.dart';
import '../features/route_planning/models/travel_leg.dart';
import '../models/scheduled_visit.dart';
import '../models/tdx_route.dart';
import 'google_route_planning_gateway.dart';
import 'itinerary_schedule_service.dart';
import 'location_service.dart';
import 'tdx_service.dart';

enum LiveAlternativeStrategy { preserveOrder, reorderRemaining }

/// A candidate is never applied here. The caller must show it and ask first.
class LiveAlternativePlan {
  final RouteDay? day;
  final String? failure;
  final List<String> warnings;
  final bool reorderMayHelp;
  final bool needsNewLegMode;

  const LiveAlternativePlan._(
    this.day,
    this.failure,
    this.warnings,
    this.reorderMayHelp,
    this.needsNewLegMode,
  );

  bool get canApply => day != null && failure == null;

  factory LiveAlternativePlan.success(RouteDay day, List<String> warnings) =>
      LiveAlternativePlan._(
        day,
        null,
        List.unmodifiable(warnings),
        false,
        false,
      );

  factory LiveAlternativePlan.failure(
    String reason, {
    bool reorderMayHelp = false,
    bool needsNewLegMode = false,
  }) => LiveAlternativePlan._(
    null,
    reason,
    const [],
    reorderMayHelp,
    needsNewLegMode,
  );
}

/// Re-queries every unfinished leg in departure order. It never substitutes a
/// straight-line estimate for a failed Google or TDX request.
class LiveItineraryAlternativePlanner {
  final TdxRoutingGateway transit;
  final GoogleRoutePlanningGateway google;
  final ItineraryScheduleService schedule;

  const LiveItineraryAlternativePlanner({
    required this.transit,
    required this.google,
    this.schedule = const ItineraryScheduleService(),
  });

  Future<LiveAlternativePlan> plan({
    required RouteDay day,
    required LocationPoint currentLocation,
    required DateTime now,
    required int completedCount,
    required LiveAlternativeStrategy strategy,
    int? affectedLegIndex,
    TdxRoute? selectedFirstRoute,
    RouteTravelMode? newLegMode,
    LocationPoint? firstOrigin,
    DateTime? firstDeparture,
    int preservedFirstSections = 0,
    bool keepFirstRemaining = false,
  }) async {
    if (completedCount < 0 || completedCount > day.visits.length) {
      return LiveAlternativePlan.failure('行程項目與交通路段無法對齊，原行程未變更。');
    }
    // The first visit may itself be the origin, so it has no incoming leg.
    // Match actual legs to visits by occurrence ID instead of list position.
    final visitIndexById = <String, int>{};
    for (var i = 0; i < day.visits.length; i++) {
      if (visitIndexById.containsKey(day.visits[i].occurrenceId)) {
        return LiveAlternativePlan.failure('行程項目識別碼重複，原行程未變更。');
      }
      visitIndexById[day.visits[i].occurrenceId] = i;
    }
    final legByVisitId = <String, TravelLeg>{};
    var previousVisitIndex = -1;
    for (final leg in day.travelLegs) {
      final visitIndex = visitIndexById[leg.destination.id];
      if (visitIndex == null || visitIndex <= previousVisitIndex) {
        return LiveAlternativePlan.failure('行程項目與交通路段無法對齊，原行程未變更。');
      }
      legByVisitId[leg.destination.id] = leg;
      previousVisitIndex = visitIndex;
    }
    if (affectedLegIndex != null &&
        (affectedLegIndex < 0 || affectedLegIndex >= day.travelLegs.length)) {
      return LiveAlternativePlan.failure('受影響路段與已完成進度不一致，請確認行程進度。');
    }
    final first = affectedLegIndex == null
        ? completedCount
        : visitIndexById[day.travelLegs[affectedLegIndex].destination.id]!;
    if (first < completedCount) {
      return LiveAlternativePlan.failure('受影響路段與已完成進度不一致，請確認行程進度。');
    }
    if (first >= day.visits.length) {
      return LiveAlternativePlan.failure('今天沒有尚待安排的項目。');
    }
    final prefixVisits = day.visits.take(first).toList();
    final prefixLegs = day.travelLegs
        .where((leg) => visitIndexById[leg.destination.id]! < first)
        .toList();
    final remaining = day.visits.skip(first).toList();
    final ordered = strategy == LiveAlternativeStrategy.reorderRemaining
        ? keepFirstRemaining && remaining.isNotEmpty
              ? [
                  remaining.first,
                  ..._orderRemaining(
                    remaining.skip(1).toList(),
                    LocationPoint(
                      latitude: remaining.first.place.latitude,
                      longitude: remaining.first.place.longitude,
                    ),
                  ),
                ]
              : _orderRemaining(remaining, currentLocation)
        : remaining;
    final warnings = <String>[];
    final visits = <RouteVisit>[...prefixVisits];
    final legs = <TravelLeg>[...prefixLegs];
    var cursor = firstDeparture != null && firstDeparture.isAfter(now)
        ? firstDeparture
        : now;
    if (prefixVisits.isNotEmpty) {
      final previousEnd = _midnight(
        day.date,
      ).add(Duration(minutes: prefixVisits.last.endMinutes));
      if (previousEnd.isAfter(cursor)) cursor = previousEnd;
    }
    final startingPoint = firstOrigin ?? currentLocation;
    var origin = RouteStop(
      id: 'live-location-${now.millisecondsSinceEpoch}',
      name: '目前位置',
      latitude: startingPoint.latitude,
      longitude: startingPoint.longitude,
      stayDurationMinutes: 0,
    );
    for (var index = 0; index < ordered.length; index++) {
      final original = ordered[index];
      final destination = _stop(original);
      final oldLeg = legByVisitId[original.occurrenceId];
      final atDestination =
          oldLeg == null && _distanceBetweenStops(origin, destination) < 0.05;
      // An unchanged adjacency keeps its mode. A newly adjacent pair needs an
      // explicit default, never the TravelLeg constructor's transit default.
      final unchangedAdjacency =
          oldLeg != null &&
          (index == 0
              ? strategy == LiveAlternativeStrategy.preserveOrder ||
                    keepFirstRemaining
              : origin.id == oldLeg.origin.id);
      if (!atDestination && !unchangedAdjacency && newLegMode == null) {
        return LiveAlternativePlan.failure(
          '從目前位置到「${original.label}」需要新路段，請選擇交通方式。',
          needsNewLegMode: true,
        );
      }
      final mode = unchangedAdjacency
          ? oldLeg.travelMode
          : newLegMode ?? RouteTravelMode.transit;
      TdxRoute? route;
      try {
        if (atDestination) {
          // This visit begins at the current stop, without an incoming leg.
        } else if (index == 0 && selectedFirstRoute != null) {
          if (mode != RouteTravelMode.transit) {
            return LiveAlternativePlan.failure('所選大眾運輸路線與原交通模式不符。');
          }
          route = selectedFirstRoute;
        } else if (mode == RouteTravelMode.transit) {
          try {
            final options = await transit.getRoutingOptions(
              origin: '${origin.latitude},${origin.longitude}',
              destination: '${destination.latitude},${destination.longitude}',
              departureTime: cursor,
            );
            route = schedule.selectRouteForDeparture(
              routes: options,
              requestedDeparture: cursor,
            );
          } catch (_) {
            // Google is a reference fallback, not a TDX realtime service.
          }
          route ??= await google.getRoute(
            originLatitude: origin.latitude,
            originLongitude: origin.longitude,
            destinationLatitude: destination.latitude,
            destinationLongitude: destination.longitude,
            requestedDeparture: cursor,
            travelMode: RouteTravelMode.transit,
          );
        } else {
          route = await google.getRoute(
            originLatitude: origin.latitude,
            originLongitude: origin.longitude,
            destinationLatitude: destination.latitude,
            destinationLongitude: destination.longitude,
            requestedDeparture: cursor,
            travelMode: mode,
          );
        }
      } catch (_) {
        return LiveAlternativePlan.failure(
          '查詢「${origin.name} → ${destination.name}」的${mode.label}路線失敗；原行程未變更。',
        );
      }
      if (route == null && !atDestination) {
        return LiveAlternativePlan.failure(
          '查不到「${origin.name} → ${destination.name}」的${mode.label}路線；原行程未變更。',
        );
      }
      if (mode == RouteTravelMode.transit &&
          route?.provider == RouteProvider.google) {
        warnings.add(
          '「${origin.name} → ${destination.name}」使用 Google Maps 大眾運輸備援；班次未經 TDX 即時資料驗證。',
        );
      }
      final routeStartTime = route == null
          ? null
          : schedule.firstKnownDeparture(route);
      if (routeStartTime != null && routeStartTime.isBefore(cursor)) {
        return LiveAlternativePlan.failure(
          '「${origin.name} → ${destination.name}」的候選班次已出發，請重新查詢。',
        );
      }
      final travelMinutes = atDestination
          ? 0
          : schedule.travelMinutesFromTdx(
              route: route!,
              requestedDeparture: cursor,
            );
      final departureMinute = cursor.difference(_midnight(day.date)).inMinutes;
      final arrivalMinute = departureMinute + travelMinutes;
      if (visits.isNotEmpty && departureMinute < visits.last.endMinutes) {
        return LiveAlternativePlan.failure('備案交通與前一項行程時間重疊，原行程未變更。');
      }
      final requested =
          original.requestedStartMinutes ??
          (original.locked ? original.startMinutes : null);
      if (original.locked && requested != null && arrivalMinute > requested) {
        return LiveAlternativePlan.failure(
          '無法準時抵達固定時間項目「${original.label}」（原定 ${_hm(requested)}）。',
          reorderMayHelp: true,
        );
      }
      var start = arrivalMinute;
      if (requested != null) start = max(start, requested);
      final end = start + original.stayMinutes;
      if (end > 24 * 60) {
        return LiveAlternativePlan.failure(
          '「${original.label}」將超出當天時間，需減少項目或另選日期。',
          reorderMayHelp: true,
        );
      }
      final preservingSections = index == 0 && preservedFirstSections > 0;
      final originalRoute = oldLeg?.route;
      if (preservingSections &&
          (originalRoute == null ||
              preservedFirstSections > originalRoute.sections.length)) {
        return LiveAlternativePlan.failure('無法確認已搭乘的轉乘段，原行程未變更。');
      }
      final storedRoute = preservingSections
          ? TdxRoute(
              transfers: route!.transfers,
              travelTime: max(
                route.travelTime,
                (arrivalMinute - oldLeg!.schedule.departureMinutes) * 60,
              ),
              startTime: originalRoute!.startTime,
              endTime: route.endTime,
              distanceMeters: route.distanceMeters,
              sections: [
                ...originalRoute.sections.take(preservedFirstSections),
                ...route.sections,
              ],
              provider: route.provider,
            )
          : route;
      final storedOrigin = preservingSections ? oldLeg!.origin : origin;
      final timing = ScheduledVisit(
        departureMinutes: preservingSections
            ? oldLeg!.schedule.departureMinutes
            : departureMinute,
        arrivalMinutes: arrivalMinute,
        visitStartMinutes: start,
        visitEndMinutes: end,
        waitingMinutes: start - arrivalMinute,
        stayMinutes: original.stayMinutes,
      );
      if (!atDestination) {
        legs.add(
          TravelLeg(
            origin: storedOrigin,
            destination: destination,
            requestedDeparture: preservingSections
                ? oldLeg!.requestedDeparture
                : cursor,
            schedule: timing,
            route: storedRoute,
            travelMode: mode,
          ),
        );
      }
      visits.add(
        RouteVisit(
          place: original.place,
          sequence: visits.length + 1,
          arrivalMinutes: arrivalMinute,
          startMinutes: start,
          endMinutes: end,
          waitingMinutes: start - arrivalMinute,
          stayMinutes: original.stayMinutes,
          requestedStartMinutes: original.requestedStartMinutes,
          locked: original.locked,
          eventId: original.eventId,
          kind: original.kind,
          preferences: original.preferences,
          mealType: original.mealType,
          information: original.information,
        ),
      );
      cursor = _midnight(day.date).add(Duration(minutes: end));
      origin = destination;
    }
    final candidate = RouteDay(
      day: day.day,
      date: day.date,
      origin: first == 0
          ? RouteStop(
              id: 'live-location-${now.millisecondsSinceEpoch}',
              name: '目前位置',
              latitude: startingPoint.latitude,
              longitude: startingPoint.longitude,
              stayDurationMinutes: 0,
            )
          : day.origin,
      visits: visits,
      travelLegs: legs,
      isValid: true,
      warnings: [...day.warnings, ...warnings],
    );
    if (!_hasMeaningfulChange(day, candidate)) {
      return LiveAlternativePlan.failure('重新查詢後行程與原安排相同，沒有可套用的備案。');
    }
    return LiveAlternativePlan.success(candidate, warnings);
  }

  bool _hasMeaningfulChange(RouteDay original, RouteDay candidate) {
    if (original.visits.length != candidate.visits.length ||
        original.travelLegs.length != candidate.travelLegs.length) {
      return true;
    }
    if (_distanceBetweenStops(original.origin, candidate.origin) > 0.001) {
      return true;
    }
    for (var i = 0; i < original.visits.length; i++) {
      final before = original.visits[i];
      final after = candidate.visits[i];
      if (before.occurrenceId != after.occurrenceId ||
          before.arrivalMinutes != after.arrivalMinutes ||
          before.startMinutes != after.startMinutes ||
          before.endMinutes != after.endMinutes) {
        return true;
      }
    }
    for (var i = 0; i < original.travelLegs.length; i++) {
      final before = original.travelLegs[i];
      final after = candidate.travelLegs[i];
      if (before.destination.id != after.destination.id ||
          _distanceBetweenStops(before.origin, after.origin) > 0.001 ||
          before.travelMode != after.travelMode ||
          before.schedule.departureMinutes != after.schedule.departureMinutes ||
          before.schedule.arrivalMinutes != after.schedule.arrivalMinutes ||
          before.effectiveRouteProvider != after.effectiveRouteProvider ||
          !_sameRoute(before.route, after.route)) {
        return true;
      }
    }
    return false;
  }

  bool _sameRoute(TdxRoute? before, TdxRoute? after) {
    if (before == null || after == null) return before == after;
    if (before.startTime != after.startTime ||
        before.endTime != after.endTime ||
        before.travelTime != after.travelTime ||
        before.transfers != after.transfers ||
        before.sections.length != after.sections.length) {
      return false;
    }
    for (var i = 0; i < before.sections.length; i++) {
      final oldSection = before.sections[i];
      final newSection = after.sections[i];
      if (oldSection.mode != newSection.mode ||
          oldSection.lineName != newSection.lineName ||
          oldSection.serviceId != newSection.serviceId ||
          oldSection.routeId != newSection.routeId ||
          oldSection.departureStopId != newSection.departureStopId ||
          oldSection.arrivalStopId != newSection.arrivalStopId ||
          oldSection.scheduledDeparture != newSection.scheduledDeparture ||
          oldSection.scheduledArrival != newSection.scheduledArrival) {
        return false;
      }
    }
    return true;
  }

  List<RouteVisit> _orderRemaining(
    List<RouteVisit> visits,
    LocationPoint current,
  ) {
    final pending = [...visits];
    final result = <RouteVisit>[];
    var latitude = current.latitude;
    var longitude = current.longitude;
    while (pending.isNotEmpty) {
      // Keep fixed-time visits in their original relative order. Among other
      // visits, a nearby one may be attempted first; actual routes are then
      // checked by plan(), not inferred from this distance.
      final lockedIndex = pending.indexWhere((visit) => visit.locked);
      final flexible = lockedIndex < 0
          ? pending
          : pending.take(lockedIndex + 1).toList();
      flexible.sort(
        (a, b) => _distance(
          latitude,
          longitude,
          a,
        ).compareTo(_distance(latitude, longitude, b)),
      );
      final next = flexible.first;
      pending.remove(next);
      result.add(next);
      latitude = next.place.latitude;
      longitude = next.place.longitude;
    }
    return result;
  }

  double _distance(double lat, double lng, RouteVisit visit) {
    final x = (lat - visit.place.latitude) * 111;
    final y = (lng - visit.place.longitude) * 101;
    return x * x + y * y;
  }

  double _distanceBetweenStops(RouteStop a, RouteStop b) {
    final x = (a.latitude - b.latitude) * 111;
    final y = (a.longitude - b.longitude) * 101;
    return sqrt(x * x + y * y);
  }

  RouteStop _stop(RouteVisit visit) => RouteStop(
    id: visit.occurrenceId,
    name: visit.label,
    latitude: visit.place.latitude,
    longitude: visit.place.longitude,
    stayDurationMinutes: visit.stayMinutes,
  );

  DateTime _midnight(DateTime date) =>
      DateTime(date.year, date.month, date.day);
  String _hm(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
}
