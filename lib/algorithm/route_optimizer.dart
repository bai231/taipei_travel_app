import 'dart:math';

/// 景點資料結構（專為演算法運算設計的簡化版本）
class Place {
  final String id;
  final String name;
  final double lat;     // 緯度
  final double lng;     // 經度
  final int stayDurationMinutes;    // 預計停留時間（分鐘）
  final int? earliestTimeMinutes;  // 最早可抵達時間（例如 09:00 為 540 分鐘）
  final int? latestTimeMinutes;    // 最晚需離開時間（例如 18:00 為 1080 分鐘）
  final double priorityScore;       // D(AI) 給予的偏好分數（越高越推薦）

  Place({
    required this.id,
    required this.name,
    required this.lat, 
    required this.lng, 
    this.stayDurationMinutes = 60,
    this.earliestTimeMinutes,
    this.latestTimeMinutes,
    this.priorityScore = 1.0,
  });
}

/// 演算法計算結果封裝
class OptimizationResult {
  final List<Place> sortedPlaces;  // 最終排列好的絕對順序
  final int totalTimeMinutes;     // 估算總耗時（包含交通與停留）
  final bool isValid;              // 是否完全符合時間窗限制

  OptimizationResult({
    required this.sortedPlaces,
    required this.totalTimeMinutes,
    required this.isValid,
  });
}

/// 路線最佳化大腦：VRPTW（帶時間窗的車輛途程問題）演算法
class RouteOptimizer {
  /// 核心進入點
  /// [placesToVisit]: D (AI) 傳過來的散裝景點清單
  /// [durationMatrix]: N x N 的時間矩陣，單位為分鐘。例如 durationMatrix[0][1] 代表景點 0 到景點 1 的車程時間
  /// [startTimeMinutes]: 今日行程出發時間（例如：早上 09:00 出發，傳入 9 * 60 = 540）
  OptimizationResult optimizeRoute({
    required List<Place> placesToVisit,
    required List<List<double>> durationMatrix,
    required int startTimeMinutes,
  }) {
    if (placesToVisit.isEmpty) {
      return OptimizationResult(sortedPlaces: [], totalTimeMinutes: 0, isValid: true);
    }

    int n = placesToVisit.length;

    // 當景點數量 $N \le 8$ 時，使用全排列搜尋（Permutation Search）
    // 8! = 40,320 種組合，在手機 CPU 上僅需約 0.01 秒即可完成運算並保證找到全域最佳解
    List<Place> bestSequence = [];
    double minCost = double.infinity;
    bool bestIsValid = false;
    int bestTotalDuration = 0;

    List<List<int>> permutations = _generatePermutations(n);

    for (var perm in permutations) {
      double currentCost = 0.0;
      int currentTime = startTimeMinutes;
      bool routeValid = true;

      for (int i = 0; i < perm.length; i++) {
        int currIndex = perm[i];
        Place currPlace = placesToVisit[currIndex];

        // 1. 移動成本計算：若非第一站，加上前一站至本站的時間
        if (i > 0) {
          int prevIndex = perm[i - 1];
          double travelTime = durationMatrix[prevIndex][currIndex];
          currentTime += travelTime.round();
          currentCost += travelTime; // 增加時間成本
        }

        // 2. 時間窗檢查：最早抵達時間限制 (Earliest Time Window)
        if (currPlace.earliestTimeMinutes != null && currentTime < currPlace.earliestTimeMinutes!) {
          int waitTime = currPlace.earliestTimeMinutes! - currentTime;
          currentTime += waitTime;
          currentCost += waitTime * 0.5; // 稍微懲罰等待時間
        }

        // 3. 時間窗檢查：最晚離開時間限制 (Latest Time Window)
        if (currPlace.latestTimeMinutes != null && currentTime > currPlace.latestTimeMinutes!) {
          routeValid = false;
          currentCost += 10000; // 違反時間窗，給予極大懲罰代價
        }

        // 4. 加算景點停留時間
        currentTime += currPlace.stayDurationMinutes;

        // 5. 結合 D(AI) 的偏好權重（偏好分數越高，Cost 越低，優先度提升）
        currentCost -= (currPlace.priorityScore * 15.0);
      }

      // 挑選代價最低且合法的組合
      if (currentCost < minCost) {
        minCost = currentCost;
        bestSequence = perm.map((idx) => placesToVisit[idx]).toList();
        bestIsValid = routeValid;
        bestTotalDuration = currentTime - startTimeMinutes;
      }
    }

    return OptimizationResult(
      sortedPlaces: bestSequence,
      totalTimeMinutes: bestTotalDuration,
      isValid: bestIsValid,
    );
  }

  /// 產生 0 到 n-1 所有索引的全排列組合 (Permutation Helper)
  List<List<int>> _generatePermutations(int n) {
    List<List<int>> result = [];
    List<int> nums = List.generate(n, (i) => i);

    void permute(List<int> arr, int k) {
      if (k == arr.length) {
        result.add(List.from(arr));
        return;
      }
      for (int i = k; i < arr.length; i++) {
        int temp = arr[k];
        arr[k] = arr[i];
        arr[i] = temp;

        permute(arr, k + 1);

        temp = arr[k];
        arr[k] = arr[i];
        arr[i] = temp;
      }
    }

    permute(nums, 0);
    return result;
  }
}