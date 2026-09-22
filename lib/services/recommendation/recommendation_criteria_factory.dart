import '../../models/recommendation_criteria.dart';
import '../../models/trip_request.dart';
import 'travel_preference_mapping.dart';

class RecommendationCriteriaFactory {
  RecommendationCriteriaFactory._();

  static RecommendationCriteria fromTripRequest(TripRequest request) {
    final preferredCategories = <String>{};
    final preferredTags = <String>{};
    final excludedCategories = <String>{};
    final excludedTags = <String>{};

    // =========================================================
    // 1. 處理使用者手動選擇的偏好
    // =========================================================

    for (final manualPreference in request.preferences) {
      final normalizedPreference = manualPreference.trim();

      if (normalizedPreference.isEmpty) {
        continue;
      }

      final categoryKeys =
          TravelPreferenceMapping.manualCategoryKeys[normalizedPreference] ??
          const <String>{};

      for (final categoryKey in categoryKeys) {
        _addCategoryPreference(
          categoryKey: categoryKey,
          categories: preferredCategories,
          tags: preferredTags,
        );
      }

      final mappedTags =
          TravelPreferenceMapping.manualTags[normalizedPreference] ??
          const <String>{};

      preferredTags.addAll(mappedTags);
    }

    // =========================================================
    // 2. 處理 Gemini 解析結果
    // =========================================================

    final aiPreference = request.parsedPreference;

    if (aiPreference != null) {
      for (final categoryKey in aiPreference.preferredCategories) {
        _addCategoryPreference(
          categoryKey: categoryKey,
          categories: preferredCategories,
          tags: preferredTags,
        );
      }

      for (final rawTag in aiPreference.preferredTags) {
        preferredTags.addAll(_resolveTag(rawTag));
      }

      for (final categoryKey in aiPreference.excludedCategories) {
        final normalizedKey = categoryKey.trim().toLowerCase();

        _addCategoryPreference(
          categoryKey: normalizedKey,
          categories: excludedCategories,
          tags: excludedTags,
        );

        final coveredTags =
            TravelPreferenceMapping.tagsCoveredByCategoryKey[normalizedKey] ??
            const <String>{};

        excludedTags.addAll(coveredTags);
      }

      for (final rawTag in aiPreference.excludedTags) {
        excludedTags.addAll(_resolveTag(rawTag));
      }
    }

    // =========================================================
    // 3. 排除條件優先
    // =========================================================

    preferredCategories.removeAll(excludedCategories);
    preferredTags.removeAll(excludedTags);

    // =========================================================
    // 4. 建立統一推薦條件
    // =========================================================

    return RecommendationCriteria(
      preferredCategories: Set.unmodifiable(preferredCategories),
      preferredTags: Set.unmodifiable(preferredTags),
      excludedCategories: Set.unmodifiable(excludedCategories),
      excludedTags: Set.unmodifiable(excludedTags),
      mustVisitPlaceNames: Set.unmodifiable(
        _normalizeTerms(aiPreference?.mustVisitPlaceNames ?? const <String>[]),
      ),
      location: request.location.trim(),
      budgetLevel: request.budget_level.clamp(1, 5),
      people: request.people,
      days: request.days,
      pace: aiPreference?.pace ?? 'balanced',
      walkingPreference: aiPreference?.walkingPreference ?? 'medium',
      statedDailyBudget: aiPreference?.dailyBudget,
      specialRequirements: Set.unmodifiable(
        _resolveTags(aiPreference?.specialRequirements ?? const <String>[]),
      ),
    );
  }

  /// 將 Gemini 的標準 category key 展開成：
  ///
  /// 1. 資料庫的 category
  /// 2. 需要補充的 tag 或搜尋關鍵字
  static void _addCategoryPreference({
    required String categoryKey,
    required Set<String> categories,
    required Set<String> tags,
  }) {
    final normalizedKey = categoryKey.trim().toLowerCase();

    if (normalizedKey.isEmpty) {
      return;
    }

    final mappedCategories =
        TravelPreferenceMapping.databaseCategoriesByKey[normalizedKey] ??
        const <String>{};

    final mappedSearchTerms =
        TravelPreferenceMapping.searchTermsByCategoryKey[normalizedKey] ??
        const <String>{};

    categories.addAll(mappedCategories);
    tags.addAll(mappedSearchTerms);
  }

  /// 將單一自由文字 tag 轉換成資料庫使用的 tag。
  ///
  /// 如果沒有對應別名，就保留原始文字。
  static Set<String> _resolveTag(String rawTag) {
    final normalizedTag = rawTag.trim();

    if (normalizedTag.isEmpty) {
      return <String>{};
    }

    final mappedTags = TravelPreferenceMapping.tagAliases[normalizedTag];

    if (mappedTags != null && mappedTags.isNotEmpty) {
      return Set<String>.from(mappedTags);
    }

    return {normalizedTag};
  }

  /// 一次轉換多個 tag 或特殊需求。
  static Set<String> _resolveTags(Iterable<String> rawTags) {
    final result = <String>{};

    for (final rawTag in rawTags) {
      result.addAll(_resolveTag(rawTag));
    }

    return result;
  }

  /// 清除空字串並自動去除重複項目。
  static Set<String> _normalizeTerms(Iterable<String> terms) {
    return terms
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty)
        .toSet();
  }
}
