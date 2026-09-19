import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/place.dart';

class UserDataService {
  final _supabase = Supabase.instance.client;
  String? get currentUserId => _supabase.auth.currentUser?.id;

  static final UserDataService _instance = UserDataService._internal();
  factory UserDataService() => _instance;
  UserDataService._internal();

  // ================= 資料夾功能 =================

  // 1. 從 Supabase 撈取使用者的所有資料夾與內部景點
  Future<List<Map<String, dynamic>>> fetchFolders() async {
    final uid = currentUserId;
    if (uid == null) {
      print('⚠️ [UserDataService] 未登入，無法取得雲端資料夾');
      return [];
    }

    try {
      // 🌟 第一步：先單純抓取 folders 主表，確保資料夾不會被空關聯濾掉
      final folderRows = await _supabase
          .from('folders')
          .select('id, title, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: true);

      print('📦 [UserDataService] 成功抓到資料夾主表筆數: ${folderRows.length}');
      final List<Map<String, dynamic>> result = [];

      // 🌟 第二步：針對每個資料夾，安全抓取內部景點
      for (var folder in folderRows) {
        final int folderId = (folder['id'] as num).toInt();
        final String title = folder['title']?.toString() ?? '未命名資料夾';
        final List<Place> places = [];

        try {
          final placesRes = await _supabase
              .from('folder_places')
              .select('place_id, places(*)')
              .eq('folder_id', folderId);

          for (var item in placesRes) {
            if (item is Map && item['places'] != null && item['places'] is Map) {
              try {
                places.add(Place.fromJson(Map<String, dynamic>.from(item['places'] as Map)));
              } catch (e) {
                print('⚠️ [UserDataService] 解析資料夾內景點失敗: $e');
              }
            }
          }
        } catch (innerError) {
          print('⚠️ [UserDataService] 讀取資料夾 $folderId 內景點出錯（保留空資料夾）: $innerError');
        }

        result.add({
          'id': folderId,
          'title': title,
          'places': places,
        });
      }

      print('☁️ [UserDataService] 成功載入 ${result.length} 個雲端資料夾');
      return result;
    } catch (e, stack) {
      print('❌ [UserDataService] fetchFolders 發生錯誤: $e');
      print('堆疊日誌: $stack');
      return [];
    }
  }

  // 2. 建立新資料夾（第一層 folders + 第二層 folder_places）
  Future<Map<String, dynamic>?> createFolder(String title, {Place? initialPlace}) async {
    final uid = currentUserId;
    final cleanTitle = title.trim();

    if (uid == null || cleanTitle.isEmpty) {
      print('⚠️ [UserDataService] 建立資料夾失敗：未登入或標題為空');
      return null;
    }

    try {
      // 🌟 第一層：寫入 folders 表取得 folder_id
      final folderRes = await _supabase.from('folders').insert({
        'user_id': uid,
        'title': cleanTitle,
      }).select().single();

      final int folderId = (folderRes['id'] as num).toInt();
      print('☁️ [UserDataService] 成功建立資料夾: $cleanTitle (ID: $folderId)');

      final List<Place> initialPlaces = [];

      // 🌟 第二層：若有初始景點，寫入 folder_places
      if (initialPlace != null) {
        final int? placeIdInt = int.tryParse(initialPlace.id);

        if (placeIdInt != null && placeIdInt > 0) {
          // 🛡️ 確保 favorites 存在（遇到重複直接忽略，不中斷後續流程）
          try {
            await _supabase.from('favorites').upsert(
              {
                'user_id': uid,
                'place_id': placeIdInt,
              },
              onConflict: 'user_id, place_id', // 👈 指定衝突鍵
            );
          } catch (favErr) {
            print('ℹ️ [UserDataService] 景點已在收藏中或同步略過: $favErr');
          }

          // 寫入資料夾關聯表（同樣指定衝突鍵防止重複加入報錯）
          await _supabase.from('folder_places').upsert(
            {
              'folder_id': folderId,
              'place_id': placeIdInt,
            },
            onConflict: 'folder_id, place_id', // 👈 指定衝突鍵
          );

          initialPlaces.add(initialPlace);
          print('☁️ [UserDataService] 成功將「${initialPlace.name}」關聯至新資料夾');
        } else {
          print('⚠️ [UserDataService] 景點 ID 非純數字 (${initialPlace.id})，僅建立空資料夾');
        }
      }

      return {
        'id': folderId,
        'title': cleanTitle,
        'places': initialPlaces,
      };
    } catch (e) {
      print('❌ [UserDataService] 建立資料夾失敗: $e');
      return null;
    }
  }

  // 3. 將景點加入既有資料夾（第二層寫入）
Future<bool> addPlaceToFolder(int folderId, Place place) async {
    final uid = currentUserId;
    final int? placeIdInt = int.tryParse(place.id);

    if (uid == null || placeIdInt == null || placeIdInt <= 0) {
      print('⚠️ [UserDataService] 加入失敗：未登入或無效的 place.id (${place.id})');
      return false;
    }

    try {
      // 🛡️ 1. 確保 favorites 存在（加上 onConflict 防重複衝突）
      try {
        await _supabase.from('favorites').upsert(
          {
            'user_id': uid,
            'place_id': placeIdInt,
          },
          onConflict: 'user_id, place_id', // 👈 關鍵修正
        );
      } catch (favErr) {
        print('ℹ️ [UserDataService] 景點已在收藏中: $favErr');
      }

      // 🛡️ 2. 寫入 folder_places 表
      await _supabase.from('folder_places').upsert(
        {
          'folder_id': folderId,
          'place_id': placeIdInt,
        },
        onConflict: 'folder_id, place_id', // 👈 關鍵修正
      );

      print('☁️ [UserDataService] 成功將「${place.name}」存入資料夾 $folderId');
      return true;
    } catch (e) {
      print('❌ [UserDataService] 加入資料夾失敗: $e');
      return false;
    }
  }

  // 4. 從資料夾移除景點
  Future<bool> removePlaceFromFolder(int folderId, Place place) async {
    final int? placeIdInt = int.tryParse(place.id);
    if (placeIdInt == null || placeIdInt <= 0) return false;

    try {
      await _supabase
          .from('folder_places')
          .delete()
          .eq('folder_id', folderId)
          .eq('place_id', placeIdInt);

      print('☁️ [UserDataService] 成功從資料夾 $folderId 移除「${place.name}」');
      return true;
    } catch (e) {
      print('❌ [UserDataService] 移除失敗: $e');
      return false;
    }
  }

  // 5. 刪除資料夾
  Future<bool> deleteFolder(int folderId) async {
    final uid = currentUserId;
    if (uid == null) return false;

    try {
      await _supabase
          .from('folders')
          .delete()
          .eq('id', folderId)
          .eq('user_id', uid);

      print('🗑️ [UserDataService] 成功刪除資料夾: $folderId');
      return true;
    } catch (e) {
      print('❌ [UserDataService] 刪除資料夾失敗: $e');
      return false;
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

  // 將景點加入行程
  Future<void> addPlaceToTrip(int tripId, String placeId) async {
    final int? parsedPlaceId = int.tryParse(placeId);

    if (parsedPlaceId == null || parsedPlaceId <= 0) {
      print('⚠️ [UserDataService] 無效的 placeId: "$placeId"，已取消加入行程');
      throw ArgumentError('無效的景點 ID: $placeId，無法加入行程');
    }

    try {
      await _supabase.from('trip_places').insert({
        'trip_id': tripId,
        'place_id': parsedPlaceId,
      });
      print('☁️ [UserDataService] 成功將景點 $parsedPlaceId 加入行程 $tripId');
    } catch (e) {
      print('❌ [UserDataService] 加入行程景點失敗: $e');
      rethrow;
    }
  }
}