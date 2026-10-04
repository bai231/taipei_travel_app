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
    required this.preferences, //使用者透過按鈕或標籤選擇的偏好
    required this.aiPrompt, // 使用者輸入的原始自然語言
    this.parsedPreference, // Gemini 將 aiPrompt 解析後產生的結構化偏好
    this.selectedPlaces = const [],
  }) : locations = _normalizeLocations(locations, location);

  /// 舊流程相容欄位。
  ///
  /// 單一縣市時回傳該縣市；多縣市時回傳「全台」，避免仍只接受
  /// String location 的舊模組誤把「台北市、新北市」當成一個不存在的縣市。
  String get location => locations.length == 1 ? locations.first : '全台';

  /// 適合直接顯示給使用者的地區文字。
  String get locationLabel => locations.join('、');

  // 旅遊天數
  int get days {
    return endDate.difference(startDate).inDays + 1;
  }

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
