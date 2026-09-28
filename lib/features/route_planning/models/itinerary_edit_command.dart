enum ItineraryEditAction {
  movePlace,
  removePlace,
  addPlace,
  replacePlace,
  changeDuration,
  lockPlace,
  unlockPlace,
  relaxDay,
  changeTravelMode,
  unknown,
}

class ItineraryEditCommand {
  final ItineraryEditAction action;

  /// 要修改的既有景點名稱。
  ///
  /// addPlace 或 relaxDay 時可能是 null。
  final String? placeName;

  /// 新增或替換景點時的搜尋文字。
  ///
  /// 例如：「台北101」、「室內景點」、「附近的咖啡廳」。
  final String? placeQuery;

  /// 目標日期，從 1 開始。
  final int? targetDay;

  /// 當日開始時間，以凌晨 00:00 起算的分鐘表示。
  ///
  /// 例如 14:30 = 870。
  final int? targetStartMinutes;

  /// 修改後的停留時間。
  final int? durationMinutes;

  /// changeTravelMode 使用的目的地景點。
  final String? destinationPlaceName;

  /// 例如 transit、walking、driving。
  final String? travelMode;

  /// AI 對這次修改的簡短說明。
  final String? reason;

  const ItineraryEditCommand({
    required this.action,
    this.placeName,
    this.placeQuery,
    this.targetDay,
    this.targetStartMinutes,
    this.durationMinutes,
    this.destinationPlaceName,
    this.travelMode,
    this.reason,
  });

  factory ItineraryEditCommand.fromJson(Map<String, dynamic> json) {
    return ItineraryEditCommand(
      action: _parseAction(json['action']),
      placeName: _readString(json['placeName']),
      placeQuery: _readString(json['placeQuery']),
      targetDay: _readInt(json['targetDay']),
      targetStartMinutes: _readInt(json['targetStartMinutes']),
      durationMinutes: _readInt(json['durationMinutes']),
      destinationPlaceName: _readString(json['destinationPlaceName']),
      travelMode: _readString(json['travelMode']),
      reason: _readString(json['reason']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action.name,
      'placeName': placeName,
      'placeQuery': placeQuery,
      'targetDay': targetDay,
      'targetStartMinutes': targetStartMinutes,
      'durationMinutes': durationMinutes,
      'destinationPlaceName': destinationPlaceName,
      'travelMode': travelMode,
      'reason': reason,
    };
  }

  static ItineraryEditAction _parseAction(dynamic value) {
    if (value is! String) {
      return ItineraryEditAction.unknown;
    }

    return ItineraryEditAction.values.firstWhere(
      (action) => action.name == value,
      orElse: () => ItineraryEditAction.unknown,
    );
  }

  static String? _readString(dynamic value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }
}
