enum TravelClarificationType { pace, walkingPreference }

class TravelClarificationOption {
  /// 程式內部使用的標準值
  ///
  /// 例如：relaxed、balanced、intensive
  final String value;

  /// 顯示給使用者看的文字
  ///
  /// 例如：悠閒、適中、緊湊
  final String label;

  /// 選項的補充說明
  final String description;

  const TravelClarificationOption({
    required this.value,
    required this.label,
    required this.description,
  });
}

class TravelClarification {
  /// 這個問題要確認哪一類資料
  final TravelClarificationType type;

  /// 顯示給使用者的問題
  final String question;

  /// 可供使用者選擇的答案
  final List<TravelClarificationOption> options;

  /// 使用者尚未選擇時的預設答案
  final String defaultValue;

  const TravelClarification({
    required this.type,
    required this.question,
    required this.options,
    required this.defaultValue,
  });
}
