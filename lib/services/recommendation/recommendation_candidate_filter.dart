import '../../models/place.dart';
import '../../models/recommendation_criteria.dart';
import '../place_service.dart';

class RecommendationCandidateFilter {
  RecommendationCandidateFilter._();

  static List<Place> filter({
    required Iterable<Place> places,
    required RecommendationCriteria criteria,
  }) {
    return places.where((place) {
      return isEligible(place: place, criteria: criteria);
    }).toList();
  }

  static bool isEligible({
    required Place place,
    required RecommendationCriteria criteria,
  }) {
    // 目前推薦階段只處理景點。
    // 餐廳與住宿之後會有各自的推薦條件。
    if (place.type != PlaceType.attraction) {
      return false;
    }

    // 沒有有效座標的景點無法參與後續路線安排。
    if (!PlaceService.hasUsableCoordinates(place)) {
      return false;
    }

    // 全台不需要限制縣市。
    if (!_isAllTaiwan(criteria.location)) {
      final placeCounty = PlaceService.countyFor(place);

      if (placeCounty != _normalizeTaiwanText(criteria.location)) {
        return false;
      }
    }

    // 排除整個景點 category。
    if (_isExcludedCategory(place: place, criteria: criteria)) {
      return false;
    }

    // 排除特定活動或景點特徵。
    if (_containsExcludedTerm(place: place, criteria: criteria)) {
      return false;
    }

    // price_level = 0 代表價格未知，先保留。
    //
    // 只有明確知道價格等級，而且超出使用者接受範圍時才排除。
    if (place.price_level > 0 && place.price_level > criteria.budgetLevel) {
      return false;
    }

    return true;
  }

  static bool _isExcludedCategory({
    required Place place,
    required RecommendationCriteria criteria,
  }) {
    final placeCategory = place.category.trim();

    return criteria.excludedCategories.any(
      (excludedCategory) => excludedCategory.trim() == placeCategory,
    );
  }

  static bool _containsExcludedTerm({
    required Place place,
    required RecommendationCriteria criteria,
  }) {
    if (criteria.excludedTags.isEmpty) {
      return false;
    }

    final searchableText = _normalizeSearchText(
      [place.name, place.category, place.description, ...place.tags].join(' '),
    );

    return criteria.excludedTags.any((excludedTag) {
      final normalizedTag = _normalizeSearchText(excludedTag);

      if (normalizedTag.isEmpty) {
        return false;
      }

      return searchableText.contains(normalizedTag);
    });
  }

  static bool _isAllTaiwan(String location) {
    final normalized = _normalizeTaiwanText(location);

    return normalized.isEmpty || normalized == '全台' || normalized == '台灣';
  }

  static String _normalizeTaiwanText(String value) {
    return value.trim().replaceAll('臺', '台');
  }

  static String _normalizeSearchText(String value) {
    return _normalizeTaiwanText(value).toLowerCase();
  }
}
