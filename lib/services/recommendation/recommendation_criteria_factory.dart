import '../../models/recommendation_criteria.dart';
import '../../models/recommendation_criteria_build_result.dart';
import '../../models/recommendation_conflict.dart';
import '../../models/trip_request.dart';
import 'travel_preference_mapping.dart';

class RecommendationCriteriaFactory {
  RecommendationCriteriaFactory._();

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

  static String _categoryLabel(String categoryKey) {
    return switch (categoryKey.trim().toLowerCase()) {
      'nature' => '自然景點',
      'religious' => '宗教廟宇',
      'cultural' => '文化體驗',
      'heritage' => '歷史與文化資產',
      'art_venue' => '藝術與藝文場館',
      'farm' => '休閒農業',
      'museum' => '博物館',
      'tourism_factory' => '觀光工廠',
      'general_recreation' => '休閒遊憩',
      'old_street_market' => '老街、商圈與市場',
      'other' => '其他景點',
      _ => categoryKey,
    };
  }

  static RecommendationCriteria fromTripRequest(TripRequest request) {
    return build(request).criteria;
  }

  static RecommendationCriteriaBuildResult build(TripRequest request) {
    final preferredCategories = <String>{};
    final preferredTags = <String>{};
    final excludedCategories = <String>{};
    final excludedTags = <String>{};

    // 保留不同來源的條件，用於後續偵測衝突。
    final manualCategoryKeys = <String>{};
    final manualPreferredTags = <String>{};

    final aiPreferredCategoryKeys = <String>{};
    final aiExcludedCategoryKeys = <String>{};
    final aiPreferredTags = <String>{};
    final aiExcludedTags = <String>{};

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

      manualCategoryKeys.addAll(categoryKeys);

      for (final categoryKey in categoryKeys) {
        _addCategoryPreference(
          categoryKey: categoryKey,
          categories: preferredCategories,
          tags: preferredTags,
        );

        manualPreferredTags.addAll(
          TravelPreferenceMapping.searchTermsByCategoryKey[categoryKey] ??
              const <String>{},
        );
      }

      final mappedTags =
          TravelPreferenceMapping.manualTags[normalizedPreference] ??
          const <String>{};

      preferredTags.addAll(mappedTags);
      manualPreferredTags.addAll(mappedTags);
    }

    // =========================================================
    // 2. 處理 Gemini 解析結果
    // =========================================================

    final aiPreference = request.parsedPreference;

    if (aiPreference != null) {
      for (final categoryKey in aiPreference.preferredCategories) {
        final normalizedKey = categoryKey.trim().toLowerCase();

        if (normalizedKey.isEmpty) {
          continue;
        }

        aiPreferredCategoryKeys.add(normalizedKey);

        _addCategoryPreference(
          categoryKey: normalizedKey,
          categories: preferredCategories,
          tags: preferredTags,
        );

        aiPreferredTags.addAll(
          TravelPreferenceMapping.searchTermsByCategoryKey[normalizedKey] ??
              const <String>{},
        );
      }

      for (final rawTag in aiPreference.preferredTags) {
        final resolvedTags = _resolveTag(rawTag);

        preferredTags.addAll(resolvedTags);
        aiPreferredTags.addAll(resolvedTags);
      }

      for (final categoryKey in aiPreference.excludedCategories) {
        final normalizedKey = categoryKey.trim().toLowerCase();

        if (normalizedKey.isEmpty) {
          continue;
        }

        aiExcludedCategoryKeys.add(normalizedKey);

        _addCategoryPreference(
          categoryKey: normalizedKey,
          categories: excludedCategories,
          tags: excludedTags,
        );

        final coveredTags =
            TravelPreferenceMapping.tagsCoveredByCategoryKey[normalizedKey] ??
            const <String>{};

        excludedTags.addAll(coveredTags);
        aiExcludedTags.addAll(coveredTags);
      }

      for (final rawTag in aiPreference.excludedTags) {
        final resolvedTags = _resolveTag(rawTag);

        excludedTags.addAll(resolvedTags);
        aiExcludedTags.addAll(resolvedTags);
      }
    }

    // =========================================================
    // 3. 偵測喜好與排除條件的衝突
    // =========================================================

    final conflicts = <RecommendationConflict>[];

    // 手動選擇的 category 與 AI 排除 category 發生衝突，
    // 或 AI 自己同時將同一個 category 放入喜歡與排除。
    final conflictingCategoryKeys = <String>{
      ...manualCategoryKeys.intersection(aiExcludedCategoryKeys),
      ...aiPreferredCategoryKeys.intersection(aiExcludedCategoryKeys),
    };

    for (final categoryKey in conflictingCategoryKeys) {
      final label = _categoryLabel(categoryKey);

      conflicts.add(
        RecommendationConflict(
          type: RecommendationConflictType.category,
          term: categoryKey,
          message:
              '你同時表達了喜歡「$label」以及排除該類型，'
              '系統將以排除條件為優先。',
        ),
      );
    }

    // 手動 tag 或 AI 喜歡的 tag，和 AI 排除 tag 發生衝突。
    final conflictingTags = <String>{
      ...manualPreferredTags.intersection(aiExcludedTags),
      ...aiPreferredTags.intersection(aiExcludedTags),
    };

    // 如果已經記錄整個 category 衝突，避免再顯示該 category
    // 展開後的每一個 tag 衝突。
    for (final categoryKey in conflictingCategoryKeys) {
      conflictingTags.removeAll(
        TravelPreferenceMapping.tagsCoveredByCategoryKey[categoryKey] ??
            const <String>{},
      );

      conflictingTags.removeAll(
        TravelPreferenceMapping.searchTermsByCategoryKey[categoryKey] ??
            const <String>{},
      );
    }

    for (final tag in conflictingTags) {
      conflicts.add(
        RecommendationConflict(
          type: RecommendationConflictType.tag,
          term: tag,
          message:
              '你同時表達了喜歡「$tag」以及想避開這項特徵，'
              '系統將以排除條件為優先。',
        ),
      );
    }

    // =========================================================
    // 4. 排除條件優先
    // =========================================================

    preferredCategories.removeAll(excludedCategories);
    preferredTags.removeAll(excludedTags);

    // =========================================================
    // 5. 建立統一推薦條件
    // =========================================================

    final criteria = RecommendationCriteria(
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

    return RecommendationCriteriaBuildResult(
      criteria: criteria,
      conflicts: conflicts,
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
}
