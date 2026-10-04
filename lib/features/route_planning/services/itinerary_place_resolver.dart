import '../../../models/place.dart';
import '../../../services/place_service.dart';
import 'itinerary_place_query_mapper.dart';

class ItineraryPlaceMatch {
  final Place place;
  final double score;
  final String reason;

  const ItineraryPlaceMatch({
    required this.place,
    required this.score,
    required this.reason,
  });
}

class ItineraryPlaceResolver {
  final ItineraryPlaceQueryMapper _queryMapper;

  const ItineraryPlaceResolver({
    ItineraryPlaceQueryMapper queryMapper = const ItineraryPlaceQueryMapper(),
  }) : _queryMapper = queryMapper;

  List<ItineraryPlaceMatch> search({
    required String query,
    required Iterable<Place> places,
    required Set<String> excludedPlaceIds,
    List<String> preferredLocations = const [],
    // 保留較寬的初步候選池，再由 ranker 依距離、評分、
    // 多樣性與預算排序，避免「自然景點」這類查詢過早淘汰好候選。
    int limit = 50,
    Map<String, num> recommendationScoresByPlaceId = const {},
  }) {
    final normalizedQuery = _normalize(query);

    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final mappedQuery = _queryMapper.map(query);

    final mappedCategories = mappedQuery.categories.map(_normalize).toSet();

    final mappedTags = mappedQuery.tags.map(_normalize).toSet();

    final mappedLocations = mappedQuery.locations.map(_normalize).toSet();

    final matches = <ItineraryPlaceMatch>[];

    for (final place in places) {
      if (excludedPlaceIds.contains(place.id)) {
        continue;
      }

      if (!PlaceService.hasUsableCoordinates(place)) {
        continue;
      }

      final name = _normalize(place.name);

      final searchable = _normalize(
        [place.name, place.category, place.address, ...place.tags].join(' '),
      );

      final placeCategory = _normalize(place.category);

      final placeTags = place.tags.map(_normalize).toSet();

      final placeCounty = _normalize(PlaceService.countyFor(place));

      final locationMatched = mappedLocations.contains(placeCounty);

      // 使用者有明確說出縣市時，將該縣市當成必要條件，
      // 例如「新北市的景點」不應回傳台北或其他縣市。
      if (mappedLocations.isNotEmpty && !locationMatched) {
        continue;
      }

      final categoryMatched = mappedCategories.contains(placeCategory);

      final matchedTags = placeTags.intersection(mappedTags);

      double score;
      String reason;

      if (name == normalizedQuery) {
        score = 100;
        reason = '景點名稱完全符合';
      } else if (name.contains(normalizedQuery)) {
        score = 80;
        reason = '景點名稱包含搜尋文字';
      } else if (normalizedQuery.contains(name) && name.length >= 2) {
        score = 70;
        reason = '使用者輸入包含景點名稱';
      } else if (categoryMatched || matchedTags.isNotEmpty) {
        score = 50;

        final reasons = <String>[];

        if (categoryMatched) {
          score += 15;
          reasons.add('分類符合 ${place.category}');
        }

        if (matchedTags.isNotEmpty) {
          final matchedTagCount = matchedTags.length > 3
              ? 3
              : matchedTags.length;

          score += matchedTagCount * 5;

          reasons.add('標籤符合 ${matchedTags.join('、')}');
        }

        reason = reasons.join('，');
      } else if (locationMatched) {
        score = 50;
        reason = '位於${PlaceService.countyFor(place)}';
      } else if (searchable.contains(normalizedQuery)) {
        score = 45;
        reason = '景點資料包含搜尋文字';
      } else {
        continue;
      }

      final normalizedPreferredLocations = preferredLocations
          .map(_normalize)
          .where((location) => location.isNotEmpty)
          .toSet();

      if (normalizedPreferredLocations.isNotEmpty &&
          !normalizedPreferredLocations.contains('全台') &&
          !normalizedPreferredLocations.contains('台灣') &&
          normalizedPreferredLocations.contains(placeCounty)) {
        score += 15;
        reason = '$reason，且位於旅遊範圍內';
      }

      final recommendationScore = recommendationScoresByPlaceId[place.id];

      if (recommendationScore != null) {
        final normalizedRecommendationScore = recommendationScore
            .toDouble()
            .clamp(0, 100);

        // 原始推薦分數為 0～100，
        // 在 AI 新增景點排序中最多貢獻 25 分。
        final recommendationBonus = normalizedRecommendationScore * 0.25;

        score += recommendationBonus;

        reason =
            '$reason，偏好推薦分數 '
            '${normalizedRecommendationScore.toStringAsFixed(0)}';
      }

      matches.add(
        ItineraryPlaceMatch(place: place, score: score, reason: reason),
      );
    }

    matches.sort((first, second) {
      final scoreComparison = second.score.compareTo(first.score);

      if (scoreComparison != 0) {
        return scoreComparison;
      }

      return first.place.name.compareTo(second.place.name);
    });

    return matches.take(limit).toList();
  }

  String _normalize(String value) {
    return value
        .trim()
        .replaceAll('臺', '台')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '');
  }
}
