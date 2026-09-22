import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../../lib/services/google_routes_native_client.dart';
import '../../lib/services/google_route_geometry_service_native.dart';

void main() {
  String request(String mode, {String? date}) => jsonEncode({
    'origin': {'latitude': 25.0, 'longitude': 121.0},
    'destination': {'latitude': 25.1, 'longitude': 121.1},
    'travelMode': mode,
    if (date != null) 'departureTime': date,
  });
  Future<Map<String, String>> config() async => {
    'apiKey': 'test',
    'packageName': 'app.test',
    'certificate': 'ABC',
  };
  test(
    'direct request has Android restrictions, REST mode and shared cache',
    () async {
      var calls = 0;
      final client = GoogleRoutesNativeClient(
        config: config,
        client: MockClient((r) async {
          calls++;
          expect(r.headers['X-Android-Package'], 'app.test');
          expect(r.headers['X-Android-Cert'], 'ABC');
          final body = jsonDecode(r.body);
          expect(body['travelMode'], 'DRIVE');
          expect(body['routingPreference'], 'TRAFFIC_UNAWARE');
          expect(body.containsKey('departureTime'), isFalse);
          return http.Response(
            '{"routes":[{"duration":"120s","distanceMeters":1000}]}',
            200,
          );
        }),
      );
      await client.route(request('DRIVING'));
      await client.route(request('DRIVING'));
      expect(calls, 1);
    },
  );
  test(
    'walking omits traffic and transit retains actual UTC departure',
    () async {
      final date = DateTime.now()
          .toUtc()
          .add(const Duration(days: 1))
          .toIso8601String();
      final client = GoogleRoutesNativeClient(
        config: config,
        client: MockClient((r) async {
          final body = jsonDecode(r.body);
          expect(body.containsKey('routingPreference'), isFalse);
          if (body['travelMode'] == 'TRANSIT')
            expect(body['departureTime'], date);
          else
            expect(body['travelMode'], 'WALK');
          return http.Response('{"routes":[]}', 200);
        }),
      );
      expect(await client.route(request('WALKING')), isNull);
      await client.route(request('TRANSIT', date: date));
      await expectLater(
        client.route(request('TRANSIT', date: '2000-01-01T00:00:00Z')),
        throwsStateError,
      );
    },
  );
  test('errors are not cached and provider body never leaks', () async {
    var calls = 0;
    final client = GoogleRoutesNativeClient(
      config: config,
      client: MockClient((r) async {
        calls++;
        return http.Response('secret provider body', 403);
      }),
    );
    for (var i = 0; i < 2; i++) {
      await expectLater(
        client.route(request('WALKING')),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('403') &&
                !e.toString().contains('secret'),
          ),
        ),
      );
    }
    expect(calls, 2);
  });
  test('decodes real step polylines and rejects malformed geometry', () {
    const encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
    final points = decodeRoutePolyline(encoded);
    expect(points.first.latitude, 38.5);
    expect(points.last.longitude, closeTo(-126.453, 0.00001));
    final segments = parseNativeGeometry({
      'legs': [
        {
          'steps': [
            {
              'travelMode': 'WALK',
              'polyline': {'encodedPolyline': encoded},
            },
          ],
        },
      ],
    });
    expect(segments.single.travelMode, 'WALKING');
    expect(segments.single.points.length, 3);
    expect(() => decodeRoutePolyline('_'), throwsFormatException);
  });
}
