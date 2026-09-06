import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/place.dart';
import 'taiwan_county_resolver.dart';

class PlaceService {
  static const _pageSize = 1000;
  static const placesTable = 'places';
  static const taiwanRestaurantsTable = 'Taiwan_Restaurants';
  static const osmRestaurantsTable = 'osm_restaurants';
  static const taiwanAccommodationsTable = 'Taiwan_Accommodations';

  static const taiwanCounties = [
    '台北市',
    '新北市',
    '基隆市',
    '桃園市',
    '新竹市',
    '新竹縣',
    '苗栗縣',
    '台中市',
    '彰化縣',
    '南投縣',
    '雲林縣',
    '嘉義市',
    '嘉義縣',
    '台南市',
    '高雄市',
    '屏東縣',
    '宜蘭縣',
    '花蓮縣',
    '台東縣',
    '澎湖縣',
    '金門縣',
    '連江縣',
  ];

  final _supabase = Supabase.instance.client;
  Future<List<Place>>? _placesRequest;
  TaiwanCountyResolver? _countyResolver;

  Future<List<Place>> getPlaces() async {
    return _placesRequest ??= _loadPlaces();
  }

  Future<List<Place>> _loadPlaces() async {
    final rows = <Map<String, dynamic>>[];
    for (var from = 0; ; from += _pageSize) {
      final data = await _supabase
          .from(placesTable)
          .select()
          .order('id')
          .range(from, from + _pageSize - 1);
      rows.addAll(data.map((row) => Map<String, dynamic>.from(row)));
      if (data.length < _pageSize) break;
    }

    _countyResolver ??= await TaiwanCountyResolver.load();
    return rows.map(Place.fromJson).map(_withResolvedCounty).toList();
  }

  Place _withResolvedCounty(Place place) {
    final county = countyFor(place, coordinateResolver: _countyResolver);
    return county.isEmpty || county == place.county
        ? place
        : place.copyWith(county: county);
  }

  Future<List<Place>> getTripCatalog() async {
    final requests = <Future<List<Place>>>[
      getPlaces(),
      _loadCatalogTable(taiwanRestaurantsTable, PlaceType.restaurant),
      _loadCatalogTable(osmRestaurantsTable, PlaceType.restaurant),
      _loadCatalogTable(taiwanAccommodationsTable, PlaceType.accommodation),
    ];
    final batches = await Future.wait(requests);
    return batches.expand((batch) => batch).toList();
  }

  Future<List<Place>> getPlacesForTrip({required String location}) async {
    final places = await getPlaces();
    return filterForTrip(places: places, location: location);
  }

  Future<List<Place>> getRoutablePlaces() async {
    final places = await getTripCatalog();
    return places.where(hasUsableCoordinates).toList();
  }

  Future<List<Place>> _loadCatalogTable(
    String table,
    PlaceType expectedType, {
    bool forceType = true,
  }) async {
    final rows = <Map<String, dynamic>>[];
    try {
      for (var from = 0; ; from += _pageSize) {
        final data = await _supabase
            .from(table)
            .select()
            .range(from, from + _pageSize - 1);
        rows.addAll(data.map((row) => Map<String, dynamic>.from(row)));
        if (data.length < _pageSize) break;
      }
    } catch (e) {
      // 網路或連線錯誤時回傳空陣列，避免 App 直接崩潰
      return [];
    }

    _countyResolver ??= await TaiwanCountyResolver.load();
    
    final parsedPlaces = <Place>[];
    for (final json in rows) {
      try {
        final place = Place.fromJson(
          json,
          forcedType: forceType ? expectedType : null,
          idPrefix: table,
        );
        parsedPlaces.add(_withResolvedCounty(place));
      } catch (_) {
        // 單筆資料格式不符時直接跳過，不中斷整批載入
        continue;
      }
    }

    return parsedPlaces.where((place) => place.type == expectedType).toList();
  }

  static List<String> availableCounties(Iterable<Place> places) {
    final available = places
        .map(countyFor)
        .where((county) => county.isNotEmpty)
        .toSet();
    return taiwanCounties.where(available.contains).toList();
  }

  static String countyFor(
    Place place, {
    TaiwanCountyResolver? coordinateResolver,
  }) {
    final explicitCounty = _normalizeTaiwanText(place.county);
    if (taiwanCounties.contains(explicitCounty)) return explicitCounty;

    if (coordinateResolver != null && hasUsableCoordinates(place)) {
      final coordinateCounty = coordinateResolver.resolve(
        latitude: place.latitude,
        longitude: place.longitude,
      );
      if (coordinateCounty.isNotEmpty) return coordinateCounty;
    }

    final normalizedAddress = _normalizeTaiwanText(place.address);
    for (final county in taiwanCounties) {
      if (normalizedAddress.contains(county)) return county;
    }
    return '';
  }

  static List<Place> filterForTrip({
    required Iterable<Place> places,
    required String location,
  }) {
    return places
        .where(
          (place) =>
              isInLocation(place: place, location: location) &&
              hasUsableCoordinates(place),
        )
        .toList();
  }

  static bool isInLocation({required Place place, required String location}) {
    final normalizedLocation = _normalizeTaiwanText(location);
    return normalizedLocation.isNotEmpty &&
        countyFor(place) == normalizedLocation;
  }

  static bool hasUsableCoordinates(Place place) {
    return place.latitude.isFinite &&
        place.longitude.isFinite &&
        place.latitude != 0 &&
        place.longitude != 0 &&
        place.latitude >= -90 &&
        place.latitude <= 90 &&
        place.longitude >= -180 &&
        place.longitude <= 180;
  }

  static String _normalizeTaiwanText(String value) {
    return value.trim().replaceAll('臺', '台');
  }
}