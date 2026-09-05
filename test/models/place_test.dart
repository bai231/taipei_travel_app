import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/models/place.dart';

void main() {
  test('缺省與只有一端的營業時間不是已知時段，保留原文', () {
    final missing = Place.fromJson({
      'id': 'missing',
      'name': '餐廳',
      'opening_hours': 'Mo-Fr 09:00-18:00',
    });
    expect(missing.hasKnownOpeningHours, isFalse);
    expect(
      missing.copyWith(county: '台北市').openingHoursRaw,
      'Mo-Fr 09:00-18:00',
    );
    final partial = Place.fromJson({'id': 'partial', 'openMinutes': 600});
    expect(partial.hasKnownOpeningHours, isFalse);
    expect(partial.copyWith(county: '台北市').hasKnownOpeningHours, isFalse);
    expect(
      Place.fromJson({
        'id': 'known',
        'openMinutes': 600,
        'closeMinutes': 1080,
      }).hasKnownOpeningHours,
      isTrue,
    );
    expect(
      Place.fromJson({
        'id': 'all-day',
        'opening_hours': '24/7',
      }).hasKnownOpeningHours,
      isTrue,
    );
  });
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
    //expect(place.priceLevel, 2);
    expect(place.estimatedCost, 600.0);
    expect(place.openMinutes, 660);
    expect(place.closeMinutes, 1260);
  });

  test('解析 TDX 餐廳巢狀座標並強制指定資料類型', () {
    final place = Place.fromJson(
      {
        'RestaurantID': 'C3_001',
        'RestaurantName': '測試餐廳',
        'Description': '餐廳說明',
        'Address': '台北市中正區測試路1號',
        'City': '台北市',
        'Position': {'PositionLat': 25.04, 'PositionLon': 121.51},
        'Picture': {'PictureUrl1': 'https://example.com/restaurant.jpg'},
      },
      forcedType: PlaceType.restaurant,
      idPrefix: 'Taiwan_Restaurants',
    );

    expect(place.id, 'Taiwan_Restaurants:C3_001');
    expect(place.name, '測試餐廳');
    expect(place.type, PlaceType.restaurant);
    expect(place.latitude, 25.04);
    expect(place.longitude, 121.51);
    expect(place.image, 'https://example.com/restaurant.jpg');
  });

  test('解析 Taiwan 中文欄位並組合完整地址', () {
    final place = Place.fromJson(
      {
        '唯一識別碼': 'Hotel_A15010000H_000008',
        '資料類型': 'Hotel',
        '資料名稱': '思源居民宿',
        '文字描述': '住宿說明',
        '縣市名稱': '臺中市',
        '行政區(鄉鎮區)名稱': '和平區',
        '街道名稱': '中坑路1號',
      },
      forcedType: PlaceType.accommodation,
      idPrefix: 'Taiwan_Accommodations',
    );

    expect(place.id, 'Taiwan_Accommodations:Hotel_A15010000H_000008');
    expect(place.name, '思源居民宿');
    expect(place.category, 'Hotel');
    expect(place.description, '住宿說明');
    expect(place.address, '臺中市和平區中坑路1號');
    expect(place.county, '臺中市');
    expect(place.latitude, 0);
    expect(place.longitude, 0);
  });

  test('解析 OSM restaurant 的 jsonb tags 與座標', () {
    final place = Place.fromJson(
      {
        'id': 10,
        'source': 'osm',
        'osm_type': 'node',
        'osm_id': 2094925734,
        'name': '福州世祖胡椒餅',
        'category': 'restaurant',
        'address': '',
        'latitude': 25.046,
        'longitude': 121.514,
        'tags': {'amenity': 'restaurant', 'takeaway': 'yes'},
      },
      forcedType: PlaceType.restaurant,
      idPrefix: 'osm_restaurants',
    );

    expect(place.id, 'osm_restaurants:10');
    expect(place.name, '福州世祖胡椒餅');
    expect(place.latitude, 25.046);
    expect(place.longitude, 121.514);
    expect(place.tags, contains('amenity:restaurant'));
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

  test('可從 OSM 類型與名稱推導住宿', () {
    final place = Place.fromJson({
      'id': 3,
      'name': '測試民宿',
      'osm_type': 'guest_house',
      'location': '臺東縣',
      'latitude': 22.75,
      'longitude': 121.15,
      'tags': <String>[],
    });

    expect(place.type, PlaceType.accommodation);
    expect(place.county, '臺東縣');
  });

  test('明確的餐廳分類優先於名稱關鍵字', () {
    final place = Place.fromJson({
      'id': 4,
      'name': '吳師大眾飯店',
      'category': 'restaurant',
      'latitude': 25.05,
      'longitude': 121.53,
      'tags': <String>[],
    });

    expect(place.type, PlaceType.restaurant);
  });
}
