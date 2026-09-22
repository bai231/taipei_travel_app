import 'dart:math';

import '../../models/place.dart';
import '../../models/place_recommendation.dart';
import 'travel_preference_mapping.dart';

class RecommendationDiversifier {
  const RecommendationDiversifier();

  /// 從原始推薦排名中選出兼顧偏好分數與類型多樣性的景點。
  ///
  /// 這個服務只提供給「智慧補齊」使用，
  /// 不會改變景點選擇器顯示的原始推薦排名。
  List<PlaceRecommendation> select({
    required Iterable<PlaceRecommendation> rankedRecommendations,
    required Iterable<Place> selectedAttractions,
    required int count,
  }) {
    if (count <= 0) {
      return const [];
    }

    final selectedIds = selectedAttractions.map((place) => place.id).toSet();

    final candidateIds = <String>{};

    final allRemaining = rankedRecommendations.where((recommendation) {
      final placeId = recommendation.place.id;

      if (selectedIds.contains(placeId)) {
        return false;
      }

      // 防止推薦清單本身包含重複景點。
      return candidateIds.add(placeId);
    }).toList();

    final remaining = _buildAdaptivePool(
      recommendations: allRemaining,
      count: count,
    );

    if (remaining.isEmpty) {
      return const [];
    }

    final selectedRecommendations = <PlaceRecommendation>[];

    // 記錄已選景點中各主題出現的次數。
    final selectedThemeCounts = <String, int>{};

    // 記錄已經出現過的 tag。
    final selectedTags = <String>{};

    for (final place in selectedAttractions) {
      final theme = _themeFor(place);

      selectedThemeCounts[theme] = (selectedThemeCounts[theme] ?? 0) + 1;

      selectedTags.addAll(
        place.tags.map(_normalize).where((tag) => tag.isNotEmpty),
      );
    }

    while (remaining.isNotEmpty && selectedRecommendations.length < count) {
      PlaceRecommendation? bestRecommendation;
      double? bestAdjustedScore;
      int bestOriginalIndex = -1;

      // 如果使用者目前尚未選擇任何景點，
      // 第一個自動補齊景點固定使用原始推薦第一名。
      if (selectedRecommendations.isEmpty && selectedIds.isEmpty) {
        final firstRecommendation = remaining.removeAt(0);

        selectedRecommendations.add(firstRecommendation);

        final firstTheme = _themeFor(firstRecommendation.place);

        selectedThemeCounts[firstTheme] =
            (selectedThemeCounts[firstTheme] ?? 0) + 1;

        selectedTags.addAll(
          firstRecommendation.matchedTags
              .map(_normalize)
              .where((tag) => tag.isNotEmpty),
        );

        continue;
      }

      for (var index = 0; index < remaining.length; index++) {
        final recommendation = remaining[index];

        final adjustedScore = _calculateAdjustedScore(
          recommendation: recommendation,
          selectedThemeCounts: selectedThemeCounts,
          selectedTags: selectedTags,
        );

        final isBetter =
            bestAdjustedScore == null || adjustedScore > bestAdjustedScore;

        // 分數相同時，保留原始推薦排名較前面的景點。
        final isStableTie =
            bestAdjustedScore != null &&
            adjustedScore == bestAdjustedScore &&
            (bestOriginalIndex < 0 || index < bestOriginalIndex);

        if (isBetter || isStableTie) {
          bestRecommendation = recommendation;
          bestAdjustedScore = adjustedScore;
          bestOriginalIndex = index;
        }
      }

      if (bestRecommendation == null) {
        break;
      }

      selectedRecommendations.add(bestRecommendation);
      remaining.removeAt(bestOriginalIndex);

      final selectedPlace = bestRecommendation.place;
      final selectedTheme = _themeFor(selectedPlace);

      selectedThemeCounts[selectedTheme] =
          (selectedThemeCounts[selectedTheme] ?? 0) + 1;

      selectedTags.addAll(
        bestRecommendation.matchedTags
            .map(_normalize)
            .where((tag) => tag.isNotEmpty),
      );
    }

    return List.unmodifiable(selectedRecommendations);
  }

  List<PlaceRecommendation> _buildAdaptivePool({
    required List<PlaceRecommendation> recommendations,
    required int count,
  }) {
    if (recommendations.isEmpty || count <= 0) {
      return const [];
    }

    final highestScore = recommendations.first.totalScore;

    // 只保留至少達到最高分 60% 的景點，
    // 避免為了多樣性加入相關性過低的項目。
    final minimumRelevantScore = highestScore * 0.6;

    // 最多檢查原始排名前 100 名。
    final maximumSearchSize = min(recommendations.length, 100);

    final relevantRecommendations = recommendations
        .take(maximumSearchSize)
        .where(
          (recommendation) => recommendation.totalScore >= minimumRelevantScore,
        )
        .toList();

    // 如果符合 60% 門檻的景點不足以完成補齊，
    // 退回原始排名前段，確保智慧補齊仍能達到目標數量。
    if (relevantRecommendations.length < count) {
      return recommendations.take(min(count, recommendations.length)).toList();
    }

    // 希望候選池至少包含 3 種主題；
    // 如果要補的景點少於 3 個，就以補齊數量為準。
    final targetThemeCount = min(count, 3);

    // 初始候選池為需求數量的 5 倍。
    final expansionStep = max(count * 5, count);

    var poolSize = min(relevantRecommendations.length, expansionStep);

    while (true) {
      final currentPool = relevantRecommendations.take(poolSize).toList();

      final themeCount = _countDistinctThemes(currentPool);

      final hasEnoughThemes = themeCount >= targetThemeCount;

      final reachedMaximumPool = poolSize >= relevantRecommendations.length;

      if (hasEnoughThemes || reachedMaximumPool) {
        return currentPool;
      }

      // 類型不足時，再向後擴大 count × 5。
      poolSize = min(relevantRecommendations.length, poolSize + expansionStep);
    }
  }

  int _countDistinctThemes(Iterable<PlaceRecommendation> recommendations) {
    return recommendations
        .map((recommendation) {
          return _themeFor(recommendation.place);
        })
        .toSet()
        .length;
  }

  double _calculateAdjustedScore({
    required PlaceRecommendation recommendation,
    required Map<String, int> selectedThemeCounts,
    required Set<String> selectedTags,
  }) {
    final theme = _themeFor(recommendation.place);
    final repeatedThemeCount = selectedThemeCounts[theme] ?? 0;

    // 同一主題重複出現時扣分。
    //
    // 第一次重複扣 12 分，最多扣 24 分，
    // 避免整個行程都由相同主題組成。
    final themePenalty = min(repeatedThemeCount * 12.0, 24.0);

    final normalizedMatchedTags = recommendation.matchedTags
        .map(_normalize)
        .where((tag) => tag.isNotEmpty)
        .toSet();

    final repeatedTagCount = normalizedMatchedTags
        .intersection(selectedTags)
        .length;

    final newTagCount = normalizedMatchedTags.difference(selectedTags).length;

    // 重複偏好特徵最多扣 9 分。
    final repeatedTagPenalty = min(repeatedTagCount * 3.0, 9.0);

    // 帶入新特徵時最多加 6 分。
    final newTagBonus = min(newTagCount * 2.0, 6.0);

    return recommendation.totalScore -
        themePenalty -
        repeatedTagPenalty +
        newTagBonus;
  }

  /// 將資料庫 category 整合成較大的旅遊主題。
  ///
  /// 例如多種自然 category 都會被視為 nature，
  /// 避免自然風景區與國家公園被誤認為完全不同的類型。
  String _themeFor(Place place) {
    final normalizedCategory = _normalize(place.category);

    for (final entry
        in TravelPreferenceMapping.databaseCategoriesByKey.entries) {
      final containsCategory = entry.value.any(
        (category) => _normalize(category) == normalizedCategory,
      );

      if (containsCategory) {
        return entry.key;
      }
    }

    if (normalizedCategory.isNotEmpty) {
      return normalizedCategory;
    }

    // 沒有 category 的景點不要全部被視為同一類。
    return 'unknown:${place.id}';
  }

  String _normalize(String value) {
    return value.trim().replaceAll('臺', '台').toLowerCase();
  }
}
