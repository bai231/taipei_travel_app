import 'place.dart';

class MustVisitResolution {
  /// 成功找到，而且符合硬性條件
  final List<Place> matchedPlaces;

  /// 找到景點，但與縣市、預算或排除條件衝突
  final List<Place> conflictingPlaces;

  /// 在資料庫中找不到的使用者輸入名稱
  final List<String> unmatchedNames;

  const MustVisitResolution({
    required this.matchedPlaces,
    required this.conflictingPlaces,
    required this.unmatchedNames,
  });

  bool get hasConflict => conflictingPlaces.isNotEmpty;

  bool get hasUnmatchedName => unmatchedNames.isNotEmpty;
}
