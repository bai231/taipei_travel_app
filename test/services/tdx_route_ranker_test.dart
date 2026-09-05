import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/models/tdx_route.dart';
import 'package:taipei_travel_app/services/tdx_route_ranker.dart';
import 'package:taipei_travel_app/services/tdx_service.dart';

void main() {
  test('跨縣市路線以總旅行時間為主，不會只因少走路選慢速公車', () {
    const ranker = TdxRouteRanker();
    final bus = _route(
      durationMinutes: 240,
      transfers: 0,
      walkMinutes: 5,
      transitMode: 'bus',
    );
    final highSpeedRail = _route(
      durationMinutes: 120,
      transfers: 2,
      walkMinutes: 20,
      transitMode: 'high_speed_rail',
    );

    final ranked = ranker.rank([bus, highSpeedRail]);

    expect(ranked.first, same(highSpeedRail));
  });

  test('同一路線不同出發時間會保留供本機挑選', () {
    const ranker = TdxRouteRanker();
    final firstDeparture = _route(
      durationMinutes: 30,
      transfers: 0,
      walkMinutes: 5,
      transitMode: 'bus',
      startMinute: 0,
      lineName: '藍1',
    );
    final secondDeparture = _route(
      durationMinutes: 30,
      transfers: 0,
      walkMinutes: 5,
      transitMode: 'bus',
      startMinute: 15,
      lineName: '藍1',
    );

    final ranked = ranker.rank([firstDeparture, secondDeparture]);

    expect(ranked, hasLength(2));
    expect(ranked, containsAll([firstDeparture, secondDeparture]));
  });

  test('單次查詢最多保留 TDX 允許的十筆候選班次', () {
    const ranker = TdxRouteRanker();
    final routes = List.generate(
      25,
      (index) => _route(
        durationMinutes: 30 + index,
        transfers: 0,
        walkMinutes: 5,
        transitMode: 'bus',
        startMinute: index,
        lineName: '幹線${index % 3}',
      ),
    );

    expect(ranker.rank(routes), hasLength(TdxService.maximumRoutingOptions));
  });

  test('完全相同的重複候選只保留一筆', () {
    const ranker = TdxRouteRanker();
    final first = _route(
      durationMinutes: 30,
      transfers: 0,
      walkMinutes: 5,
      transitMode: 'bus',
      lineName: '藍1',
    );
    final duplicate = _route(
      durationMinutes: 30,
      transfers: 0,
      walkMinutes: 5,
      transitMode: 'bus',
      lineName: '藍1',
    );

    expect(ranker.rank([first, duplicate]), hasLength(1));
  });
}

TdxRoute _route({
  required int durationMinutes,
  required int transfers,
  required int walkMinutes,
  required String transitMode,
  int startMinute = 0,
  String? lineName,
}) {
  final start = DateTime(2026, 8, 24, 9).add(Duration(minutes: startMinute));
  return TdxRoute(
    transfers: transfers,
    travelTime: durationMinutes * 60,
    startTime: start,
    endTime: start.add(Duration(minutes: durationMinutes)),
    sections: [
      RouteSection(
        mode: 'pedestrian',
        travelTime: walkMinutes * 60,
        stopCount: 0,
        intermediateStops: const [],
      ),
      RouteSection(
        mode: transitMode,
        lineName: lineName,
        travelTime: (durationMinutes - walkMinutes) * 60,
        stopCount: 0,
        intermediateStops: const [],
      ),
    ],
  );
}
