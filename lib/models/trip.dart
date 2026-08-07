import 'place.dart';

class Trip {
  final String id;

  String name;

  List<Place> places;

  String note;

  String coverImage;

  DateTime createdTime;

  int totalStayMinutes;

  Trip({
    required this.id,
    required this.name,
    required this.places,
    required this.note,
    required this.coverImage,
    required this.createdTime,
    required this.totalStayMinutes,
  });
}
