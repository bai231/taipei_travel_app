import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 🌟 1. 最外層改為 extends ChangeNotifier，具備全域廣播能力
class UserDataService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  String? get currentUserId => _supabase.auth.currentUser?.id;

  static final UserDataService _instance = UserDataService._internal();
  factory UserDataService() => _instance;

  // 🌟 2. 本地記憶體快取與監聽訂閱
  final List<Map<String, dynamic>> _folders = [];
  StreamSubscription<AuthState>? _authSubscription;

  // 外部讀取快取清單（唯讀）
  List<Map<String, dynamic>> get folders => List.unmodifiable(_folders);

  // 🌟 3. 私有建構子：自動接管登入與登出事件
  UserDataService._internal() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        // 登入成功：向雲端拉取該帳號資料夾
        fetchFolders();
      } else if (event == AuthChangeEvent.signedOut) {
        // 登出成功：立即清空本地資料夾快取，並廣播畫面還原為空狀態
        _folders.clear();
        notifyListeners();
      }
    });
  }

  // 手動清除快取
  void clearFolders() {
    _folders.clear();
    notifyListeners();
  }

  // ================= 資料夾功能 =================

  // 1. 從 Supabase 撈取使用者的所有資料夾與內部景點
  Future<List<Map<String, dynamic>>> fetchFolders() async {
    final uid = currentUserId;
    if (uid == null) {
      print('⚠️ [UserDataService] 未登入，無法取得雲端資料夾');
      _folders.clear();
      notifyListeners();
      return [];
    }

    try {
      // 🌟 第一步：先單純抓取 folders 主表，確保資料夾不會被空關聯濾掉[cite: 4]
      final folderRows = await _supabase
          .from('folders')
          .select('id, title, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: true);

      print('📦 [UserDataService] 成功抓到資料夾主表筆數: ${folderRows.length}');
      final List<Map<String, dynamic>> result = [];

      // 🌟 第二步：針對每個資料夾，安全抓取內部景點[cite: 4]
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
                // 使用專案相容的 Place.fromJson 解析[cite: 1, 4]
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

      // 🌟 第三步：更新內部快取並對外廣播通知 UI 重繪
      _folders.clear();
      _folders.addAll(result);
      notifyListeners();

      print('☁️ [UserDataService] 成功載入 ${_folders.length} 個雲端資料夾');
      return _folders;
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
      final folderRes = await _supabase.from('folders').insert({
        'user_id': uid,
        'title': cleanTitle,
      }).select().single();

      final int folderId = (folderRes['id'] as num).toInt();
      print('☁️ [UserDataService] 成功建立資料夾: $cleanTitle (ID: $folderId)');

      final List<Place> initialPlaces = [];

      if (initialPlace != null) {
        final int? placeIdInt = int.tryParse(initialPlace.id);

        if (placeIdInt != null && placeIdInt > 0) {
          try {
            await _supabase.from('favorites').upsert(
              {
                'user_id': uid,
                'place_id': placeIdInt,
              },
              onConflict: 'user_id, place_id',
            );

            await _supabase.from('folder_places').upsert(
              {
                'folder_id': folderId,
                'place_id': placeIdInt,
              },
              onConflict: 'folder_id, place_id',
            );
            initialPlaces.add(initialPlace);
            print('☁️ [UserDataService] 成功將「${initialPlace.name}」關聯至新資料夾');
          } catch (relError) {
            print('⚠️ [UserDataService] 關聯景點失敗: $relError');
          }
        } else {
          print('⚠️ [UserDataService] 景點 ID 非純數字 (${initialPlace.id})，僅建立空資料夾');
        }
      }

      await fetchFolders(); // 重新拉取並觸發 notifyListeners[cite: 3, 6]

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
      try {
        await _supabase.from('favorites').upsert(
          {
            'user_id': uid,
            'place_id': placeIdInt,
          },
          onConflict: 'user_id, place_id',
        );
      } catch (favErr) {
        print('ℹ️ [UserDataService] 景點已在收藏中或同步略過: $favErr');
      }

      await _supabase.from('folder_places').upsert(
        {
          'folder_id': folderId,
          'place_id': placeIdInt,
        },
        onConflict: 'folder_id, place_id',
      );

      print('☁️ [UserDataService] 成功將「${place.name}」存入資料夾 $folderId');
      await fetchFolders(); // 重新整理並更新畫面[cite: 3, 6]
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
      await fetchFolders(); // 重新拉取並觸發畫面重繪[cite: 3, 6]
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
      await fetchFolders(); // 重新拉取並更新清單[cite: 3, 6]
      return true;
    } catch (e) {
      print('❌ [UserDataService] 刪除資料夾失敗: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}