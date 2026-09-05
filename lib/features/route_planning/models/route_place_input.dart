import '../../../models/place.dart';
import '../../../models/visit_preferences.dart';

class RoutePlaceInput {
  final Place place;
  final int? day;
  final int? startMinutes;
  final bool locked;
  final VisitPreferences preferences;
  final VisitKind kind;
  final MealType? suggestedMealType;

  String get occurrenceId =>
      kind == VisitKind.activity ? place.id : '${place.id}:${kind.name}:$day';
  MealType get effectiveMealType => preferences.mealType == MealType.unspecified
      ? suggestedMealType ?? MealType.unspecified
      : preferences.mealType;
  int get stayMinutes =>
      preferences.durationFor(place, suggestedMealType: suggestedMealType);

  const RoutePlaceInput({
    required this.place,
    this.day,
    this.startMinutes,
    this.locked = false,
    this.preferences = const VisitPreferences(),
    this.kind = VisitKind.activity,
    this.suggestedMealType,
  });
}
