import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/place.dart';

class UserDataService {
  final _supabase = Supabase.instance.client;
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // ================= 資料夾功能 =================

  // 撈取使用者的資料夾清單
  Future<List<Map<String, dynamic>>> fetchFolders() async {
    final uid = currentUserId;
    if (uid == null) return [];

    final response = await _supabase
        .from('folders')
        .select('*, folder_places(place_id)')
        .eq('user_id', uid)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  // 建立新資料夾並將景點移入
  Future<void> createFolder(String title, {String? placeId}) async {
    final uid = currentUserId;
    if (uid == null) return;

    final folderRes = await _supabase.from('folders').insert({
      'user_id': uid,
      'title': title,
    }).select().single();

    if (placeId != null) {
      final folderId = folderRes['id'];
      await _supabase.from('folder_places').insert({
        'folder_id': folderId,
        'place_id': int.tryParse(placeId) ?? 0,
      });
    }
  }

  // ================= 行程功能 =================

  // 撈取使用者的所有行程
  Future<List<Map<String, dynamic>>> fetchTrips() async {
    final uid = currentUserId;
    if (uid == null) return [];

    final response = await _supabase
        .from('trips')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // 建立新行程
  Future<void> createTrip(String title) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _supabase.from('trips').insert({
      'user_id': uid,
      'title': title,
    });
  }

  // 將景點加入行程
  Future<void> addPlaceToTrip(int tripId, String placeId) async {
    await _supabase.from('trip_places').insert({
      'trip_id': tripId,
      'place_id': int.tryParse(placeId) ?? 0,
    });
  }
}