import 'recommendation_conflict.dart';
import 'recommendation_criteria.dart';

class RecommendationCriteriaBuildResult {
  /// 已完成合併與衝突處理的推薦條件
  final RecommendationCriteria criteria;

  /// 合併過程中發現的需求衝突
  final List<RecommendationConflict> conflicts;

  RecommendationCriteriaBuildResult({
    required this.criteria,
    required Iterable<RecommendationConflict> conflicts,
  }) : conflicts = List.unmodifiable(conflicts);

  bool get hasConflicts => conflicts.isNotEmpty;
}
