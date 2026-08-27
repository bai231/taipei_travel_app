import 'dart:math';

import '../../../algorithm/route_optimizer.dart';
import '../../../models/place.dart';
import '../../../models/scheduled_visit.dart';
import '../../../models/trip_request.dart';
import '../../../models/tdx_route.dart';
import '../../../services/itinerary_schedule_service.dart';
import '../../../services/tdx_service.dart';
import '../../../services/timed_tdx_route_service.dart';
import '../models/route_day.dart';
import '../models/route_itinerary.dart';
import '../models/route_place_input.dart';
import '../models/route_visit.dart';
import '../models/travel_leg.dart';

class ItineraryPlanningControl {
  bool _useEstimatesForRemainingRoutes = false;

  bool get useEstimatesForRemainingRoutes => _useEstimatesForRemainingRoutes;

  void useEstimates() {
    _useEstimatesForRemainingRoutes = true;
  }
}

class _RateLimitRetryBudget {
  int remainingWaits;

  _RateLimitRetryBudget(this.remainingWaits);
}

class ItineraryPlanningService {
  static const taipeiMainStation = RouteStop(
    id: 'taipei-main-station',
    name: '台北車站',
    latitude: 25.0478,
    longitude: 121.5170,
    stayDurationMinutes: 0,
  );

  final RouteOptimizer _optimizer;
  final TimedTdxRouteService _timedRouteService;
  final ItineraryScheduleService _scheduleService;
  final RouteStop origin;
  final int dayStartMinutes;
  final Duration requestInterval;
  final DateTime Function() _now;
  final Future<void> Function(Duration duration) _delay;
  final int maximumRateLimitWaits;

  ItineraryPlanningService({
    RouteOptimizer? optimizer,
    TimedTdxRouteService? timedRouteService,
    this._scheduleService = const ItineraryScheduleService(),
    this.origin = taipeiMainStation,
    this.dayStartMinutes = 9 * 60,
    this.requestInterval = const Duration(seconds: 2),
    this.maximumRateLimitWaits = 2,
    DateTime Function()? now,
    Future<void> Function(Duration duration)? delay,
  }) : _optimizer = optimizer ?? RouteOptimizer(),
       _timedRouteService = timedRouteService ?? TimedTdxRouteService(),
       _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed;

  Future<RouteItinerary> generate({
    required TripRequest request,
    required List<RoutePlaceInput> places,
    void Function(String message)? onProgress,
    void Function(Duration? remaining)? onRateLimitWait,
    ItineraryPlanningControl? control,
  }) async {
    final activeControl = control ?? ItineraryPlanningControl();
    final retryBudget = _RateLimitRetryBudget(maximumRateLimitWaits);
    final now = _now();

    final tripStartDate = DateTime(
      request.startDate.year,
      request.startDate.month,
      request.startDate.day,
    );

    final today = DateTime(now.year, now.month, now.day);

    // 過去日期目前仍不允許查詢。
    // 今天即使已超過 09:00，也會在後面改成現在時間加一分鐘。
    if (tripStartDate.isBefore(today)) {
      throw StateError('TDX 不支援查詢已經過去的日期，請重新選擇今天或未來日期。');
    }

    final warnings = <String>[];
    final dayConstraints = _assignConstraintsToDays(
      request: request,
      places: places,
      warnings: warnings,
    );
    final days = <RouteDay>[];
    var dayOrigin = origin;

    for (var dayIndex = 0; dayIndex < request.days; dayIndex++) {
      final dayNumber = dayIndex + 1;
      onProgress?.call('正在安排 Day $dayNumber…');
      final date = DateTime(
        request.startDate.year,
        request.startDate.month,
        request.startDate.day + dayIndex,
      );

      final initialDepartureMinutes = _initialDepartureMinutesForDate(
        date: date,
        now: now,
      );
      final routeDay = await _generateDay(
        day: dayNumber,
        date: date,
        dayOrigin: dayOrigin,
        initialDepartureMinutes: initialDepartureMinutes,
        constraints: dayConstraints[dayIndex],
        onProgress: onProgress,
        onRateLimitWait: onRateLimitWait,
        control: activeControl,
        retryBudget: retryBudget,
      );
      days.add(routeDay);
      if (routeDay.visits.isNotEmpty) {
        dayOrigin = _nextDayOrigin(routeDay.visits.last.place);
      }
    }

    onProgress?.call('行程安排完成');

    return RouteItinerary(
      request: request,
      origin: origin,
      days: days,
      generatedAt: DateTime.now(),
      warnings: warnings,
    );
  }

  int _initialDepartureMinutesForDate({
    required DateTime date,
    required DateTime now,
  }) {
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    // 不是今天，維持預設 09:00。
    if (!isToday) {
      return dayStartMinutes;
    }

    final defaultDeparture = DateTime(
      date.year,
      date.month,
      date.day,
    ).add(Duration(minutes: dayStartMinutes));

    // 今天尚未超過 09:00，維持預設時間。
    if (!now.isAfter(defaultDeparture)) {
      return dayStartMinutes;
    }

    // 今天已超過 09:00，改成現在時間加一分鐘。
    final adjustedDeparture = now.add(const Duration(minutes: 1));

    return adjustedDeparture.hour * 60 + adjustedDeparture.minute;
  }

  List<List<RoutePlaceInput>> _assignConstraintsToDays({
    required TripRequest request,
    required List<RoutePlaceInput> places,
    required List<String> warnings,
  }) {
    final buckets = List.generate(request.days, (_) => <RoutePlaceInput>[]);
    final assignedPlaceIds = <String>{};
    final unassigned = <RoutePlaceInput>[];

    for (final constraint in places) {
      if (!assignedPlaceIds.add(constraint.place.id)) {
        warnings.add('${constraint.place.name} 重複出現，已只保留一次。');
        continue;
      }
      final selectedDay = constraint.day;
      if (selectedDay == null) {
        unassigned.add(constraint);
      } else if (selectedDay < 1 || selectedDay > request.days) {
        warnings.add(
          '${constraint.place.name} 指定的 Day $selectedDay 超出旅程範圍，已改為自動安排。',
        );
        unassigned.add(constraint);
      } else {
        buckets[selectedDay - 1].add(constraint);
      }
    }

    final orderedUnassigned = _orderInputsByDistance(unassigned);
    final geographicGroups = _splitByGeography(orderedUnassigned, request.days);
    _mergeGeographicGroups(buckets, geographicGroups);

    return buckets;
  }

  Future<RouteDay> _generateDay({
    required int day,
    required DateTime date,
    required RouteStop dayOrigin,
    required int initialDepartureMinutes,
    required List<RoutePlaceInput> constraints,
    void Function(String message)? onProgress,
    void Function(Duration? remaining)? onRateLimitWait,
    required ItineraryPlanningControl control,
    required _RateLimitRetryBudget retryBudget,
  }) async {
    if (constraints.isEmpty) {
      return RouteDay(
        day: day,
        date: date,
        origin: dayOrigin,
        visits: const [],
        travelLegs: const [],
        isValid: true,
      );
    }

    final constraintsById = {
      for (final constraint in constraints) constraint.place.id: constraint,
    };
    final stops = constraints.map(_toRouteStop).toList();
    final orderedStops = _orderStops(stops, dayOrigin);
    final visits = <RouteVisit>[];
    final travelLegs = <TravelLeg>[];
    final warnings = <String>[];
    var previousStop = dayOrigin;
    var departureMinutes = initialDepartureMinutes;

    for (var index = 0; index < orderedStops.length; index++) {
      final destination = orderedStops[index];
      final constraint = constraintsById[destination.id]!;
      departureMinutes = _plannedDepartureMinutes(
        availableDepartureMinutes: departureMinutes,
        previousStop: previousStop,
        destination: destination,
        isFirstStop: index == 0,
      );
      onProgress?.call(
        '正在查詢 Day $day 第 ${index + 1}/${orderedStops.length} 段交通…',
      );
      late DateTime requestedDeparture;
      late ScheduledVisit schedule;
      TdxRoute? route;
      String? errorMessage;
      var routeAdjustmentCount = 0;
      var rateLimitRetriesForLeg = 0;

      while (true) {
        requestedDeparture = date.add(Duration(minutes: departureMinutes));
        route = null;
        errorMessage = null;

        if (control.useEstimatesForRemainingRoutes) {
          errorMessage = '已取消等待，後續路段使用估計時間。';
        } else {
          while (true) {
            try {
              route = await _timedRouteService.getRouteAtOrAfter(
                origin: '${previousStop.latitude},${previousStop.longitude}',
                destination: '${destination.latitude},${destination.longitude}',
                requestedDeparture: requestedDeparture,
              );
              if (route == null) {
                errorMessage = 'TDX 沒有提供指定時間後的可用路線，已使用估計時間。';
              }
              break;
            } on TdxRateLimitException catch (error) {
              final canRetry =
                  rateLimitRetriesForLeg < 1 && retryBudget.remainingWaits > 0;
              if (!canRetry) {
                errorMessage = 'TDX 仍在查詢冷卻中，已使用估計時間。';
                break;
              }

              rateLimitRetriesForLeg++;
              retryBudget.remainingWaits--;
              final shouldContinue = await _waitForRateLimit(
                retryAfter: error.retryAfter,
                control: control,
                onProgress: onProgress,
                onRateLimitWait: onRateLimitWait,
              );
              if (!shouldContinue) {
                errorMessage = '已取消等待，後續路段使用估計時間。';
                break;
              }
              onProgress?.call('TDX 冷卻結束，正在重新查詢目前路段…');
            } catch (error) {
              errorMessage = 'TDX 路線查詢失敗，已使用估計時間：$error';
              break;
            }
          }
        }

        final travelMinutes = route == null
            ? _estimatedTravelMinutes(previousStop, destination)
            : _scheduleService.travelMinutesFromTdx(
                route: route,
                requestedDeparture: requestedDeparture,
              );
        schedule = _scheduleService.scheduleVisit(
          departureMinutes: departureMinutes,
          travelMinutes: travelMinutes,
          destination: destination,
        );

        final fixedStart = constraint.locked ? constraint.startMinutes : null;
        final shouldRetryEarlier =
            route != null &&
            index == 0 &&
            fixedStart != null &&
            schedule.visitStartMinutes > fixedStart &&
            routeAdjustmentCount < 2;
        final shouldRetryLater =
            route != null &&
            schedule.waitingMinutes > 15 &&
            routeAdjustmentCount < 2;

        if (shouldRetryEarlier) {
          final latenessMinutes = schedule.visitStartMinutes - fixedStart;
          departureMinutes = max(0, departureMinutes - latenessMinutes - 5);
          onProgress?.call('首站可能遲到，正在重新查詢更早的 TDX 班次…');
        } else if (shouldRetryLater) {
          departureMinutes += schedule.waitingMinutes - 5;
          onProgress?.call('抵達時間過早，正在重新查詢較晚的 TDX 班次…');
        } else {
          break;
        }

        routeAdjustmentCount++;
        if (requestInterval > Duration.zero) {
          await Future<void>.delayed(requestInterval);
        }
      }

      if (constraint.locked &&
          constraint.startMinutes != null &&
          schedule.visitStartMinutes > constraint.startMinutes!) {
        warnings.add(
          '${constraint.place.name} 預計 ${_formatMinutes(schedule.visitStartMinutes)} 抵達，晚於指定時間 ${_formatMinutes(constraint.startMinutes!)}。',
        );
      }
      final fixedTimeOutsideOpeningHours =
          constraint.locked &&
          constraint.startMinutes != null &&
          (constraint.startMinutes! < constraint.place.openMinutes ||
              constraint.startMinutes! + constraint.place.stayTime >
                  constraint.place.closeMinutes);
      if (fixedTimeOutsideOpeningHours) {
        warnings.add('${constraint.place.name} 的指定時間不在景點營業時間內。');
      } else if (schedule.visitEndMinutes > constraint.place.closeMinutes) {
        warnings.add('${constraint.place.name} 的停留時間超過景點營業時間。');
      }

      travelLegs.add(
        TravelLeg(
          origin: previousStop,
          destination: destination,
          requestedDeparture: requestedDeparture,
          schedule: schedule,
          route: route,
          errorMessage: errorMessage,
        ),
      );
      visits.add(
        RouteVisit(
          place: constraint.place,
          sequence: index + 1,
          arrivalMinutes: schedule.arrivalMinutes,
          startMinutes: schedule.visitStartMinutes,
          endMinutes: schedule.visitEndMinutes,
          waitingMinutes: schedule.waitingMinutes,
          stayMinutes: schedule.stayMinutes,
          requestedStartMinutes: constraint.startMinutes,
          locked: constraint.locked,
        ),
      );

      departureMinutes = schedule.visitEndMinutes;
      previousStop = destination;
      if (index < orderedStops.length - 1 && requestInterval > Duration.zero) {
        await Future<void>.delayed(requestInterval);
      }
    }

    return RouteDay(
      day: day,
      date: date,
      origin: dayOrigin,
      visits: visits,
      travelLegs: travelLegs,
      isValid: warnings.isEmpty,
      warnings: warnings,
    );
  }

  Future<bool> _waitForRateLimit({
    required Duration retryAfter,
    required ItineraryPlanningControl control,
    void Function(String message)? onProgress,
    void Function(Duration? remaining)? onRateLimitWait,
  }) async {
    final totalSeconds = max(1, retryAfter.inSeconds);
    try {
      for (
        var remainingSeconds = totalSeconds;
        remainingSeconds > 0;
        remainingSeconds--
      ) {
        if (control.useEstimatesForRemainingRoutes) return false;
        final remaining = Duration(seconds: remainingSeconds);
        onRateLimitWait?.call(remaining);
        onProgress?.call('TDX 冷卻中，$remainingSeconds 秒後自動繼續…');
        await _delay(const Duration(seconds: 1));
      }
      return !control.useEstimatesForRemainingRoutes;
    } finally {
      onRateLimitWait?.call(null);
    }
  }

  List<RouteStop> _orderStops(List<RouteStop> stops, RouteStop routeOrigin) {
    if (stops.length == 1) return List.of(stops);
    if (stops.length > 8) {
      return _nearestNeighborOrder(stops, routeOrigin);
    }

    final matrix = List.generate(
      stops.length,
      (originIndex) => List.generate(
        stops.length,
        (destinationIndex) => originIndex == destinationIndex
            ? 0.0
            : _estimatedTravelMinutes(
                stops[originIndex],
                stops[destinationIndex],
              ).toDouble(),
      ),
    );
    final travelTimesFromOrigin = stops
        .map((stop) => _estimatedTravelMinutes(routeOrigin, stop).toDouble())
        .toList();
    return _optimizer
        .optimizeRoute(
          stopsToVisit: stops,
          durationMatrix: matrix,
          startTimeMinutes: _optimizationStartMinutes(stops, routeOrigin),
          travelTimesFromStart: travelTimesFromOrigin,
        )
        .sortedStops;
  }

  int _optimizationStartMinutes(List<RouteStop> stops, RouteStop routeOrigin) {
    var startMinutes = dayStartMinutes;
    for (final stop in stops) {
      final fixedStart = stop.earliestTimeMinutes == stop.latestTimeMinutes
          ? stop.earliestTimeMinutes
          : null;
      if (fixedStart == null) continue;
      startMinutes = min(
        startMinutes,
        fixedStart - _estimatedTravelMinutes(routeOrigin, stop) - 5,
      );
    }
    return max(0, startMinutes);
  }

  int _plannedDepartureMinutes({
    required int availableDepartureMinutes,
    required RouteStop previousStop,
    required RouteStop destination,
    required bool isFirstStop,
  }) {
    final earliestStart = destination.earliestTimeMinutes;
    if (earliestStart == null) return availableDepartureMinutes;
    final desiredDeparture = max(
      0,
      earliestStart - _estimatedTravelMinutes(previousStop, destination) - 5,
    );
    if (isFirstStop && earliestStart == destination.latestTimeMinutes) {
      return min(availableDepartureMinutes, desiredDeparture);
    }
    return max(availableDepartureMinutes, desiredDeparture);
  }

  List<RouteStop> _nearestNeighborOrder(
    List<RouteStop> stops,
    RouteStop routeOrigin,
  ) {
    final remaining = List<RouteStop>.of(stops);
    final ordered = <RouteStop>[];
    var current = routeOrigin;
    while (remaining.isNotEmpty) {
      remaining.sort(
        (first, second) => _estimatedTravelMinutes(
          current,
          first,
        ).compareTo(_estimatedTravelMinutes(current, second)),
      );
      current = remaining.removeAt(0);
      ordered.add(current);
    }
    return ordered;
  }

  List<RoutePlaceInput> _orderInputsByDistance(List<RoutePlaceInput> inputs) {
    final remaining = List<RoutePlaceInput>.of(inputs);
    final ordered = <RoutePlaceInput>[];
    var current = origin;
    while (remaining.isNotEmpty) {
      remaining.sort((first, second) {
        final firstStop = _toRouteStop(first);
        final secondStop = _toRouteStop(second);
        return _estimatedTravelMinutes(
          current,
          firstStop,
        ).compareTo(_estimatedTravelMinutes(current, secondStop));
      });
      final next = remaining.removeAt(0);
      ordered.add(next);
      current = _toRouteStop(next);
    }
    return ordered;
  }

  List<List<RoutePlaceInput>> _splitByGeography(
    List<RoutePlaceInput> orderedInputs,
    int dayCount,
  ) {
    final groups = List.generate(dayCount, (_) => <RoutePlaceInput>[]);
    if (orderedInputs.isEmpty || dayCount == 0) return groups;
    if (dayCount == 1) {
      groups.first.addAll(orderedInputs);
      return groups;
    }

    final splitCount = min(dayCount - 1, orderedInputs.length - 1);
    final boundaries = <int>{};
    final gaps = <({int boundary, double distance})>[];
    for (var index = 1; index < orderedInputs.length; index++) {
      final previous = orderedInputs[index - 1].place;
      final current = orderedInputs[index].place;
      gaps.add((
        boundary: index,
        distance: _distanceInKilometers(
          previous.latitude,
          previous.longitude,
          current.latitude,
          current.longitude,
        ),
      ));
    }

    gaps.sort((first, second) => second.distance.compareTo(first.distance));
    for (final gap in gaps) {
      if (boundaries.length >= splitCount || gap.distance < 40) break;
      boundaries.add(gap.boundary);
    }

    for (var part = 1; boundaries.length < splitCount; part++) {
      final idealBoundary = (orderedInputs.length * part / dayCount).round();
      final candidates = List.generate(
        orderedInputs.length - 1,
        (index) => index + 1,
      ).where((boundary) => !boundaries.contains(boundary)).toList();
      if (candidates.isEmpty) break;
      candidates.sort((first, second) {
        final firstDistance = (first - idealBoundary).abs();
        final secondDistance = (second - idealBoundary).abs();
        return firstDistance.compareTo(secondDistance);
      });
      boundaries.add(candidates.first);
    }

    final orderedBoundaries = boundaries.toList()..sort();
    var start = 0;
    for (var groupIndex = 0; groupIndex < dayCount; groupIndex++) {
      final end = groupIndex < orderedBoundaries.length
          ? orderedBoundaries[groupIndex]
          : orderedInputs.length;
      if (start < end) {
        groups[groupIndex].addAll(orderedInputs.sublist(start, end));
      }
      start = end;
    }
    return groups;
  }

  void _mergeGeographicGroups(
    List<List<RoutePlaceInput>> buckets,
    List<List<RoutePlaceInput>> geographicGroups,
  ) {
    final groups = geographicGroups.where((group) => group.isNotEmpty).toList();
    var firstAvailableDay = 0;
    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final remainingGroups = groups.length - groupIndex;
      final lastAvailableDay = buckets.length - remainingGroups;
      var targetDay = firstAvailableDay;
      for (
        var dayIndex = firstAvailableDay + 1;
        dayIndex <= lastAvailableDay;
        dayIndex++
      ) {
        if (_totalStayMinutes(buckets[dayIndex]) <
            _totalStayMinutes(buckets[targetDay])) {
          targetDay = dayIndex;
        }
      }
      buckets[targetDay].addAll(groups[groupIndex]);
      firstAvailableDay = targetDay + 1;
    }
  }

  RouteStop _nextDayOrigin(Place place) {
    return RouteStop(
      id: place.id,
      name: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
      stayDurationMinutes: 0,
    );
  }

  RouteStop _toRouteStop(RoutePlaceInput constraint) {
    final place = constraint.place;
    final requestedStart = constraint.locked ? constraint.startMinutes : null;
    return RouteStop(
      id: place.id,
      name: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
      stayDurationMinutes: place.stayTime,
      earliestTimeMinutes: requestedStart ?? place.openMinutes,
      latestTimeMinutes: requestedStart ?? place.closeMinutes,
    );
  }

  int _estimatedTravelMinutes(RouteStop from, RouteStop to) {
    final distance = _distanceInKilometers(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    if (distance <= 20) {
      return max(1, (8 + distance / 18 * 60).ceil());
    }
    if (distance <= 80) {
      return max(1, (20 + distance / 35 * 60).ceil());
    }
    return max(1, (45 + distance / 90 * 60).ceil());
  }

  double _distanceInKilometers(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const radiansPerDegree = pi / 180;
    final latitudeDifference = (endLatitude - startLatitude) * radiansPerDegree;
    final longitudeDifference =
        (endLongitude - startLongitude) * radiansPerDegree;
    final startLatitudeRadians = startLatitude * radiansPerDegree;
    final endLatitudeRadians = endLatitude * radiansPerDegree;
    final value =
        sin(latitudeDifference / 2) * sin(latitudeDifference / 2) +
        cos(startLatitudeRadians) *
            cos(endLatitudeRadians) *
            sin(longitudeDifference / 2) *
            sin(longitudeDifference / 2);
    return 6371 * 2 * atan2(sqrt(value), sqrt(1 - value));
  }

  int _totalStayMinutes(List<RoutePlaceInput> constraints) {
    return constraints.fold(
      0,
      (total, constraint) => total + constraint.place.stayTime,
    );
  }

  String _formatMinutes(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }
}
