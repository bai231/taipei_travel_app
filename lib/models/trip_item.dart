import 'place.dart';

class TripItem {
  final Place place;

  final int day;

  final int startMinutes;

  final int endMinutes;

  TripItem({
    required this.place,
    required this.day,
    required this.startMinutes,
    required this.endMinutes,
  });
}
