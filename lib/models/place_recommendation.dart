import 'place.dart';

class PlaceRecommendation {
  final Place place;

  final double totalScore;
  final double categoryScore;
  final double tagScore;
  final double ratingScore;
  final double priceScore;
  final double distanceScore;
  final double? distanceKm;

  final Set<String> matchedTags;
  final List<String> reasons;

  const PlaceRecommendation({
    required this.place,
    required this.totalScore,
    required this.categoryScore,
    required this.tagScore,
    required this.ratingScore,
    required this.priceScore,
    required this.distanceScore,
    required this.distanceKm,
    required this.matchedTags,
    required this.reasons,
  });
}
