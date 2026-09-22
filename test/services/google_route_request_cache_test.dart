import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/features/route_planning/models/route_travel_mode.dart';
import 'package:taipei_travel_app/services/google_route_request_cache.dart';

void main() {
  String request(RouteTravelMode mode, int hour) =>
      GoogleRouteRequestCache.request(
        originLatitude: 25,
        originLongitude: 121,
        destinationLatitude: 24,
        destinationLongitude: 120,
        departureTime: DateTime.utc(2026, 9, 8, hour),
        travelMode: mode,
      );

  test('僅大眾運輸將出發時間納入查詢鍵', () {
    for (final mode in RouteTravelMode.values) {
      expect(
        request(mode, 9) == request(mode, 10),
        mode != RouteTravelMode.transit,
      );
    }
    expect(request(RouteTravelMode.values.first, 9), isNotEmpty);
  });

  test('同時請求只載入一次，完成後重用結果', () async {
    final cache = GoogleRouteRequestCache();
    final completion = Completer<int>();
    var calls = 0;
    Future<int> load() {
      calls++;
      return completion.future;
    }

    final first = cache.get('geometry:route', load, canCache: (_) => true);
    final second = cache.get('geometry:route', load, canCache: (_) => true);
    expect(calls, 1);
    completion.complete(42);
    expect(await Future.wait([first, second]), [42, 42]);
    expect(await cache.get('geometry:route', load, canCache: (_) => true), 42);
    expect(calls, 1);
  });

  test('時間查詢不會載入或誤用地圖資料', () async {
    final cache = GoogleRouteRequestCache();
    expect(
      await cache.get(
        'information:route',
        () async => 20,
        canCache: (_) => true,
      ),
      20,
    );
    var geometryCalls = 0;
    expect(geometryCalls, 0);
    expect(
      await cache.get('geometry:route', () async {
        geometryCalls++;
        return 99;
      }, canCache: (_) => true),
      99,
    );
    expect(geometryCalls, 1);
  });

  test('失敗與空結果不會永久快取，後續可重試', () async {
    final cache = GoogleRouteRequestCache();
    await expectLater(
      cache.get<int>(
        'route',
        () async => throw StateError('failed'),
        canCache: (_) => true,
      ),
      throwsStateError,
    );
    expect(
      await cache.get('route', () async => 0, canCache: (value) => value > 0),
      0,
    );
    expect(
      await cache.get('route', () async => 1, canCache: (value) => value > 0),
      1,
    );
  });
}
