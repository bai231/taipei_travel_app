import '../../../models/trip_place_constraint.dart';
import '../../../models/visit_preferences.dart';
import '../models/itinerary_edit_command.dart';
import '../models/itinerary_edit_result.dart';
import '../models/route_itinerary.dart';
import '../models/route_travel_mode.dart';
import 'relax_day_planner.dart';
import '../../../models/place.dart';

class ItineraryEditExecutionResult {
  final List<TripPlaceConstraint> constraints;
  final Map<RouteLegKey, RouteTravelMode> travelModeOverrides;
  final List<String> errors;
  final List<String> appliedMessages;

  const ItineraryEditExecutionResult({
    required this.constraints,
    required this.travelModeOverrides,
    this.errors = const [],
    this.appliedMessages = const [],
  });

  bool get isSuccessful => errors.isEmpty;
}

class ItineraryEditExecutor {
  final RelaxDayPlanner _relaxDayPlanner;

  const ItineraryEditExecutor({
    RelaxDayPlanner relaxDayPlanner = const RelaxDayPlanner(),
  }) : _relaxDayPlanner = relaxDayPlanner;

  ItineraryEditExecutionResult execute({
    required ItineraryEditResult editResult,
    required List<TripPlaceConstraint> currentConstraints,
    required Map<RouteLegKey, RouteTravelMode> currentTravelModeOverrides,
    required RouteItinerary itinerary,
    Map<int, Place> resolvedPlaces = const {},
  }) {
    final constraints = _copyConstraints(currentConstraints);

    final travelModeOverrides = Map<RouteLegKey, RouteTravelMode>.of(
      currentTravelModeOverrides,
    );

    final errors = <String>[];
    final appliedMessages = <String>[];

    for (var index = 0; index < editResult.commands.length; index++) {
      final command = editResult.commands[index];
      final prefix = '第 ${index + 1} 項修改';

      switch (command.action) {
        case ItineraryEditAction.movePlace:
          _movePlace(command, constraints, prefix, errors);
          break;

        case ItineraryEditAction.removePlace:
          _removePlace(command, constraints, prefix, errors);
          break;

        case ItineraryEditAction.changeDuration:
          _changeDuration(command, constraints, prefix, errors);
          break;

        case ItineraryEditAction.lockPlace:
          _lockPlace(command, constraints, prefix, errors);
          break;

        case ItineraryEditAction.unlockPlace:
          _unlockPlace(command, constraints, prefix, errors);
          break;

        case ItineraryEditAction.changeTravelMode:
          _changeTravelMode(
            command: command,
            itinerary: itinerary,
            travelModeOverrides: travelModeOverrides,
            prefix: prefix,
            errors: errors,
          );
          break;

        case ItineraryEditAction.addPlace:
          _addPlace(
            command: command,
            commandIndex: index,
            resolvedPlaces: resolvedPlaces,
            constraints: constraints,
            prefix: prefix,
            errors: errors,
            appliedMessages: appliedMessages,
          );
          break;

        case ItineraryEditAction.replacePlace:
          errors.add('$prefix：替換景點需要先從資料庫選擇替代景點。');
          break;

        case ItineraryEditAction.relaxDay:
          _relaxDay(
            command: command,
            itinerary: itinerary,
            constraints: constraints,
            prefix: prefix,
            errors: errors,
            appliedMessages: appliedMessages,
          );
          break;

        case ItineraryEditAction.unknown:
          errors.add('$prefix：無法辨識修改類型。');
          break;
      }
    }

    return ItineraryEditExecutionResult(
      constraints: List.unmodifiable(constraints),
      travelModeOverrides: Map.unmodifiable(travelModeOverrides),
      errors: List.unmodifiable(errors),
      appliedMessages: List.unmodifiable(appliedMessages),
    );
  }

  void _addPlace({
    required ItineraryEditCommand command,
    required int commandIndex,
    required Map<int, Place> resolvedPlaces,
    required List<TripPlaceConstraint> constraints,
    required String prefix,
    required List<String> errors,
    required List<String> appliedMessages,
  }) {
    final place = resolvedPlaces[commandIndex];

    if (place == null) {
      errors.add('$prefix：尚未選擇要新增的景點。');
      return;
    }

    final alreadyExists = constraints.any(
      (constraint) => constraint.place.id == place.id,
    );

    if (alreadyExists) {
      errors.add('$prefix：「${place.name}」已經在行程中。');
      return;
    }

    constraints.add(
      TripPlaceConstraint(
        place: place,
        day: command.targetDay,
        startMinutes: command.targetStartMinutes,
        locked: command.targetStartMinutes != null,
        preferences: const VisitPreferences(),
      ),
    );

    final locationText = command.targetDay == null
        ? '由系統自動安排日期'
        : '安排至 Day ${command.targetDay}';

    appliedMessages.add('已新增「${place.name}」，$locationText。');
  }

  void _movePlace(
    ItineraryEditCommand command,
    List<TripPlaceConstraint> constraints,
    String prefix,
    List<String> errors,
  ) {
    final constraint = _findConstraint(command.placeName, constraints);

    if (constraint == null) {
      errors.add('$prefix：找不到「${command.placeName}」。');
      return;
    }

    if (command.targetDay != null) {
      constraint.day = command.targetDay;
    }

    if (command.targetStartMinutes != null) {
      constraint.startMinutes = command.targetStartMinutes;
      constraint.locked = true;
    } else if (command.targetDay != null) {
      // 只指定日期時，交由排程演算法安排當天時間。
      constraint.startMinutes = null;
      constraint.locked = false;
    }
  }

  void _removePlace(
    ItineraryEditCommand command,
    List<TripPlaceConstraint> constraints,
    String prefix,
    List<String> errors,
  ) {
    final originalLength = constraints.length;

    constraints.removeWhere(
      (constraint) => _sameName(constraint.place.name, command.placeName),
    );

    if (constraints.length == originalLength) {
      errors.add('$prefix：找不到「${command.placeName}」。');
    }
  }

  void _changeDuration(
    ItineraryEditCommand command,
    List<TripPlaceConstraint> constraints,
    String prefix,
    List<String> errors,
  ) {
    final constraint = _findConstraint(command.placeName, constraints);

    if (constraint == null) {
      errors.add('$prefix：找不到「${command.placeName}」。');
      return;
    }

    final durationMinutes = command.durationMinutes;

    if (durationMinutes == null || durationMinutes <= 0) {
      errors.add('$prefix：停留時間不正確。');
      return;
    }

    final original = constraint.preferences;

    constraint.preferences = VisitPreferences(
      mealType: original.mealType,
      durationMinutes: durationMinutes,
      mealWindowStart: original.mealWindowStart,
      mealWindowEnd: original.mealWindowEnd,
      hotelStay: original.hotelStay,
    );
  }

  void _lockPlace(
    ItineraryEditCommand command,
    List<TripPlaceConstraint> constraints,
    String prefix,
    List<String> errors,
  ) {
    final constraint = _findConstraint(command.placeName, constraints);

    if (constraint == null) {
      errors.add('$prefix：找不到「${command.placeName}」。');
      return;
    }

    if (command.targetDay == null || command.targetStartMinutes == null) {
      errors.add('$prefix：鎖定景點需要指定日期與時間。');
      return;
    }

    constraint.day = command.targetDay;
    constraint.startMinutes = command.targetStartMinutes;
    constraint.locked = true;
  }

  void _unlockPlace(
    ItineraryEditCommand command,
    List<TripPlaceConstraint> constraints,
    String prefix,
    List<String> errors,
  ) {
    final constraint = _findConstraint(command.placeName, constraints);

    if (constraint == null) {
      errors.add('$prefix：找不到「${command.placeName}」。');
      return;
    }

    constraint.day = null;
    constraint.startMinutes = null;
    constraint.locked = false;
  }

  void _changeTravelMode({
    required ItineraryEditCommand command,
    required RouteItinerary itinerary,
    required Map<RouteLegKey, RouteTravelMode> travelModeOverrides,
    required String prefix,
    required List<String> errors,
  }) {
    final mode = _parseTravelMode(command.travelMode);

    if (mode == null) {
      errors.add('$prefix：不支援指定的交通方式。');
      return;
    }

    for (final day in itinerary.days) {
      for (final leg in day.travelLegs) {
        final originMatches = _sameName(leg.origin.name, command.placeName);

        final destinationMatches = _sameName(
          leg.destination.name,
          command.destinationPlaceName,
        );

        if (!originMatches || !destinationMatches) {
          continue;
        }

        final key = routeLegKey(
          day: day.day,
          originId: leg.origin.id,
          destinationId: leg.destination.id,
        );

        if (mode == RouteTravelMode.transit) {
          travelModeOverrides.remove(key);
        } else {
          travelModeOverrides[key] = mode;
        }

        return;
      }
    }

    errors.add('$prefix：目前行程中找不到指定的交通區段。');
  }

  void _relaxDay({
    required ItineraryEditCommand command,
    required RouteItinerary itinerary,
    required List<TripPlaceConstraint> constraints,
    required String prefix,
    required List<String> errors,
    required List<String> appliedMessages,
  }) {
    final targetDay = command.targetDay;

    if (targetDay == null) {
      errors.add('$prefix：沒有指定要放鬆哪一天。');
      return;
    }

    final plan = _relaxDayPlanner.createPlan(
      itinerary: itinerary,
      day: targetDay,
    );

    if (!plan.canApply || plan.placeToRemove == null) {
      errors.add('$prefix：${plan.error ?? '無法產生調整方案。'}');
      return;
    }

    final placeToRemove = plan.placeToRemove!;

    final originalLength = constraints.length;

    constraints.removeWhere(
      (constraint) => constraint.place.id == placeToRemove.id,
    );

    if (constraints.length == originalLength) {
      errors.add(
        '$prefix：找不到要移除的景點'
        '「${placeToRemove.name}」。',
      );
      return;
    }

    appliedMessages.add(plan.explanation);
  }

  RouteTravelMode? _parseTravelMode(String? value) {
    switch (value) {
      case 'transit':
        return RouteTravelMode.transit;

      case 'walking':
        return RouteTravelMode.walking;

      case 'driving':
        return RouteTravelMode.driving;

      default:
        return null;
    }
  }

  TripPlaceConstraint? _findConstraint(
    String? placeName,
    List<TripPlaceConstraint> constraints,
  ) {
    if (placeName == null || placeName.trim().isEmpty) {
      return null;
    }

    for (final constraint in constraints) {
      if (_sameName(constraint.place.name, placeName)) {
        return constraint;
      }
    }

    return null;
  }

  bool _sameName(String? first, String? second) {
    if (first == null || second == null) {
      return false;
    }

    return _normalizeName(first) == _normalizeName(second);
  }

  String _normalizeName(String value) {
    return value.trim().toLowerCase();
  }

  List<TripPlaceConstraint> _copyConstraints(List<TripPlaceConstraint> values) {
    return values
        .map(
          (item) => TripPlaceConstraint(
            place: item.place,
            day: item.day,
            startMinutes: item.startMinutes,
            locked: item.locked,
            preferences: item.preferences,
          ),
        )
        .toList();
  }
}
