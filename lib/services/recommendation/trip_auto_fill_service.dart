import 'dart:math';

import '../../models/place.dart';
import '../../models/place_recommendation.dart';
import '../../models/trip_auto_fill_plan.dart';
import 'recommendation_diversifier.dart';

class TripAutoFillService {
  final RecommendationDiversifier _diversifier;

  const TripAutoFillService({
    RecommendationDiversifier diversifier = const RecommendationDiversifier(),
  }) : _diversifier = diversifier;

  TripAutoFillPlan createPlan({
    required int days,
    required String pace,
    required Iterable<Place> selectedAttractions,
    required Iterable<PlaceRecommendation> rankedRecommendations,
  }) {
    final normalizedDays = max(days, 1);

    final targetCount = normalizedDays * _placesPerDay(pace);

    final selectedAttractionList = selectedAttractions.toList();

    final selectedIds = selectedAttractionList.map((place) => place.id).toSet();

    final currentCount = selectedIds.length;

    final missingCount = max(targetCount - currentCount, 0);

    if (missingCount == 0) {
      return TripAutoFillPlan(
        targetAttractionCount: targetCount,
        currentAttractionCount: currentCount,
        placesToAdd: const [],
      );
    }

    final diversifiedRecommendations = _diversifier.select(
      rankedRecommendations: rankedRecommendations,
      selectedAttractions: selectedAttractionList,
      count: missingCount,
    );

    final placesToAdd = diversifiedRecommendations
        .map((recommendation) => recommendation.place)
        .toList();

    return TripAutoFillPlan(
      targetAttractionCount: targetCount,
      currentAttractionCount: currentCount,
      placesToAdd: List.unmodifiable(placesToAdd),
    );
  }

  int _placesPerDay(String pace) {
    return switch (pace.trim().toLowerCase()) {
      'relaxed' => 2,
      'intensive' => 4,
      _ => 3,
    };
  }
}
