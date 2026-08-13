import '../algorithm/route_optimizer.dart';
import 'tdx_service.dart';

class TdxMatrixService {
  final TdxService _tdxService = TdxService();
  static const _requestInterval = Duration(seconds: 2);

  Future<List<List<double>>> buildDurationMatrix(List<RouteStop> places) async {
    final placeCount = places.length;
    final matrix = List.generate(
      placeCount,
      (_) => List.filled(placeCount, 0.0),
    );

    print('開始向 TDX 請求 $placeCount x $placeCount 矩陣資料...');
    final startTime = DateTime.now();

    for (var originIndex = 0; originIndex < placeCount; originIndex++) {
      for (
        var destinationIndex = originIndex + 1;
        destinationIndex < placeCount;
        destinationIndex++
      ) {
        final travelTime = await _travelTimeInMinutes(
          origin: places[originIndex],
          destination: places[destinationIndex],
        );
        matrix[originIndex][destinationIndex] = travelTime;
        matrix[destinationIndex][originIndex] = travelTime;
        await Future<void>.delayed(_requestInterval);
      }
    }

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    print('矩陣計算完成！總耗時: $elapsed 毫秒');
    return matrix;
  }

  Future<List<double>> buildTravelTimesFromOrigin({
    required RouteStop origin,
    required List<RouteStop> destinations,
  }) async {
    final travelTimes = <double>[];
    for (final destination in destinations) {
      travelTimes.add(
        await _travelTimeInMinutes(origin: origin, destination: destination),
      );
      await Future<void>.delayed(_requestInterval);
    }
    return travelTimes;
  }

  Future<double> _travelTimeInMinutes({
    required RouteStop origin,
    required RouteStop destination,
  }) async {
    try {
      final routes = await _tdxService.getRoutingOptions(
        origin: '${origin.latitude},${origin.longitude}',
        destination: '${destination.latitude},${destination.longitude}',
      );
      return routes.isEmpty ? 9999.0 : routes.first.travelTime / 60.0;
    } catch (error) {
      print('取得 ${origin.name} 到 ${destination.name} 失敗: $error');
      return 9999.0;
    }
  }
}
