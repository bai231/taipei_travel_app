import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taipei_travel_app/models/tdx_route.dart';
import 'package:taipei_travel_app/services/tdx_realtime_service.dart';
import 'package:taipei_travel_app/services/transit_realtime_monitor.dart';

void main() {
  test('權杖到期前沿用快取，到期後重新取得', () async {
    final clock = _FakeClock(DateTime(2026, 9, 22, 10));
    var tokenRequests = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        tokenRequests++;
        return http.Response(
          jsonEncode({
            'access_token': 'token-$tokenRequests',
            'expires_in': 60,
          }),
          200,
        );
      }
      return _busEtaResponse();
    });
    final service = TdxRealtimeService(
      client: client,
      clientId: 'test-id',
      clientSecret: 'test-secret',
      minimumRequestInterval: Duration.zero,
      now: clock.now,
    );

    await service.load(_busIdentity());
    clock.advance(const Duration(seconds: 20));
    await service.load(_busIdentity());
    expect(tokenRequests, 1);

    clock.advance(const Duration(seconds: 11));
    await service.load(_busIdentity());
    expect(tokenRequests, 2);

    service.dispose();
  });

  test('連續請求透過可替換等待函式遵守最短間隔', () async {
    final clock = _FakeClock(DateTime(2026, 9, 22, 10));
    final waits = <Duration>[];
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response(
          jsonEncode({'access_token': 'token', 'expires_in': 3600}),
          200,
        );
      }
      return _busEtaResponse();
    });
    final service = TdxRealtimeService(
      client: client,
      clientId: 'test-id',
      clientSecret: 'test-secret',
      minimumRequestInterval: const Duration(seconds: 2),
      now: clock.now,
      delay: (duration) async {
        waits.add(duration);
        clock.advance(duration);
      },
    );

    await service.load(_busIdentity());
    await service.load(_busIdentity());

    expect(waits, [const Duration(seconds: 2)]);
    expect(clock.value, DateTime(2026, 9, 22, 10, 0, 2));

    service.dispose();
  });
}

TransitSectionIdentity _busIdentity() => TransitSectionIdentity(
  provider: TransitProvider.bus,
  legIndex: 0,
  sectionIndex: 0,
  serviceDate: DateTime(2026, 9, 22),
  section: RouteSection(
    mode: 'bus',
    lineName: '307',
    routeId: '307',
    city: 'Taipei',
    departureTitle: '臺北車站',
    arrivalTitle: '西門站',
    travelTime: 600,
    stopCount: 0,
    intermediateStops: const [],
    scheduledDeparture: DateTime(2026, 9, 22, 10, 10),
    scheduledArrival: DateTime(2026, 9, 22, 10, 20),
  ),
);

http.Response _busEtaResponse() => http.Response.bytes(
  utf8.encode(
    jsonEncode([
      {
        'StopName': {'Zh_tw': '臺北車站'},
        'EstimateTime': 300,
        'StopStatus': 0,
        'SrcUpdateTime': '2026-09-22T10:00:00+08:00',
      },
    ]),
  ),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

class _FakeClock {
  DateTime value;

  _FakeClock(this.value);

  DateTime now() => value;

  void advance(Duration duration) {
    value = value.add(duration);
  }
}
