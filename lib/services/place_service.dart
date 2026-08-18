import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/place.dart';

class PlaceService {
  final _supabase = Supabase.instance.client;

  Future<List<Place>> getPlaces() async {
    final data = await _supabase.from('places').select();

    return data.map<Place>((json) => Place.fromJson(json)).toList();
  }
}
