class RecommendationCriteria {
  /// 已轉換成資料庫實際 category 的喜好分類
  ///
  /// 例如：文化類、文化資產類
  final Set<String> preferredCategories;

  /// 已轉換成資料庫 tag 或搜尋關鍵字的喜好
  ///
  /// 例如：歷史人文、古蹟、咖啡廳
  final Set<String> preferredTags;

  /// 使用者明確排除的資料庫 category
  final Set<String> excludedCategories;

  /// 使用者明確排除的活動或特徵
  ///
  /// 例如：登山健行、戲水
  final Set<String> excludedTags;

  /// 使用者指定一定要去的景點名稱
  final Set<String> mustVisitPlaceNames;

  /// 行程地區
  final String location;

  /// 表單選擇的價格等級，範圍為 1～5
  final int budgetLevel;

  /// 旅遊人數
  final int people;

  /// 旅遊天數
  final int days;

  /// 行程節奏：relaxed、balanced、intensive
  final String pace;

  /// 步行接受程度：low、medium、high
  final String walkingPreference;

  /// AI 從自然語言中解析出的每日每人預算
  ///
  /// 目前只保留，不覆蓋表單中的 budgetLevel。
  final int? statedDailyBudget;

  /// 無障礙、親子、寵物友善等特殊需求
  final Set<String> specialRequirements;

  const RecommendationCriteria({
    required this.preferredCategories,
    required this.preferredTags,
    required this.excludedCategories,
    required this.excludedTags,
    required this.mustVisitPlaceNames,
    required this.location,
    required this.budgetLevel,
    required this.people,
    required this.days,
    required this.pace,
    required this.walkingPreference,
    required this.statedDailyBudget,
    required this.specialRequirements,
  });

  Map<String, dynamic> toJson() {
    return {
      'preferredCategories': preferredCategories.toList(),
      'preferredTags': preferredTags.toList(),
      'excludedCategories': excludedCategories.toList(),
      'excludedTags': excludedTags.toList(),
      'mustVisitPlaceNames': mustVisitPlaceNames.toList(),
      'location': location,
      'budgetLevel': budgetLevel,
      'people': people,
      'days': days,
      'pace': pace,
      'walkingPreference': walkingPreference,
      'statedDailyBudget': statedDailyBudget,
      'specialRequirements': specialRequirements.toList(),
    };
  }
}
