enum RecommendationConflictType { category, tag }

class RecommendationConflict {
  /// 衝突類型：景點分類或景點特徵
  final RecommendationConflictType type;

  /// 發生衝突的標準化條件
  ///
  /// 例如：nature、登山健行
  final String term;

  /// 顯示給使用者看的繁體中文訊息
  final String message;

  const RecommendationConflict({
    required this.type,
    required this.term,
    required this.message,
  });

  Map<String, dynamic> toJson() {
    return {'type': type.name, 'term': term, 'message': message};
  }
}
