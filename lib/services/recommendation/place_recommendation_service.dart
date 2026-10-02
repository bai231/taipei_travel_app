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

    final tagScore = min(matchedTags.length * 12.0, 40.0);

    if (matchedTags.isNotEmpty) {
      reasons.add('符合偏好：${matchedTags.join('、')}');
    }

    //final ratingScore = _calculateRatingScore(place.rating);

    if (place.rating > 0) {
      reasons.add('景點評分 ${place.rating.toStringAsFixed(1)}');
    }

    final priceScore = _calculatePriceScore(
      placePriceLevel: place.price_level,
      preferredBudgetLevel: criteria.budgetLevel,
    );

    final priceReason = _buildPriceReason(
      placePriceLevel: place.price_level,
      preferredBudgetLevel: criteria.budgetLevel,
    );

    if (priceReason != null) {
      reasons.add(priceReason);
    }

    final totalScore = categoryScore + tagScore + priceScore;

    if (reasons.isEmpty) {
      reasons.add('符合基本旅遊條件');
    }

    return PlaceRecommendation(
      place: place,
      totalScore: totalScore.clamp(0, 100).toDouble(),
      categoryScore: categoryScore,
      tagScore: tagScore,
      //ratingScore: ratingScore,
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
    // 價格未知時保留候選資格，但只給中立分數。
    if (placePriceLevel <= 0) {
      return 8;
    }

    // 理論上超出預算的景點已在 CandidateFilter 被排除。
    // 這裡仍保留防護，避免服務被單獨呼叫時給出錯誤分數。
    if (placePriceLevel > preferredBudgetLevel) {
      return 0;
    }

    // 在預算範圍內都視為符合，基礎分數為 8 分。
    // 比最高可接受價格更便宜時，依節省幅度增加分數，
    // 最高不超過 10 分。
    final savedLevels = preferredBudgetLevel - placePriceLevel;

    return min(20.0, 16.0 + savedLevels);
  }

  String? _buildPriceReason({
    required int placePriceLevel,
    required int preferredBudgetLevel,
  }) {
    // 價格未知不應該被當成推薦理由。
    if (placePriceLevel <= 0) {
      return null;
    }

    // 超出預算不提供正面的推薦理由。
    // 正常情況下，這類景點已在候選篩選階段被排除。
    if (placePriceLevel > preferredBudgetLevel) {
      return null;
    }

    final savedLevels = preferredBudgetLevel - placePriceLevel;

    if (savedLevels >= 2) {
      return '價格較經濟，低於你的預算等級';
    }

    return '價格符合你的預算範圍';
  }

  String _normalize(String value) {
    return value.trim().replaceAll('臺', '台').toLowerCase();
  }
}
