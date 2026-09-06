import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/services/place_service.dart';
import 'package:taipei_travel_app/services/taiwan_county_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final type in [PlaceType.restaurant, PlaceType.accommodation]) {
    test('缺座標的 $type 可直接用中文縣市欄位篩選', () {
      final place = Place.fromJson({
        '唯一識別碼': 'test-county-only',
        '資料名稱': '只有縣市的測試資料',
        '縣市名稱': '臺中市',
      }, forcedType: type);

      expect(PlaceService.countyFor(place), '台中市');
      expect(PlaceService.availableCounties([place]), ['台中市']);
      expect(
        PlaceService.filterCatalog(places: [place], type: type, county: '台中市'),
        [place],
      );
      expect(PlaceService.hasUsableCoordinates(place), isFalse);
    });
  }

  test('有效縣市欄位優先於座標與地址', () async {
    final resolver = await TaiwanCountyResolver.load();
    final place = _place(
      '欄位優先',
      address: '高雄市',
      latitude: 24.1372,
      longitude: 120.6869,
    ).copyWith(county: ' 臺北市 ');

    expect(PlaceService.countyFor(place, coordinateResolver: resolver), '台北市');
  });

  test('沒有有效縣市欄位時以座標判定且優先於地址', () async {
    final resolver = await TaiwanCountyResolver.load();
    for (final county in ['', '未知']) {
      final place = _place(
        '座標判定',
        address: '臺北市',
        latitude: 24.1372,
        longitude: 120.6869,
      ).copyWith(county: county);

      expect(
        PlaceService.countyFor(place, coordinateResolver: resolver),
        '台中市',
      );
    }
  });

  test('缺少縣市及有效座標時使用地址或保留未知', () async {
    final resolver = await TaiwanCountyResolver.load();
    for (final address in ['臺南市東區', '']) {
      final place = _place('地址備援', address: address, latitude: 0, longitude: 0);
      expect(
        PlaceService.countyFor(place, coordinateResolver: resolver),
        address.isEmpty ? '' : '台南市',
      );
    }
  });

  test('行程目錄只使用指定的四個 Supabase 資料表', () {
    expect(PlaceService.placesTable, 'places');
    expect(PlaceService.taiwanRestaurantsTable, 'Taiwan_Restaurants');
    expect(PlaceService.osmRestaurantsTable, 'osm_restaurants');
    expect(PlaceService.taiwanAccommodationsTable, 'Taiwan_Accommodations');
  });

  test('行程景點只保留所選城市且具有有效座標的資料', () {
    final places = [
      _place('台北景點', address: '臺北市中正區', latitude: 25.04),
      _place('台南景點', address: '臺南市東區', latitude: 22.98),
      _place('缺座標', address: '台北市萬華區', latitude: 0),
    ];

    final result = PlaceService.filterForTrip(places: places, location: '台北市');

    expect(result.map((place) => place.name), ['台北景點']);
  });

  test('台與臺視為相同縣市名稱', () {
    final place = _place('台北景點', address: '臺北市信義區');

    expect(PlaceService.isInLocation(place: place, location: '台北市'), isTrue);
  });

  test('行程目錄可依類型、縣市與關鍵字篩選', () {
    final places = [
      _place(
        '台北咖啡店',
        address: '臺北市大安區',
        category: '咖啡',
        type: PlaceType.restaurant,
      ),
      _place(
        '高雄餐廳',
        address: '高雄市苓雅區',
        category: '餐廳',
        type: PlaceType.restaurant,
      ),
      _place('台北景點', address: '台北市中正區'),
    ];

    final result = PlaceService.filterCatalog(
      places: places,
      type: PlaceType.restaurant,
      county: '台北市',
      keyword: '咖啡',
    );

    expect(result.map((place) => place.name), ['台北咖啡店']);
  });

  test('目錄可顯示缺座標資料，但路線名單仍排除', () {
    final accommodation = _place(
      '台中住宿',
      address: '臺中市和平區',
      type: PlaceType.accommodation,
      latitude: 0,
      longitude: 0,
    );

    expect(
      PlaceService.filterCatalog(
        places: [accommodation],
        type: PlaceType.accommodation,
        county: '台中市',
      ),
      [accommodation],
    );
    expect(
      PlaceService.filterForTrip(places: [accommodation], location: '台中市'),
      isEmpty,
    );
  });

  test('可從地址取得目前資料中實際存在的縣市', () {
    final places = [
      _place('台北景點', address: '臺北市中正區'),
      _place('高雄景點', address: '高雄市前金區'),
    ];

    expect(PlaceService.availableCounties(places), ['台北市', '高雄市']);
  });

  test('已由座標補上的 county 可用於縣市篩選', () {
    final place = _place('無地址景點', address: '').copyWith(county: '臺中市');

    expect(PlaceService.countyFor(place), '台中市');
    expect(
      PlaceService.filterCatalog(
        places: [place],
        type: PlaceType.attraction,
        county: '台中市',
      ),
      [place],
    );
  });
}

Place _place(
  String name, {
  required String address,
  String category = '景點',
  PlaceType type = PlaceType.attraction,
  double latitude = 25.03,
  double longitude = 121.56,
}) {
  return Place(
    id: name,
    name: name,
    category: category,
    description: '',
    address: address,
    latitude: latitude,
    longitude: longitude,
    image: '',
    type: type,
    stayTime: 60,
    rating: 4,
    tags: const [],
    //priceLevel: 0,
    estimatedCost: 0,
    openMinutes: 0,
    closeMinutes: 1440,
  );
}
