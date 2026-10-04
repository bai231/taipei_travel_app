import 'dart:math';

import '../../models/place.dart';
import '../../models/place_recommendation.dart';
import '../../models/recommendation_criteria.dart';

class PlaceRecommendationService {
  const PlaceRecommendationService();

  /// 對候選景點進行評分與排序。
  ///
  /// manuallySelectedPlaces：
  /// 使用者自行加入行程的景點。
  /// 若有提供，推薦系統會考慮候選景點與這些景點之間的距離。
  List<PlaceRecommendation> rank({
    required Iterable<Place> candidates,
    required RecommendationCriteria criteria,
    Iterable<Place> manuallySelectedPlaces = const [],
  }) {
    final selectedPlaces = manuallySelectedPlaces.toList();

    final recommendations = candidates.map((place) {
      return _scorePlace(
        place: place,
        criteria: criteria,
        manuallySelectedPlaces: selectedPlaces,
      );
    }).toList();

    recommendations.sort((a, b) {
      final scoreComparison = b.totalScore.compareTo(a.totalScore);

      if (scoreComparison != 0) {
        return scoreComparison;
      }

      // 總分相同時，優先比較 rating。
      final ratingComparison = b.place.rating.compareTo(a.place.rating);

      if (ratingComparison != 0) {
        return ratingComparison;
      }

      // rating 也相同時，再依名稱排序。
      return a.place.name.compareTo(b.place.name);
    });

    return recommendations;
  }

  /// 計算單一景點的推薦分數。
  PlaceRecommendation _scorePlace({
    required Place place,
    required RecommendationCriteria criteria,
    required List<Place> manuallySelectedPlaces,
  }) {
    final reasons = <String>[];

    // ============================================================
    // 1. 景點類型
    // 原始最高 40 分，最後換算成最高 30 分。
    // ============================================================

    final categoryRawScore = _calculateCategoryScore(
      place: place,
      criteria: criteria,
      reasons: reasons,
    );

    final categoryScore = categoryRawScore * 0.75; // 40 -> 30

    // ============================================================
    // 2. Tag 偏好
    // 原始最高 40 分，最後換算成最高 30 分。
    // ============================================================

    final matchedTags = _findMatchedTags(
      place: place,
      preferredTags: criteria.preferredTags,
    );

    final tagRawScore = min(matchedTags.length * 12.0, 40.0);

    final tagScore = tagRawScore * 0.75; // 40 -> 30

    if (matchedTags.isNotEmpty) {
      reasons.add('符合偏好：${matchedTags.join('、')}');
    }

    // ============================================================
    // 3. Rating
    // 最高 15 分。
    // ============================================================

    final ratingScore = _calculateRatingScore(place.rating);

    if (place.rating > 0) {
      reasons.add('景點評分 ${place.rating.toStringAsFixed(1)}');
    }

    // ============================================================
    // 4. 價格
    // 原始最高 20 分，最後換算成最高 10 分。
    // ============================================================

    final priceRawScore = _calculatePriceScore(
      placePriceLevel: place.price_level,
      preferredBudgetLevel: criteria.budgetLevel,
    );

    final priceScore = priceRawScore * 0.5; // 20 -> 10

    final priceReason = _buildPriceReason(
      placePriceLevel: place.price_level,
      preferredBudgetLevel: criteria.budgetLevel,
    );

    if (priceReason != null) {
      reasons.add(priceReason);
    }

    // ============================================================
    // 5. 距離
    // 找候選景點與所有「使用者手動選擇景點」中最近的距離。
    // 最高 15 分。
    // ============================================================

    final nearestDistanceKm = _calculateNearestDistanceKm(
      place: place,
      selectedPlaces: manuallySelectedPlaces,
    );

    final distanceScore = _calculateDistanceScore(nearestDistanceKm);

    if (nearestDistanceKm != null) {
      reasons.add(
        '距離已選景點約 '
        '${nearestDistanceKm.toStringAsFixed(1)} 公里',
      );
    }

    // ============================================================
    // 6. 總分
    //
    // Category : 30
    // Tag      : 30
    // Price    : 10
    // Rating   : 15
    // Distance : 15
    //
    // Total    : 100
    // ============================================================

    final totalScore =
        categoryScore + tagScore + priceScore + ratingScore + distanceScore;

    if (reasons.isEmpty) {
      reasons.add('符合基本旅遊條件');
    }

    return PlaceRecommendation(
      place: place,
      totalScore: totalScore.clamp(0, 100).toDouble(),

      categoryScore: categoryScore,
      tagScore: tagScore,
      priceScore: priceScore,
      ratingScore: ratingScore,

      distanceScore: distanceScore,
      distanceKm: nearestDistanceKm,

      matchedTags: Set.unmodifiable(matchedTags),
      reasons: List.unmodifiable(reasons),
    );
  }

  // ==============================================================
  // Category
  // ==============================================================

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

  // ==============================================================
  // Tags
  // ==============================================================

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

  // ==============================================================
  // Rating
  // ==============================================================

  double _calculateRatingScore(double rating) {
    if (rating <= 0) {
      return 0;
    }

    final normalizedRating = rating.clamp(0, 5).toDouble();

    // 5 星 = 15 分
    return normalizedRating / 5 * 15;
  }

  // ==============================================================
  // Price
  // ==============================================================

  double _calculatePriceScore({
    required int placePriceLevel,
    required int preferredBudgetLevel,
  }) {
    // 價格未知時保留候選資格，
    // 但只提供中立分數。
    if (placePriceLevel <= 0) {
      return 8;
    }

    // 理論上超出預算的景點應該已經由
    // CandidateFilter 排除。
    if (placePriceLevel > preferredBudgetLevel) {
      return 0;
    }

    // 在預算內給予基礎分數，
    // 越低於預算上限分數越高。
    final savedLevels = preferredBudgetLevel - placePriceLevel;

    return min(20.0, 16.0 + savedLevels);
  }

  String? _buildPriceReason({
    required int placePriceLevel,
    required int preferredBudgetLevel,
  }) {
    // 價格未知不作為推薦理由。
    if (placePriceLevel <= 0) {
      return null;
    }

    // 超出預算不提供正面理由。
    if (placePriceLevel > preferredBudgetLevel) {
      return null;
    }

    final savedLevels = preferredBudgetLevel - placePriceLevel;

    if (savedLevels >= 2) {
      return '價格較經濟，低於你的預算等級';
    }

    return '價格符合你的預算範圍';
  }

  // ==============================================================
  // Distance
  // ==============================================================

  /// 找到候選景點與「最近一個手動選擇景點」的距離。
  ///
  /// 若使用者尚未手動選擇任何景點，
  /// 則回傳 null。
  double? _calculateNearestDistanceKm({
    required Place place,
    required List<Place> selectedPlaces,
  }) {
    if (selectedPlaces.isEmpty) {
      return null;
    }

    double nearestDistance = double.infinity;

    for (final selected in selectedPlaces) {
      final distance = _calculateDistanceKm(
        place.latitude,
        place.longitude,
        selected.latitude,
        selected.longitude,
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
      }
    }

    return nearestDistance;
  }

  /// 將距離轉成推薦分數。
  ///
  /// <= 1 km : 15
  /// <= 3 km : 12
  /// <= 5 km : 9
  /// <= 8 km : 5
  /// > 8 km  : 0
  double _calculateDistanceScore(double? distanceKm) {
    // 沒有手動選擇的景點時，
    // 不使用距離作為推薦依據。
    if (distanceKm == null) {
      return 0;
    }

    if (distanceKm <= 1) {
      return 15;
    }

    if (distanceKm <= 3) {
      return 12;
    }

    if (distanceKm <= 5) {
      return 9;
    }

    if (distanceKm <= 8) {
      return 5;
    }

    return 0;
  }

  /// 使用 Haversine Formula
  /// 計算兩組經緯度之間的直線距離。
  ///
  /// 回傳單位：公里。
  double _calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;

    final dLat = _toRadians(lat2 - lat1);

    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  // ==============================================================
  // Common
  // ==============================================================

  String _normalize(String value) {
    return value.trim().replaceAll('臺', '台').toLowerCase();
  }
}
