import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/services/place_service.dart';

void main() {
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

  test('可從地址取得目前資料中實際存在的縣市', () {
    final places = [
      _place('台北景點', address: '臺北市中正區'),
      _place('高雄景點', address: '高雄市前金區'),
    ];

    expect(PlaceService.availableCounties(places), ['台北市', '高雄市']);
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
