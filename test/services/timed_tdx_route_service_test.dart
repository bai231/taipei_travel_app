import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/models/tdx_route.dart';
import 'package:taipei_travel_app/services/tdx_service.dart';
import 'package:taipei_travel_app/services/timed_tdx_route_service.dart';

void main() {
  test('第一批班次太早時延後查詢並快取結果', () async {
    final gateway = _FakeTdxRoutingGateway();
    final service = TimedTdxRouteService(
      gateway: gateway,
      requestInterval: Duration.zero,
    );
    final requestedDeparture = DateTime(2026, 8, 15, 10);

    final firstResult = await service.getRouteAtOrAfter(
      origin: '25.0,121.0',
      destination: '25.1,121.1',
      requestedDeparture: requestedDeparture,
    );
    final secondResult = await service.getRouteAtOrAfter(
      origin: '25.0,121.0',
      destination: '25.1,121.1',
      requestedDeparture: requestedDeparture,
    );

    expect(firstResult?.startTime, DateTime(2026, 8, 15, 10, 5));
    expect(secondResult, same(firstResult));
    expect(gateway.queries, [
      requestedDeparture,
      requestedDeparture.add(const Duration(minutes: 15)),
    ]);
  });
}

class _FakeTdxRoutingGateway implements TdxRoutingGateway {
  final List<DateTime> queries = [];

  @override
  Future<List<TdxRoute>> getRoutingOptions({
    required String origin,
    required String destination,
    DateTime? departureTime,
  }) async {
    queries.add(departureTime!);
    if (queries.length == 1) {
      return [
        TdxRoute(
          transfers: 0,
          travelTime: 20 * 60,
          startTime: DateTime(2026, 8, 15, 9, 58),
          endTime: DateTime(2026, 8, 15, 10, 18),
          sections: const [],
        ),
      ];
    }
    return [
      TdxRoute(
        transfers: 0,
        travelTime: 20 * 60,
        startTime: DateTime(2026, 8, 15, 10, 5),
        endTime: DateTime(2026, 8, 15, 10, 25),
        sections: const [],
      ),
    ];
  }
}
