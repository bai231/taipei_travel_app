import '../models/place.dart';

/// Display-only ranking. Scores are supplied by the caller, not Place.rating.
/// Finite scores descend; ties and unscored items preserve input order.
List<Place> rankPlannerCandidates(
  List<Place> places, {
  Map<String, num> scoresByPlaceId = const {},
}) {
  num? score(Place place) {
    final value = scoresByPlaceId[place.id];
    return value != null && value.isFinite ? value : null;
  }

  final indexed = places.asMap().entries.toList();
  indexed.sort((a, b) {
    final left = score(a.value);
    final right = score(b.value);
    if (left == null && right != null) return 1;
    if (left != null && right == null) return -1;
    final comparison = left == null || right == null
        ? 0
        : right.compareTo(left);
    return comparison != 0 ? comparison : a.key.compareTo(b.key);
  });
  return indexed.map((entry) => entry.value).toList();
}
