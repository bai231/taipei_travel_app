import '../algorithm/route_optimizer.dart';
import 'tdx_service.dart';

class TdxMatrixService {
  // 直接實例化隊友寫好的 TdxService
  final TdxService _tdxService = TdxService();

  /// 傳入 N 個景點，回傳 N x N 的移動時間矩陣（單位：分鐘）
  Future<List<List<double>>> buildDurationMatrix(List<Place> places) async {
    int n = places.length;
    
    // 預先建立一個裡面全是 0.0 的 N x N 二維陣列
    List<List<double>> matrix = List.generate(n, (_) => List.filled(n, 0.0));
    
    // 用來裝載所有「同時發送」的 API 任務
    List<Future<void>> futures = [];

    print('🚀 開始向 TDX 請求 $n x $n 矩陣資料...');
    final startTime = DateTime.now();

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        // 如果是同一個景點 (自己到自己)，距離直接是 0，不用打 API
        if (i == j) {
          matrix[i][j] = 0.0;
          continue;
        }

        // 把每一個 A點 到 B點 的請求，包裝成 Future 丟進清單
        futures.add(() async {
          try {
            String originStr = '${places[i].lat},${places[i].lng}';
            String destStr = '${places[j].lat},${places[j].lng}';

            // 呼叫隊友寫好的函數
            final routes = await _tdxService.getRoutingOptions(
              origin: originStr,
              destination: destStr,
            );

            if (routes.isNotEmpty) {
              // 抓取隊友排在第一名的路線，將秒數轉換為分鐘
              matrix[i][j] = routes.first.travelTime / 60.0;
            } else {
              // 如果 TDX 真的找不到路（例如隔了一座中央山脈），給一個極大的懲罰值
              matrix[i][j] = 9999.0; 
            }
          } catch (e) {
            print('⚠️ 取得 ${places[i].name} 到 ${places[j].name} 失敗: $e');
            matrix[i][j] = 9999.0;
          }
        }()); // 注意這裡的 () 是讓這個 async 函數立刻執行並回傳 Future
      }
    }

    // 🔥 魔法在這裡：讓 20 個 API 請求「同時」一起跑，並等待它們全部完成！
    await Future.wait(futures);

    final endTime = DateTime.now();
    print('✅ 矩陣計算完成！總耗時: ${endTime.difference(startTime).inMilliseconds} 毫秒');

    return matrix;
  }
}