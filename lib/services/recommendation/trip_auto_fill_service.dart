import 'dart:math';

import '../../models/place.dart';
import '../../models/place_recommendation.dart';
import '../../models/trip_auto_fill_plan.dart';

class TripAutoFillService {
  const TripAutoFillService();

  TripAutoFillPlan createPlan({
    required int days,
    required String pace,
    required Iterable<Place> selectedAttractions,
    required Iterable<PlaceRecommendation> rankedRecommendations,
  }) {
    final normalizedDays = max(days, 1);

    final targetCount = normalizedDays * _placesPerDay(pace);

    final selectedIds = selectedAttractions.map((place) => place.id).toSet();

    final currentCount = selectedIds.length;

    final missingCount = max(targetCount - currentCount, 0);

    if (missingCount == 0) {
      return TripAutoFillPlan(
        targetAttractionCount: targetCount,
        currentAttractionCount: currentCount,
        placesToAdd: const [],
      );
    }

    final placesToAdd = <Place>[];
    final addedIds = <String>{};

    for (final recommendation in rankedRecommendations) {
      final place = recommendation.place;

      // 不重複加入使用者已選或必去的景點。
      if (selectedIds.contains(place.id)) {
        continue;
      }

      // 防止推薦清單本身含有重複 ID。
      if (!addedIds.add(place.id)) {
        continue;
      }

      placesToAdd.add(place);

      if (placesToAdd.length >= missingCount) {
        break;
      }
    }

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
