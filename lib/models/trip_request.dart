import 'trip_place_constraint.dart';
import 'travel_preference.dart';

class TripRequest {
  final String title;
  final DateTime startDate;
  final DateTime endDate;

  /// 使用者選擇的旅遊縣市。第一版多縣市流程以此欄位為準。
  final List<String> locations;

  final int people;
  final int budget_level;
  final List<String> preferences;
  final String aiPrompt;
  final TravelPreference? parsedPreference;
  final List<TripPlaceConstraint> selectedPlaces;

  TripRequest({
    required this.title,
    required this.startDate,
    required this.endDate,
    List<String>? locations,
    String? location,
    required this.people,
    required this.budget_level,
    required this.preferences,
    required this.aiPrompt,
    this.parsedPreference,
    this.selectedPlaces = const [],
  }) : locations = _normalizeLocations(locations, location);

  /// 舊流程相容欄位。
  String get location => locations.length == 1 ? locations.first : '全台';

  /// 適合直接顯示給使用者的地區文字。
  String get locationLabel => locations.join('、');

  int get days => endDate.difference(startDate).inDays + 1;

  static List<String> _normalizeLocations(
    List<String>? locations,
    String? legacyLocation,
  ) {
    final values = <String>[
      if (locations != null) ...locations,
      if ((locations == null || locations.isEmpty) && legacyLocation != null)
        legacyLocation,
    ]
        .map((value) => value.trim().replaceAll('臺', '台'))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    return List.unmodifiable(values.isEmpty ? const ['全台'] : values);
  }
}
