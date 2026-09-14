import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/services/taiwan_county_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('可使用 MultiPolygon 判定座標所屬縣市', () {
    final resolver = TaiwanCountyResolver.fromGeoJson('''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": {"county": "臺北市"},
            "geometry": {
              "type": "MultiPolygon",
              "coordinates": [[[
                [121.0, 25.0],
                [122.0, 25.0],
                [122.0, 26.0],
                [121.0, 26.0],
                [121.0, 25.0]
              ]]]
            }
          }
        ]
      }
    ''');

    expect(resolver.resolve(latitude: 25.5, longitude: 121.5), '台北市');
    expect(resolver.resolve(latitude: 24, longitude: 121.5), isEmpty);
  });

  test('內建縣市界線可判定實際台灣座標', () async {
    final resolver = await TaiwanCountyResolver.load();

    expect(resolver.resolve(latitude: 25.033, longitude: 121.5654), '台北市');
    expect(resolver.resolve(latitude: 24.1372, longitude: 120.6869), '台中市');
    expect(resolver.resolve(latitude: 22.6117, longitude: 120.3003), '高雄市');
  });
}
