import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/models/place.dart';

void main() {
  test('解析 Supabase places 資料庫欄位', () {
    final place = Place.fromJson({
      'id': 1,
      'name': '台北餐廳',
      'category': '餐廳',
      'placeType': 'restaurant',
      'county': '台北市',
      'description': '台北餐廳',
      'address': '台北市信義區市府路45號',
      'latitude': 25.033964,
      'longitude': 121.564468,
      'image': null,
      'stayTime': 120,
      'rating': 4.8,
      'tags': ['攝影', '夜景'],
      'priceLevel': 2,
      'estimatedCost': 600,
      'openMinutes': 660,
      'closeMinutes': 1260,
    });

    expect(place.id, '1');
    expect(place.type, PlaceType.restaurant);
    expect(place.county, '台北市');
    expect(place.longitude, 121.564468);
    expect(place.stayTime, 120);
    expect(place.priceLevel, 2);
    expect(place.estimatedCost, 600.0);
    expect(place.openMinutes, 660);
    expect(place.closeMinutes, 1260);
  });

  test('缺少明確類型時可從分類推導住宿', () {
    final place = Place.fromJson({
      'id': 2,
      'name': '測試旅館',
      'category': '飯店旅館',
      'address': '高雄市前金區',
      'latitude': 22.62,
      'longitude': 120.29,
      'tags': <String>[],
    });

    expect(place.type, PlaceType.accommodation);
  });
}
