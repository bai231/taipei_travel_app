import 'place.dart';

class TripAutoFillPlan {
  /// 根據天數和 pace 計算出的目標景點數。
  final int targetAttractionCount;

  /// 使用者目前已經加入的景點數。
  final int currentAttractionCount;

  /// 實際可以從推薦排行補入的景點。
  final List<Place> placesToAdd;

  const TripAutoFillPlan({
    required this.targetAttractionCount,
    required this.currentAttractionCount,
    required this.placesToAdd,
  });

  int get requestedAddCount {
    final missing = targetAttractionCount - currentAttractionCount;

    return missing > 0 ? missing : 0;
  }

  int get actualAddCount => placesToAdd.length;

  bool get alreadyEnough => requestedAddCount == 0;

  bool get canFullyFill {
    return actualAddCount >= requestedAddCount;
  }
}
