import 'dart:math';

import '../../../algorithm/route_optimizer.dart';
import '../../../models/scheduled_visit.dart';
import '../../../models/trip_request.dart';
import '../../../models/tdx_route.dart';
import '../../../services/itinerary_schedule_service.dart';
import '../../../services/timed_tdx_route_service.dart';
import '../models/route_day.dart';
import '../models/route_itinerary.dart';
import '../models/route_place_input.dart';
import '../models/route_visit.dart';
import '../models/travel_leg.dart';

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

  ItineraryPlanningService({
    RouteOptimizer? optimizer,
    TimedTdxRouteService? timedRouteService,
    this._scheduleService = const ItineraryScheduleService(),
    this.origin = taipeiMainStation,
    this.dayStartMinutes = 9 * 60,
    this.requestInterval = const Duration(seconds: 2),
  }) : _optimizer = optimizer ?? RouteOptimizer(),
       _timedRouteService = timedRouteService ?? TimedTdxRouteService();

  Future<RouteItinerary> generate({
    required TripRequest request,
    required List<RoutePlaceInput> places,
    void Function(String message)? onProgress,
  }) async {
    final warnings = <String>[];
    final dayConstraints = _assignConstraintsToDays(
      request: request,
      places: places,
      warnings: warnings,
    );
    final days = <RouteDay>[];

    for (var dayIndex = 0; dayIndex < request.days; dayIndex++) {
      final dayNumber = dayIndex + 1;
      onProgress?.call('正在安排 Day $dayNumber…');
      final date = DateTime(
        request.startDate.year,
        request.startDate.month,
        request.startDate.day + dayIndex,
      );
      days.add(
        await _generateDay(
          day: dayNumber,
          date: date,
          constraints: dayConstraints[dayIndex],
          onProgress: onProgress,
        ),
      );
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

    for (final constraint in unassigned) {
      final target = buckets.reduce(
        (first, second) => _totalStayMinutes(first) <= _totalStayMinutes(second)
            ? first
            : second,
      );
      target.add(constraint);
    }

    return buckets;
  }

  Future<RouteDay> _generateDay({
    required int day,
    required DateTime date,
    required List<RoutePlaceInput> constraints,
    void Function(String message)? onProgress,
  }) async {
    if (constraints.isEmpty) {
      return RouteDay(
        day: day,
        date: date,
        origin: origin,
        visits: const [],
        travelLegs: const [],
        isValid: true,
      );
    }

    final constraintsById = {
      for (final constraint in constraints) constraint.place.id: constraint,
    };
    final stops = constraints.map(_toRouteStop).toList();
    final orderedStops = _orderStops(stops);
    final visits = <RouteVisit>[];
    final travelLegs = <TravelLeg>[];
    final warnings = <String>[];
    var previousStop = origin;
    final minimumDepartureMinutes = _getDayStartMinutes(date);
    var departureMinutes = minimumDepartureMinutes;

    for (var index = 0; index < orderedStops.length; index++) {
      final destination = orderedStops[index];
      final constraint = constraintsById[destination.id]!;
      departureMinutes = max(
        minimumDepartureMinutes,
        _plannedDepartureMinutes(
          availableDepartureMinutes: departureMinutes,
          previousStop: previousStop,
          destination: destination,
          isFirstStop: index == 0,
        ),
      );
      onProgress?.call(
        '正在查詢 Day $day 第 ${index + 1}/${orderedStops.length} 段交通…',
      );
      late DateTime requestedDeparture;
      late ScheduledVisit schedule;
      TdxRoute? route;
      String? errorMessage;
      var routeAdjustmentCount = 0;

      while (true) {
        requestedDeparture = date.add(Duration(minutes: departureMinutes));
        route = null;
        errorMessage = null;

        try {
          route = await _timedRouteService.getRouteAtOrAfter(
            origin: '${previousStop.latitude},${previousStop.longitude}',
            destination: '${destination.latitude},${destination.longitude}',
            requestedDeparture: requestedDeparture,
          );
          if (route == null) {
            errorMessage = 'TDX 沒有提供指定時間後的可用路線，已使用估計時間。';
          }
        } catch (error) {
          errorMessage = 'TDX 路線查詢失敗，已使用估計時間：$error';
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
            index == 0 &&
            fixedStart != null &&
            schedule.visitStartMinutes > fixedStart &&
            routeAdjustmentCount < 2;
        final shouldRetryLater =
            schedule.waitingMinutes > 15 && routeAdjustmentCount < 2;

        if (shouldRetryEarlier) {
          final latenessMinutes = schedule.visitStartMinutes - fixedStart;
          departureMinutes = max(
            minimumDepartureMinutes,
            departureMinutes - latenessMinutes - 5,
          );
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
      origin: origin,
      visits: visits,
      travelLegs: travelLegs,
      isValid: warnings.isEmpty,
      warnings: warnings,
    );
  }

  // 計算當天的起始時間（分鐘），如果是今天且已經超過預設開始時間，則改成目前時間加一分鐘
  int _getDayStartMinutes(DateTime date) {
    final now = DateTime.now();

    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    // 不是今天，不論是過去或未來，都從預設時間開始
    if (!isToday) {
      return dayStartMinutes;
    }

    final plannedStart = DateTime(
      date.year,
      date.month,
      date.day,
    ).add(Duration(minutes: dayStartMinutes));

    // 今天但還沒超過預設開始時間
    if (!now.isAfter(plannedStart)) {
      return dayStartMinutes;
    }

    // 今天已超過 09:00，改成目前時間加一分鐘
    return now.hour * 60 + now.minute + 1;
  }

  //演算法入口
  List<RouteStop> _orderStops(List<RouteStop> stops) {
    if (stops.length == 1) return List.of(stops);
    if (stops.length > 8) return _nearestNeighborOrder(stops);

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
        .map((stop) => _estimatedTravelMinutes(origin, stop).toDouble())
        .toList();
    return _optimizer
        .optimizeRoute(
          stopsToVisit: stops,
          durationMatrix: matrix,
          startTimeMinutes: _optimizationStartMinutes(stops),
          travelTimesFromStart: travelTimesFromOrigin,
        )
        .sortedStops;
  }

  int _optimizationStartMinutes(List<RouteStop> stops) {
    var startMinutes = dayStartMinutes;
    for (final stop in stops) {
      final fixedStart = stop.earliestTimeMinutes == stop.latestTimeMinutes
          ? stop.earliestTimeMinutes
          : null;
      if (fixedStart == null) continue;
      startMinutes = min(
        startMinutes,
        fixedStart - _estimatedTravelMinutes(origin, stop) - 5,
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

  List<RouteStop> _nearestNeighborOrder(List<RouteStop> stops) {
    final remaining = List<RouteStop>.of(stops);
    final ordered = <RouteStop>[];
    var current = origin;
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
    return max(1, (8 + distance / 18 * 60).ceil());
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
