import '../../../models/place.dart';

class RoutePlaceInput {
  final Place place;
  final int? day;
  final int? startMinutes;
  final bool locked;

  const RoutePlaceInput({
    required this.place,
    this.day,
    this.startMinutes,
    this.locked = false,
  });
}
