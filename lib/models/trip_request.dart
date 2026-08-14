import 'trip_place_constraint.dart';

class TripRequest {
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String location;
  final int people;
  final double budget;
  final List<String> preferences;
  final String aiPrompt;
  final List<TripPlaceConstraint> selectedPlaces;

  TripRequest({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.people,
    required this.budget,
    required this.preferences,
    required this.aiPrompt,
    this.selectedPlaces = const [],
  });

  // 旅遊天數
  int get days {
    return endDate.difference(startDate).inDays + 1;
  }
}
