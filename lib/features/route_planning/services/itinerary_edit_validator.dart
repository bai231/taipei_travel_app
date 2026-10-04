import '../models/itinerary_edit_command.dart';
import '../models/itinerary_edit_result.dart';
import '../models/route_itinerary.dart';

class ItineraryEditValidationResult {
  final List<String> errors;

  const ItineraryEditValidationResult({this.errors = const []});

  bool get isValid => errors.isEmpty;
}

class ItineraryEditValidator {
  const ItineraryEditValidator();

  ItineraryEditValidationResult validate({
    required ItineraryEditResult result,
    required RouteItinerary itinerary,
  }) {
    final errors = <String>[];

    if (!result.understood) {
      errors.add('AI 尚未完整理解修改要求。');
    }

    if (result.commands.isEmpty) {
      errors.add('沒有可執行的修改指令。');
    }

    final itineraryPlaceNames = {
      for (final day in itinerary.days)
        for (final visit in day.visits) _normalizeName(visit.place.name),
    };

    for (var index = 0; index < result.commands.length; index++) {
      final command = result.commands[index];
      final commandNumber = index + 1;

      _validateCommand(
        command: command,
        commandNumber: commandNumber,
        dayCount: itinerary.days.length,
        itineraryPlaceNames: itineraryPlaceNames,
        errors: errors,
      );
    }

    return ItineraryEditValidationResult(errors: List.unmodifiable(errors));
  }

  void _validateCommand({
    required ItineraryEditCommand command,
    required int commandNumber,
    required int dayCount,
    required Set<String> itineraryPlaceNames,
    required List<String> errors,
  }) {
    final prefix = '第 $commandNumber 項修改';

    if (command.action == ItineraryEditAction.unknown) {
      errors.add('$prefix：無法辨識修改類型。');
      return;
    }

    if (command.targetDay != null &&
        (command.targetDay! < 1 || command.targetDay! > dayCount)) {
      errors.add(
        '$prefix：Day ${command.targetDay} '
        '超出目前 $dayCount 天的行程範圍。',
      );
    }

    if (command.targetStartMinutes != null &&
        (command.targetStartMinutes! < 0 ||
            command.targetStartMinutes! >= 1440)) {
      errors.add('$prefix：指定時間不正確。');
    }

    switch (command.action) {
      case ItineraryEditAction.movePlace:
        _requireExistingPlace(
          command.placeName,
          prefix,
          itineraryPlaceNames,
          errors,
        );

        if (command.targetDay == null && command.targetStartMinutes == null) {
          errors.add('$prefix：移動景點時必須指定日期或時間。');
        }

      case ItineraryEditAction.removePlace:
        _requireExistingPlace(
          command.placeName,
          prefix,
          itineraryPlaceNames,
          errors,
        );

      case ItineraryEditAction.addPlace:
        final query = !_isBlank(command.placeQuery)
            ? command.placeQuery
            : command.placeName;

        if (_isBlank(query)) {
          errors.add('$prefix：新增景點時缺少景點名稱或條件。');
        }
        break;

      case ItineraryEditAction.replacePlace:
        _requireExistingPlace(
          command.placeName,
          prefix,
          itineraryPlaceNames,
          errors,
        );

        if (_isBlank(command.placeQuery)) {
          errors.add('$prefix：替換景點時缺少新景點名稱或條件。');
        }

      case ItineraryEditAction.changeDuration:
        _requireExistingPlace(
          command.placeName,
          prefix,
          itineraryPlaceNames,
          errors,
        );

        if (command.durationMinutes == null || command.durationMinutes! <= 0) {
          errors.add('$prefix：缺少有效的停留時間。');
        }

      case ItineraryEditAction.lockPlace:
        _requireExistingPlace(
          command.placeName,
          prefix,
          itineraryPlaceNames,
          errors,
        );

        if (command.targetDay == null) {
          errors.add('$prefix：鎖定景點時必須指定日期。');
        }

        if (command.targetStartMinutes == null) {
          errors.add('$prefix：鎖定景點時必須指定時間。');
        }

      case ItineraryEditAction.unlockPlace:
        _requireExistingPlace(
          command.placeName,
          prefix,
          itineraryPlaceNames,
          errors,
        );

      case ItineraryEditAction.relaxDay:
        if (command.targetDay == null) {
          errors.add('$prefix：放鬆行程時必須指定日期。');
        }

      case ItineraryEditAction.changeTravelMode:
        _requireExistingPlace(
          command.placeName,
          prefix,
          itineraryPlaceNames,
          errors,
        );

        _requireExistingPlace(
          command.destinationPlaceName,
          '$prefix的目的地',
          itineraryPlaceNames,
          errors,
        );

        const supportedModes = {'transit', 'walking', 'driving'};

        if (!supportedModes.contains(command.travelMode)) {
          errors.add('$prefix：不支援指定的交通方式。');
        }

      case ItineraryEditAction.unknown:
        break;
    }
  }

  void _requireExistingPlace(
    String? placeName,
    String prefix,
    Set<String> itineraryPlaceNames,
    List<String> errors,
  ) {
    if (_isBlank(placeName)) {
      errors.add('$prefix：缺少景點名稱。');
      return;
    }

    final normalizedName = _normalizeName(placeName!);

    if (!itineraryPlaceNames.contains(normalizedName)) {
      errors.add('$prefix：目前行程中找不到「$placeName」。');
    }
  }

  bool _isBlank(String? value) {
    return value == null || value.trim().isEmpty;
  }

  String _normalizeName(String value) {
    return value.trim().toLowerCase();
  }
}
