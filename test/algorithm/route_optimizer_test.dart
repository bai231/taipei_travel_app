import 'package:flutter_test/flutter_test.dart';
// 這裡匯入你剛剛在 lib 裡面寫好的大腦
import 'package:taipei_travel_app/algorithm/route_optimizer.dart';

void main() {
  test('測試 VRPTW 路線最佳化演算法', () {
    final optimizer = RouteOptimizer();

    // 建立 3 個測試景點
    final places = [
      RouteStop(id: '1', name: '台北 101', latitude: 25.0339, longitude: 121.5644, stayDurationMinutes: 60, priorityScore: 2.0),
      RouteStop(id: '2', name: '寧夏夜市', latitude: 25.0573, longitude: 121.5155, stayDurationMinutes: 90, earliestTimeMinutes: 1080, priorityScore: 5.0),
      RouteStop(id: '3', name: '大稻埕', latitude: 25.0567, longitude: 121.5101, stayDurationMinutes: 45, priorityScore: 1.0),
    ];

    // 模擬 3x3 的時間矩陣（單位：分鐘）
    // [0][1]: 101 -> 寧夏 (25分), [0][2]: 101 -> 大稻埕 (20分)
    // [1][2]: 寧夏 -> 大稻埕 (10分)
    final List<List<double>> mockMatrix = [
      [0.0, 25.0, 20.0],
      [25.0, 0.0, 10.0],
      [20.0, 10.0, 0.0],
    ];

    // 假設早上 10:00 (600 分鐘) 出發
    final result = optimizer.optimizeRoute(
      stopsToVisit: places,
      durationMatrix: mockMatrix,
      startTimeMinutes: 600,
    );

    print('=== 最佳化排序結果 ===');
    for (var p in result.sortedStops) {
      print('-> ${p.name}');
    }
    print('總行程花費時間: ${result.totalTimeMinutes} 分鐘');
    print('是否完全符合時間限制: ${result.isValid}');
  });
}
