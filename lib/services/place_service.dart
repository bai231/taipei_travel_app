import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/place.dart';

class PlaceService {
  final _supabase = Supabase.instance.client;

  Future<List<Place>> getPlaces() async {
    try {
      final response = await _supabase
          .from('places')
          .select()
          .order('id', ascending: true);

      final List<dynamic> data = response as List<dynamic>;

      // 安全地將每筆 Map 傳入 Place.fromJson
      return data
          .map((item) => Place.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      print("❌ 景點載入失敗: $e");
      rethrow;
    }
  }
}