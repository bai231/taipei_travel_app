import 'dart:math';

import '../../models/place.dart';
import '../../models/place_recommendation.dart';
import '../../models/recommendation_criteria.dart';

class PlaceRecommendationService {
  const PlaceRecommendationService();

  List<PlaceRecommendation> rank({
    required Iterable<Place> candidates,
    required RecommendationCriteria criteria,
  }) {
    final recommendations = candidates.map((place) {
      return _scorePlace(place: place, criteria: criteria);
    }).toList();

    recommendations.sort((a, b) {
      final scoreComparison = b.totalScore.compareTo(a.totalScore);

      if (scoreComparison != 0) {
        return scoreComparison;
      }

      // 總分相同時，優先使用原始 rating。
      //final ratingComparison = b.place.rating.compareTo(a.place.rating);

      //if (ratingComparison != 0) {
      //  return ratingComparison;
      //}

      return a.place.name.compareTo(b.place.name);
    });

    return recommendations;
  }

  PlaceRecommendation _scorePlace({
    required Place place,
    required RecommendationCriteria criteria,
  }) {
    final reasons = <String>[];

    final categoryScore = _calculateCategoryScore(
      place: place,
      criteria: criteria,
      reasons: reasons,
    );

    final matchedTags = _findMatchedTags(
      place: place,
      preferredTags: criteria.preferredTags,
    );

    final tagScore = min(matchedTags.length * 12.0, 35.0);

    if (matchedTags.isNotEmpty) {
      reasons.add('符合偏好：${matchedTags.join('、')}');
    }

    final ratingScore = _calculateRatingScore(place.rating);

    if (place.rating > 0) {
      reasons.add('景點評分 ${place.rating.toStringAsFixed(1)}');
    }

    final priceScore = _calculatePriceScore(
      placePriceLevel: place.price_level,
      preferredBudgetLevel: criteria.budgetLevel,
    );

    if (place.price_level > 0) {
      reasons.add('價格等級 ${place.price_level}');
    } else {
      reasons.add('價格資料未知');
    }

    final totalScore = categoryScore + tagScore + ratingScore + priceScore;

    if (reasons.isEmpty) {
      reasons.add('符合基本旅遊條件');
    }

    return PlaceRecommendation(
      place: place,
      totalScore: totalScore.clamp(0, 100).toDouble(),
      categoryScore: categoryScore,
      tagScore: tagScore,
      ratingScore: ratingScore,
      priceScore: priceScore,
      matchedTags: Set.unmodifiable(matchedTags),
      reasons: List.unmodifiable(reasons),
    );
  }

  double _calculateCategoryScore({
    required Place place,
    required RecommendationCriteria criteria,
    required List<String> reasons,
  }) {
    if (criteria.preferredCategories.isEmpty) {
      return 0;
    }

    final normalizedPlaceCategory = _normalize(place.category);

    final isMatched = criteria.preferredCategories.any((preferredCategory) {
      return _normalize(preferredCategory) == normalizedPlaceCategory;
    });

    if (!isMatched) {
      return 0;
    }

    reasons.add('符合景點類型：${place.category}');

    return 40;
  }

  Set<String> _findMatchedTags({
    required Place place,
    required Set<String> preferredTags,
  }) {
    if (preferredTags.isEmpty) {
      return <String>{};
    }

    final searchableText = _normalize(
      [place.name, place.category, place.description, ...place.tags].join(' '),
    );

    return preferredTags.where((tag) {
      final normalizedTag = _normalize(tag);

      return normalizedTag.isNotEmpty && searchableText.contains(normalizedTag);
    }).toSet();
  }

  double _calculateRatingScore(double rating) {
    if (rating <= 0) {
      return 0;
    }

    final normalizedRating = rating.clamp(0, 5).toDouble();

    return normalizedRating / 5 * 15;
  }

  double _calculatePriceScore({
    required int placePriceLevel,
    required int preferredBudgetLevel,
  }) {
    // 價格未知時給少量中立分數，
    // 避免未知資料比所有景點都差。
    if (placePriceLevel <= 0) {
      return 4;
    }

    final difference = (preferredBudgetLevel - placePriceLevel).abs();

    return max(0, 10 - difference * 2.5).toDouble();
  }

  String _normalize(String value) {
    return value.trim().replaceAll('臺', '台').toLowerCase();
  }
}
