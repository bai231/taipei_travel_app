import 'dart:math';

import '../../../algorithm/route_optimizer.dart';
import '../../../models/place.dart';
import '../../../models/scheduled_visit.dart';
import '../../../models/trip_request.dart';
import '../../../models/tdx_route.dart';
import '../../../models/visit_preferences.dart';
import '../../../services/place_service.dart';
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
  final RouteOptimizer _optimizer;
  final TimedTdxRouteService _timedRouteService;
  final ItineraryScheduleService _scheduleService;
  final RouteStop? origin;
  final int dayStartMinutes;
  final Duration requestInterval;
  final DateTime Function() _now;
  final Future<void> Function(Duration duration) _delay;
  final int maximumRateLimitWaits;

  static const double _crossCountyHotelPenaltyMinutes = 10000;

  ItineraryPlanningService({
    RouteOptimizer? optimizer,
    TimedTdxRouteService? timedRouteService,
    this._scheduleService = const ItineraryScheduleService(),
    this.origin,
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
    if (places.isEmpty) {
      throw StateError('行程中至少需要一個景點。');
    }
    final normalizedPlaces = _withDefaultHotelStays(request, places);
    _validateInputs(request, normalizedPlaces);

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
      places: normalizedPlaces,
      warnings: warnings,
    );
    final days = <RouteDay>[];
    final fallbackOrigin = _toRouteStop(normalizedPlaces.first);
    var dayOrigin = origin;
    var earliestNextDayMinutes = 0;

    for (var dayIndex = 0; dayIndex < request.days; dayIndex++) {
      final dayNumber = dayIndex + 1;
      onProgress?.call('正在安排 Day $dayNumber…');
      final date = DateTime(
        request.startDate.year,
        request.startDate.month,
        request.startDate.day + dayIndex,
      );

      final preferredDepartureMinutes = _mealAwareDepartureMinutes(
        defaultDepartureMinutes: _initialDepartureMinutesForDate(
          date: date,
          now: now,
          constraints: dayConstraints[dayIndex],
        ),
        dayOrigin: dayOrigin,
        constraints: dayConstraints[dayIndex],
      );
      final isToday =
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
      final departureFloor = max(
        earliestNextDayMinutes,
        isToday ? now.hour * 60 + now.minute + 1 : 0,
      );
      final initialDepartureMinutes = max(
        departureFloor,
        preferredDepartureMinutes,
      );
      final routeDay = await _generateDay(
        day: dayNumber,
        date: date,
        dayOrigin: dayOrigin,
        fallbackOrigin: fallbackOrigin,
        initialDepartureMinutes: initialDepartureMinutes,
        departureFloor: departureFloor,
        constraints: dayConstraints[dayIndex],
        onProgress: onProgress,
        onRateLimitWait: onRateLimitWait,
        control: activeControl,
        retryBudget: retryBudget,
      );
      days.add(routeDay);
      if (routeDay.visits.isNotEmpty) {
        dayOrigin = _nextDayOrigin(routeDay.visits.last.place);
        earliestNextDayMinutes = max(0, routeDay.visits.last.endMinutes - 1440);
      } else {
        earliestNextDayMinutes = max(0, earliestNextDayMinutes - 1440);
      }
      warnings.addAll(
        routeDay.warnings.map((warning) => 'Day $dayNumber：$warning'),
      );
      if (dayNumber < request.days &&
          !dayConstraints[dayIndex].any(
            (input) => input.kind == VisitKind.hotelStay,
          )) {
        warnings.add('Day $dayNumber 尚未設定住宿；隔日暫從最後位置出發。');
      }
    }

    onProgress?.call('行程安排完成');

    final itineraryOrigin =
        origin ??
        days
            .firstWhere(
              (day) => day.visits.isNotEmpty,
              orElse: () => days.first,
            )
            .origin;

    return RouteItinerary(
      request: request,
      origin: itineraryOrigin,
      days: days,
      generatedAt: DateTime.now(),
      warnings: warnings,
      inputs: normalizedPlaces,
    );
  }

  List<RoutePlaceInput> _withDefaultHotelStays(
    TripRequest request,
    List<RoutePlaceInput> places,
  ) {
    final unconfigured = places
        .where(
          (input) =>
              input.place.type == PlaceType.accommodation &&
              input.preferences.hotelStay == null,
        )
        .toList();
    if (unconfigured.isEmpty) return List.of(places);

    final configuredNights = <int>{};
    for (final input in places) {
      final stay = input.preferences.hotelStay;
      if (stay == null) continue;
      for (var night = stay.checkInDay; night < stay.checkOutDay; night++) {
        configuredNights.add(night);
      }
    }
    final defaults = <String, HotelStay>{};
    final automaticNights = request.days <= 1 ? 1 : request.days - 1;
    if (configuredNights.isEmpty) {
      if (unconfigured.length > automaticNights) {
        throw StateError('住宿數量多於旅程夜數，請移除住宿或手動調整日期。');
      }
      final orderedHotels = _orderInputsByDistance(unconfigured);
      for (var index = 0; index < orderedHotels.length; index++) {
        final input = orderedHotels[index];
        final checkInDay =
            input.day ?? (index * automaticNights ~/ orderedHotels.length + 1);
        final checkOutDay = input.day == null
            ? (index + 1) * automaticNights ~/ orderedHotels.length + 1
            : checkInDay + 1;
        defaults[input.place.id] = HotelStay(
          checkInDay: checkInDay,
          checkOutDay: checkOutDay,
        );
      }
    } else {
      final availableNights = [
        for (var night = 1; night <= automaticNights; night++)
          if (!configuredNights.contains(night)) night,
      ];
      final manuallyDated = unconfigured
          .where((input) => input.day != null)
          .toList();
      final automaticallyDated = unconfigured
          .where((input) => input.day == null)
          .toList();
      final occupiedManualNights = manuallyDated
          .map((input) => input.day!)
          .toSet();
      final usableNights = availableNights
          .where((night) => !occupiedManualNights.contains(night))
          .toList();
      if (usableNights.length < automaticallyDated.length) {
        throw StateError('沒有足夠的未安排夜晚可放入住宿，請手動調整住宿日期。');
      }
      for (final input in manuallyDated) {
        defaults[input.place.id] = HotelStay(
          checkInDay: input.day!,
          checkOutDay: input.day! + 1,
        );
      }
      final orderedHotels = _orderInputsByDistance(automaticallyDated);
      for (var index = 0; index < orderedHotels.length; index++) {
        final night = usableNights[index];
        defaults[orderedHotels[index].place.id] = HotelStay(
          checkInDay: night,
          checkOutDay: night + 1,
        );
      }
    }

    return places.map((input) {
      final stay = defaults[input.place.id];
      if (stay == null) return input;
      final preferences = input.preferences;
      return RoutePlaceInput(
        place: input.place,
        day: input.day,
        startMinutes: input.startMinutes,
        locked: input.locked,
        kind: input.kind,
        suggestedMealType: input.suggestedMealType,
        preferences: VisitPreferences(
          mealType: preferences.mealType,
          durationMinutes: preferences.durationMinutes,
          mealWindowStart: preferences.mealWindowStart,
          mealWindowEnd: preferences.mealWindowEnd,
          hotelStay: stay,
        ),
      );
    }).toList();
  }

  void _validateInputs(TripRequest request, List<RoutePlaceInput> places) {
    if (request.days < 1) throw StateError('旅程結束日不可早於開始日。');
    final nights = <int, String>{};
    final bookings = <String>{};
    for (final input in places) {
      if (!PlaceService.hasUsableCoordinates(input.place)) {
        throw StateError('${input.place.name} 缺少有效座標，無法查詢交通。');
      }
      final error = input.preferences.validationError(
        input.place,
        request.days,
      );
      if (error != null) throw StateError(error);
      if (input.startMinutes != null &&
          (input.startMinutes! < 0 || input.startMinutes! >= 1440)) {
        throw StateError('${input.place.name} 指定時間必須介於 00:00 至 23:59。');
      }
      if (input.locked &&
          input.startMinutes != null &&
          input.day == null &&
          input.place.type != PlaceType.accommodation) {
        throw StateError('${input.place.name} 固定時間需同時指定日期。');
      }
      if (input.locked &&
          input.day != null &&
          (input.day! < 1 || input.day! > request.days)) {
        throw StateError('${input.place.name} 的鎖定日期超出旅程，請先調整。');
      }
      if (input.place.type != PlaceType.accommodation) continue;
      final stay = input.preferences.hotelStay!;
      if (input.day != null && input.day != stay.checkInDay) {
        throw StateError('${input.place.name} 的指定日期與入住日期不一致。');
      }
      final key = '${input.place.id}:${stay.checkInDay}:${stay.checkOutDay}';
      if (!bookings.add(key)) continue;
      for (var night = stay.checkInDay; night < stay.checkOutDay; night++) {
        if (nights.containsKey(night)) {
          throw StateError(
            'Day $night 同晚住宿重疊：${nights[night]}、${input.place.name}。',
          );
        }
        nights[night] = input.place.name;
      }
    }
  }

  int _initialDepartureMinutesForDate({
    required DateTime date,
    required DateTime now,
    required List<RoutePlaceInput> constraints,
  }) {
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final lockedStarts = constraints
        .where(
          (constraint) => constraint.locked && constraint.startMinutes != null,
        )
        .map((constraint) => constraint.startMinutes!);
    var preferredStart = lockedStarts.isEmpty
        ? dayStartMinutes
        : min(dayStartMinutes, lockedStarts.reduce(min));
    preferredStart = max(0, preferredStart);

    if (!isToday) return preferredStart;

    final adjustedDeparture = now.add(const Duration(minutes: 1));
    final nextAvailableMinute =
        adjustedDeparture.hour * 60 + adjustedDeparture.minute;
    return max(preferredStart, nextAvailableMinute);
  }

  int _mealAwareDepartureMinutes({
    required int defaultDepartureMinutes,
    required RouteStop? dayOrigin,
    required List<RoutePlaceInput> constraints,
  }) {
    if (dayOrigin == null) return defaultDepartureMinutes;
    var departureMinutes = defaultDepartureMinutes;
    for (final input in _suggestMeals(constraints)) {
      if (input.place.type != PlaceType.restaurant || input.locked) continue;
      final meal = input.effectiveMealType;
      final mealStart = input.preferences.mealWindowStart ?? meal.startMinutes;
      if (mealStart == null) continue;
      final directTravelMinutes = _estimatedTravelMinutes(
        dayOrigin,
        _toRouteStop(input),
      );
      departureMinutes = min(
        departureMinutes,
        max(0, mealStart - directTravelMinutes),
      );
    }
    return departureMinutes;
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
      final stay = constraint.place.type == PlaceType.accommodation
          ? constraint.preferences.hotelStay
          : null;
      final assignmentId = stay == null
          ? constraint.place.id
          : '${constraint.place.id}:${stay.checkInDay}:${stay.checkOutDay}';
      if (!assignedPlaceIds.add(assignmentId)) {
        warnings.add('${constraint.place.name} 重複出現，已只保留一次。');
        continue;
      }
      if (stay != null) {
        void addHotelEndPoint(int day) {
          buckets[day - 1].add(
            RoutePlaceInput(
              place: constraint.place,
              day: day,
              startMinutes: day == stay.checkInDay
                  ? constraint.startMinutes
                  : null,
              locked: day == stay.checkInDay && constraint.locked,
              preferences: constraint.preferences,
              kind: VisitKind.hotelStay,
            ),
          );
        }

        for (var night = stay.checkInDay; night < stay.checkOutDay; night++) {
          if (night <= request.days) addHotelEndPoint(night);
        }
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
    _mergeGeographicGroupsByHotel(buckets, geographicGroups);

    return buckets;
  }

  Future<RouteDay> _generateDay({
    required int day,
    required DateTime date,
    required RouteStop? dayOrigin,
    required RouteStop fallbackOrigin,
    required int initialDepartureMinutes,
    required int departureFloor,
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
        origin: dayOrigin ?? fallbackOrigin,
        visits: const [],
        travelLegs: const [],
        isValid: true,
      );
    }

    final effectiveConstraints = _suggestMeals(constraints);
    final constraintsById = {
      for (final constraint in effectiveConstraints)
        constraint.occurrenceId: constraint,
    };
    final hotelEndPoints = effectiveConstraints
        .where((input) => input.kind == VisitKind.hotelStay)
        .map(_toRouteStop)
        .toList();
    final stops = effectiveConstraints
        .where((input) => input.kind != VisitKind.hotelStay)
        .map(_toRouteStop)
        .toList();
    final orderedStops = [
      ..._orderStops(
        stops,
        routeOrigin: dayOrigin,
        routeEnd: hotelEndPoints.isEmpty ? null : hotelEndPoints.last,
        startTimeMinutes: initialDepartureMinutes,
      ),
      ...hotelEndPoints,
    ];
    final effectiveDayOrigin = dayOrigin ?? orderedStops.first;
    final visits = <RouteVisit>[];
    final travelLegs = <TravelLeg>[];
    final warnings = <String>[];
    final mealCounts = <MealType, int>{};
    for (final input in effectiveConstraints.where(
      (input) => input.place.type == PlaceType.restaurant,
    )) {
      final meal = input.effectiveMealType;
      mealCounts[meal] = (mealCounts[meal] ?? 0) + 1;
    }
    var previousStop = effectiveDayOrigin;
    var departureMinutes = initialDepartureMinutes;

    for (var index = 0; index < orderedStops.length; index++) {
      final destination = orderedStops[index];
      final constraint = constraintsById[destination.id]!;
      final startsAtSelectedPlace = dayOrigin == null && index == 0;
      final alreadyAtHotel =
          constraint.kind == VisitKind.hotelStay &&
          previousStop.latitude == destination.latitude &&
          previousStop.longitude == destination.longitude;
      late DateTime requestedDeparture;
      late ScheduledVisit schedule;
      TdxRoute? route;
      String? errorMessage;
      var routeAdjustmentCount = 0;
      var rateLimitRetriesForLeg = 0;

      if (startsAtSelectedPlace || alreadyAtHotel) {
        final earliestStart = destination.earliestTimeMinutes;
        if (earliestStart != null) {
          departureMinutes = max(departureMinutes, earliestStart);
        }
        schedule = _scheduleService.scheduleVisit(
          departureMinutes: departureMinutes,
          travelMinutes: 0,
          destination: destination,
        );
        onProgress?.call('Day $day 從 ${destination.name} 開始。');
      } else {
        departureMinutes = _plannedDepartureMinutes(
          availableDepartureMinutes: departureMinutes,
          previousStop: previousStop,
          destination: destination,
          isFirstStop: index == 0,
        );
        departureMinutes = max(departureFloor, departureMinutes);
        onProgress?.call(
          '正在查詢 Day $day 第 ${index + 1}/${orderedStops.length} 段交通…',
        );

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
                  destination:
                      '${destination.latitude},${destination.longitude}',
                  requestedDeparture: requestedDeparture,
                );
                if (route == null) {
                  errorMessage = 'TDX 沒有提供指定時間後的可用路線，已使用估計時間。';
                }
                break;
              } on TdxRateLimitException catch (error) {
                final canRetry =
                    rateLimitRetriesForLeg < 1 &&
                    retryBudget.remainingWaits > 0;
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
          final mealWindowEnd = constraint.place.type == PlaceType.restaurant
              ? constraint.preferences.mealWindowEnd ??
                    constraint.effectiveMealType.endMinutes
              : null;
          final shouldRetryEarlier =
              route != null &&
              index == 0 &&
              ((fixedStart != null &&
                      schedule.visitStartMinutes > fixedStart) ||
                  (!constraint.locked &&
                      mealWindowEnd != null &&
                      schedule.visitStartMinutes > mealWindowEnd)) &&
              routeAdjustmentCount < 2;
          final shouldRetryLater =
              route != null &&
              schedule.waitingMinutes > 15 &&
              routeAdjustmentCount < 2;

          if (shouldRetryEarlier) {
            final latestAllowedStart = fixedStart ?? mealWindowEnd!;
            final latenessMinutes =
                schedule.visitStartMinutes - latestAllowedStart;
            departureMinutes = max(
              departureFloor,
              departureMinutes - latenessMinutes - 5,
            );
            onProgress?.call(
              fixedStart != null
                  ? '首站可能遲到，正在重新查詢更早的 TDX 班次…'
                  : '首餐超出合理時段，正在重新查詢更早的 TDX 班次…',
            );
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
      }

      if (constraint.locked &&
          constraint.startMinutes != null &&
          schedule.visitStartMinutes > constraint.startMinutes!) {
        warnings.add(
          '${constraint.place.name} 預計 ${_formatMinutes(schedule.visitStartMinutes)} 抵達，晚於指定時間 ${_formatMinutes(constraint.startMinutes!)}。',
        );
      }
      final usesOpeningHours =
          constraint.kind == VisitKind.activity &&
          constraint.place.hasKnownOpeningHours;
      final fixedTimeOutsideOpeningHours =
          usesOpeningHours &&
          constraint.locked &&
          constraint.startMinutes != null &&
          (constraint.startMinutes! < constraint.place.openMinutes ||
              constraint.startMinutes! + constraint.stayMinutes >
                  constraint.place.closeMinutes);
      if (fixedTimeOutsideOpeningHours) {
        warnings.add('${constraint.place.name} 的指定時間不在景點營業時間內。');
      } else if (usesOpeningHours &&
          schedule.visitEndMinutes > constraint.place.closeMinutes) {
        warnings.add('${constraint.place.name} 的停留時間超過景點營業時間。');
      }
      if (constraint.kind == VisitKind.hotelStay &&
          schedule.visitStartMinutes <
              constraint.preferences.hotelStay!.effectiveCheckInFrom) {
        warnings.add('${constraint.place.name} 的抵達時間早於設定的最早抵達時間。');
      }
      if (schedule.visitEndMinutes > 1440) {
        warnings.add('${constraint.place.name} 已超出當天時間，請減少項目或調整日期。');
      }
      final information = _visitInformation(constraint, schedule);
      if (constraint.place.type == PlaceType.restaurant &&
          [
            MealType.breakfast,
            MealType.lunch,
            MealType.dinner,
          ].contains(constraint.effectiveMealType) &&
          (mealCounts[constraint.effectiveMealType] ?? 0) > 1) {
        information.add(
          '同一天有多筆${constraint.effectiveMealType.label}；已全部保留，請確認是否刻意安排。',
        );
      }
      information.add(
        startsAtSelectedPlace || alreadyAtHotel
            ? '本次從此位置開始，不新增進站交通。'
            : route == null
            ? '交通時間為估算，未確認實際可搭乘路線。'
            : '交通時間來自 TDX 查詢，不代表已訂票或保證班次運行。',
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
          eventId: constraint.occurrenceId,
          kind: constraint.kind,
          preferences: constraint.preferences,
          mealType: constraint.effectiveMealType,
          information: information,
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
      origin: effectiveDayOrigin,
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

  List<RouteStop> _orderStops(
    List<RouteStop> stops, {
    required RouteStop? routeOrigin,
    required int startTimeMinutes,
    RouteStop? routeEnd,
  }) {
    if (stops.length <= 1) return List.of(stops);
    if (stops.length > 8) {
      return _timeAwareOrder(stops, routeOrigin, routeEnd, startTimeMinutes);
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
    final travelTimesFromOrigin = routeOrigin == null
        ? null
        : stops
              .map(
                (stop) => _estimatedTravelMinutes(routeOrigin, stop).toDouble(),
              )
              .toList();
    return _optimizer
        .optimizeRoute(
          stopsToVisit: stops,
          durationMatrix: matrix,
          startTimeMinutes: _optimizationStartMinutes(
            stops,
            routeOrigin,
            startTimeMinutes,
          ),
          travelTimesFromStart: travelTimesFromOrigin,
          travelTimesToEnd: routeEnd == null
              ? null
              : stops
                    .map(
                      (stop) =>
                          _estimatedTravelMinutes(stop, routeEnd).toDouble(),
                    )
                    .toList(),
          endPenaltyScores: routeEnd == null
              ? null
              : stops
                    .map((stop) => _hotelEndpointPenalty(stop, routeEnd))
                    .toList(),
        )
        .sortedStops;
  }

  int _optimizationStartMinutes(
    List<RouteStop> stops,
    RouteStop? routeOrigin,
    int defaultStartMinutes,
  ) {
    var startMinutes = defaultStartMinutes;
    for (final stop in stops) {
      final fixedStart = stop.earliestTimeMinutes == stop.latestTimeMinutes
          ? stop.earliestTimeMinutes
          : null;
      if (fixedStart == null) continue;
      final travelMinutes = routeOrigin == null
          ? 0
          : _estimatedTravelMinutes(routeOrigin, stop) + 5;
      startMinutes = min(startMinutes, fixedStart - travelMinutes);
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

  List<RouteStop> _timeAwareOrder(
    List<RouteStop> stops,
    RouteStop? origin,
    RouteStop? end,
    int start,
  ) {
    final remaining = List<RouteStop>.of(stops);
    final ordered = <RouteStop>[];
    var current = origin;
    var time = start;
    while (remaining.isNotEmpty) {
      double score(RouteStop stop) {
        final travel = current == null
            ? 0
            : _estimatedTravelMinutes(current, stop);
        final arrival = time + travel;
        final visitStart = max(arrival, stop.earliestTimeMinutes ?? 0);
        final late = max(0, visitStart - (stop.latestTimeMinutes ?? 1440));
        final endpointCost = end == null
            ? 0
            : _estimatedTravelMinutes(stop, end) +
                  _hotelEndpointPenalty(stop, end);
        return travel +
            (visitStart - arrival) * 0.5 +
            late * 10000 +
            endpointCost * 0.1;
      }

      remaining.sort((first, second) => score(first).compareTo(score(second)));
      final next = remaining.removeAt(0);
      time =
          max(
            time +
                (current == null ? 0 : _estimatedTravelMinutes(current, next)),
            next.earliestTimeMinutes ?? 0,
          ) +
          next.stayDurationMinutes;
      current = next;
      ordered.add(next);
    }
    return ordered;
  }

  List<RoutePlaceInput> _suggestMeals(List<RoutePlaceInput> inputs) {
    final used = inputs
        .where((input) => input.place.type == PlaceType.restaurant)
        .map((input) => input.preferences.mealType)
        .toSet();
    return inputs.map((input) {
      if (input.place.type != PlaceType.restaurant ||
          input.preferences.mealType != MealType.unspecified) {
        return input;
      }
      final fixed = input.locked ? input.startMinutes : null;
      final suggestion = fixed != null
          ? [MealType.breakfast, MealType.lunch, MealType.dinner].firstWhere(
              (meal) =>
                  fixed >= meal.startMinutes! && fixed <= meal.endMinutes!,
              orElse: () => MealType.snack,
            )
          : [MealType.lunch, MealType.dinner, MealType.snack].firstWhere(
              (meal) => !used.contains(meal),
              orElse: () => MealType.snack,
            );
      used.add(suggestion);
      return RoutePlaceInput(
        place: input.place,
        day: input.day,
        startMinutes: input.startMinutes,
        locked: input.locked,
        preferences: input.preferences,
        suggestedMealType: suggestion,
      );
    }).toList();
  }

  List<String> _visitInformation(
    RoutePlaceInput input,
    ScheduledVisit schedule,
  ) {
    final place = input.place;
    final preferences = input.preferences;
    final details = <String>[
      if (input.locked && input.startMinutes != null)
        '已確認的使用者安排：${_formatMinutes(input.startMinutes!)}（不代表已訂位／訂房）。',
      '${preferences.durationMinutes == null ? '預設／資料庫估算' : '使用者設定'}：${input.kind == VisitKind.activity ? '停留' : input.kind.label} ${input.stayMinutes} 分鐘。',
      if (place.estimatedCost <= 0)
        '費用未知，不代表免費。'
      else
        '資料庫預估費用 ${place.estimatedCost} 元，非即時報價。',
    ];
    if (place.type == PlaceType.accommodation) {
      final stay = preferences.hotelStay!;
      details.addAll([
        '住宿日期：Day ${stay.checkInDay} 起至 Day ${stay.checkOutDay}；飯店固定為每天最後一站。',
        '${stay.checkInFromMinutes == null ? '最早抵達時間未知，暫以預設估算' : '使用者提供最早抵達時間'} ${_formatMinutes(stay.effectiveCheckInFrom)}。',
        '房況、訂房與寄放行李服務未確認。',
        '隔日不重複顯示飯店，第一段交通會直接從此飯店出發。',
      ]);
      return details;
    }
    details.add(
      place.hasKnownOpeningHours
          ? '資料庫提供營業區間 ${_formatMinutes(place.openMinutes)}–${_formatMinutes(place.closeMinutes)}；每日及假日例外待確認。'
          : '營業時間未知，尚未驗證能否在安排時段進入。',
    );
    if (place.openingHoursRaw.isNotEmpty) {
      details.add('營業時間原文（未完整解析）：${place.openingHoursRaw}');
    }
    if (place.type == PlaceType.restaurant) {
      final meal = input.effectiveMealType;
      final start = preferences.mealWindowStart ?? meal.startMinutes;
      final end = preferences.mealWindowEnd ?? meal.endMinutes;
      details.add(
        '${input.suggestedMealType == null ? '使用者餐別' : '演算法建議餐別'}：${meal.label}（非訂位）。',
      );
      if (start != null && end != null) {
        details.add(
          '${preferences.mealWindowStart == null ? '預設' : '使用者設定'}用餐開始時段：${_formatMinutes(start)}–${_formatMinutes(end)}。',
        );
        if (schedule.visitStartMinutes < start ||
            schedule.visitStartMinutes > end) {
          details.add('用餐時間偏離偏好時段；已保留項目，請調整交通或指定時間。');
        }
      }
    }
    return details;
  }

  List<RoutePlaceInput> _orderInputsByDistance(List<RoutePlaceInput> inputs) {
    if (inputs.length < 2) return List<RoutePlaceInput>.of(inputs);
    final inputsById = {for (final input in inputs) input.place.id: input};
    final orderedStops = _orderStops(
      inputs
          .map(
            (input) => RouteStop(
              id: input.place.id,
              name: input.place.name,
              latitude: input.place.latitude,
              longitude: input.place.longitude,
              county: PlaceService.countyFor(input.place),
              stayDurationMinutes: 0,
            ),
          )
          .toList(),
      routeOrigin: null,
      startTimeMinutes: dayStartMinutes,
    );
    final reference = origin ?? _toRouteStop(inputs.first);
    final firstDistance = _distanceInKilometers(
      reference.latitude,
      reference.longitude,
      orderedStops.first.latitude,
      orderedStops.first.longitude,
    );
    final lastDistance = _distanceInKilometers(
      reference.latitude,
      reference.longitude,
      orderedStops.last.latitude,
      orderedStops.last.longitude,
    );
    final directedStops = lastDistance < firstDistance
        ? orderedStops.reversed
        : orderedStops;
    return directedStops.map((stop) => inputsById[stop.id]!).toList();
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

  void _mergeGeographicGroupsByHotel(
    List<List<RoutePlaceInput>> buckets,
    List<List<RoutePlaceInput>> geographicGroups,
  ) {
    final remainingGroups = geographicGroups
        .where((group) => group.isNotEmpty)
        .map(List<RoutePlaceInput>.of)
        .toList();
    if (remainingGroups.isEmpty) return;

    final hotelDays = <int>[
      for (var dayIndex = 0; dayIndex < buckets.length; dayIndex++)
        if (_hotelAnchor(buckets[dayIndex]) != null) dayIndex,
    ];
    final daysWithoutHotels = <int>[
      for (var dayIndex = 0; dayIndex < buckets.length; dayIndex++)
        if (_hotelAnchor(buckets[dayIndex]) == null) dayIndex,
    ];
    final availableHotelDays = List<int>.of(hotelDays);
    final hotelAssignments = min(
      availableHotelDays.length,
      max(0, remainingGroups.length - daysWithoutHotels.length),
    );
    for (var assignment = 0; assignment < hotelAssignments; assignment++) {
      var bestDayListIndex = 0;
      var bestGroupIndex = 0;
      var bestCost = double.infinity;
      for (
        var dayListIndex = 0;
        dayListIndex < availableHotelDays.length;
        dayListIndex++
      ) {
        final hotel = _hotelAnchor(buckets[availableHotelDays[dayListIndex]])!;
        for (
          var groupIndex = 0;
          groupIndex < remainingGroups.length;
          groupIndex++
        ) {
          final cost = _groupToHotelCost(remainingGroups[groupIndex], hotel);
          if (cost < bestCost) {
            bestCost = cost;
            bestDayListIndex = dayListIndex;
            bestGroupIndex = groupIndex;
          }
        }
      }
      final dayIndex = availableHotelDays.removeAt(bestDayListIndex);
      buckets[dayIndex].addAll(remainingGroups.removeAt(bestGroupIndex));
    }

    var firstAvailableDayIndex = 0;
    for (
      var groupIndex = 0;
      groupIndex < remainingGroups.length;
      groupIndex++
    ) {
      final groupsLeft = remainingGroups.length - groupIndex;
      final lastAvailableDayIndex = daysWithoutHotels.length - groupsLeft;
      var bestDayListIndex = firstAvailableDayIndex;
      for (
        var dayListIndex = firstAvailableDayIndex + 1;
        dayListIndex <= lastAvailableDayIndex;
        dayListIndex++
      ) {
        if (_totalStayMinutes(buckets[daysWithoutHotels[dayListIndex]]) <
            _totalStayMinutes(buckets[daysWithoutHotels[bestDayListIndex]])) {
          bestDayListIndex = dayListIndex;
        }
      }
      buckets[daysWithoutHotels[bestDayListIndex]].addAll(
        remainingGroups[groupIndex],
      );
      firstAvailableDayIndex = bestDayListIndex + 1;
    }
  }

  Place? _hotelAnchor(List<RoutePlaceInput> constraints) {
    for (final constraint in constraints.reversed) {
      if (constraint.kind == VisitKind.hotelStay) return constraint.place;
    }
    return null;
  }

  double _groupToHotelCost(List<RoutePlaceInput> group, Place hotel) {
    final hotelCounty = PlaceService.countyFor(hotel);
    final groupCounties = group
        .map((input) => PlaceService.countyFor(input.place))
        .where((county) => county.isNotEmpty)
        .toSet();
    final hasKnownCountyMismatch =
        hotelCounty.isNotEmpty &&
        groupCounties.isNotEmpty &&
        !groupCounties.contains(hotelCounty);
    final nearestDistance = group
        .map(
          (input) => _distanceInKilometers(
            input.place.latitude,
            input.place.longitude,
            hotel.latitude,
            hotel.longitude,
          ),
        )
        .reduce(min);
    return nearestDistance +
        (hasKnownCountyMismatch ? _crossCountyHotelPenaltyMinutes : 0);
  }

  RouteStop _nextDayOrigin(Place place) {
    return RouteStop(
      id: place.id,
      name: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
      county: PlaceService.countyFor(place),
      stayDurationMinutes: 0,
    );
  }

  RouteStop _toRouteStop(RoutePlaceInput constraint) {
    final place = constraint.place;
    final requestedStart = constraint.locked ? constraint.startMinutes : null;
    var earliest = place.hasKnownOpeningHours ? place.openMinutes : 0;
    var latest =
        (place.hasKnownOpeningHours ? place.closeMinutes : 1440) -
        constraint.stayMinutes;
    if (place.type == PlaceType.restaurant) {
      earliest = max(
        earliest,
        constraint.preferences.mealWindowStart ??
            constraint.effectiveMealType.startMinutes ??
            0,
      );
      latest = min(
        latest,
        constraint.preferences.mealWindowEnd ??
            constraint.effectiveMealType.endMinutes ??
            1440,
      );
    }
    if (constraint.kind != VisitKind.activity) {
      earliest = constraint.preferences.hotelStay!.effectiveCheckInFrom;
      latest = 1440 - constraint.stayMinutes;
    }
    return RouteStop(
      id: constraint.occurrenceId,
      name: constraint.kind == VisitKind.activity
          ? place.name
          : '${place.name}・${constraint.kind.label}',
      latitude: place.latitude,
      longitude: place.longitude,
      county: PlaceService.countyFor(place),
      stayDurationMinutes: constraint.stayMinutes,
      earliestTimeMinutes: requestedStart ?? earliest,
      latestTimeMinutes: requestedStart ?? latest,
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

  double _hotelEndpointPenalty(RouteStop from, RouteStop hotel) {
    final crossesCounty =
        from.county.isNotEmpty &&
        hotel.county.isNotEmpty &&
        from.county != hotel.county;
    return crossesCounty ? _crossCountyHotelPenaltyMinutes : 0;
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
      (total, constraint) => total + constraint.stayMinutes,
    );
  }

  String _formatMinutes(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }
}
