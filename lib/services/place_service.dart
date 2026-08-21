import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/place.dart';

class PlaceService {
  final _supabase = Supabase.instance.client;

  Future<List<Place>> getPlaces() async {
    final data = await _supabase.from('places').select();

    return data.map<Place>((json) => Place.fromJson(json)).toList();
  }

  Future<List<Place>> getPlacesForTrip({required String location}) async {
    final places = await getPlaces();
    return filterForTrip(places: places, location: location);
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

  static bool isInLocation({
    required Place place,
    required String location,
  }) {
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
