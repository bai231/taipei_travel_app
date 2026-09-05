import '../../../models/place.dart';
import '../../../models/visit_preferences.dart';

class RouteVisit {
  final Place place;
  final int sequence;
  final int arrivalMinutes;
  final int startMinutes;
  final int endMinutes;
  final int waitingMinutes;
  final int stayMinutes;
  final int? requestedStartMinutes;
  final bool locked;
  final String? eventId;
  final VisitKind kind;
  final VisitPreferences preferences;
  final MealType mealType;
  final List<String> information;

  String get occurrenceId => eventId ?? place.id;
  String get label => kind != VisitKind.activity
      ? '${place.name}・${kind.label}'
      : place.type == PlaceType.restaurant
      ? '${place.name}・${mealType.label}'
      : place.name;

  const RouteVisit({
    required this.place,
    required this.sequence,
    required this.arrivalMinutes,
    required this.startMinutes,
    required this.endMinutes,
    required this.waitingMinutes,
    required this.stayMinutes,
    required this.requestedStartMinutes,
    required this.locked,
    this.eventId,
    this.kind = VisitKind.activity,
    this.preferences = const VisitPreferences(),
    this.mealType = MealType.unspecified,
    this.information = const [],
  });
}
