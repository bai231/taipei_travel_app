import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/place.dart';

class PlaceService {
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

  Future<List<Place>> getPlaces() async {
    final data = await _supabase.from('places').select();

    return data.map<Place>((json) => Place.fromJson(json)).toList();
  }

  Future<List<Place>> getPlacesForTrip({required String location}) async {
    final places = await getPlaces();
    return filterForTrip(places: places, location: location);
  }

  Future<List<Place>> getRoutablePlaces() async {
    final places = await getPlaces();
    return places.where(hasUsableCoordinates).toList();
  }

  static List<Place> filterCatalog({
    required Iterable<Place> places,
    required PlaceType type,
    String? county,
    String keyword = '',
  }) {
    final normalizedCounty = _normalizeTaiwanText(county ?? '');
    final normalizedKeyword = _normalizeTaiwanText(keyword).toLowerCase();
    return places.where((place) {
      if (place.type != type || !hasUsableCoordinates(place)) return false;
      if (normalizedCounty.isNotEmpty && countyFor(place) != normalizedCounty) {
        return false;
      }
      if (normalizedKeyword.isEmpty) return true;
      final searchable = _normalizeTaiwanText(
        [place.name, place.category, place.address, ...place.tags].join(' '),
      ).toLowerCase();
      return searchable.contains(normalizedKeyword);
    }).toList();
  }

  static List<String> availableCounties(Iterable<Place> places) {
    final available = places
        .map(countyFor)
        .where((county) => county.isNotEmpty)
        .toSet();
    return taiwanCounties.where(available.contains).toList();
  }

  static String countyFor(Place place) {
    final explicitCounty = _normalizeTaiwanText(place.county);
    if (explicitCounty.isNotEmpty) return explicitCounty;

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
    final normalizedAddress = _normalizeTaiwanText(place.address);
    return normalizedLocation.isNotEmpty &&
        normalizedAddress.contains(normalizedLocation);
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
