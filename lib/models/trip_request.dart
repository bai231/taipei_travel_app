class TripRequest {
  final String title;
  final DateTime startDate;
  final DateTime endDate;

  final String location;

  final int people;

  final double budget;

  final List<String> preferences;

  TripRequest({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.people,
    required this.budget,
    required this.preferences,
  });

  int get days {
    return endDate.difference(startDate).inDays + 1;
  }
}
