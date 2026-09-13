import 'trip_place_constraint.dart';
import 'travel_preference.dart';

class TripRequest {
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String location;
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
    required this.location,
    required this.people,
    required this.budget_level,
    required this.preferences, //使用者透過按鈕或標籤選擇的偏好
    required this.aiPrompt, // 使用者輸入的原始自然語言
    this.parsedPreference, // Gemini 將 aiPrompt 解析後產生的結構化偏好
    this.selectedPlaces = const [],
  });

  // 旅遊天數
  int get days {
    return endDate.difference(startDate).inDays + 1;
  }
}
