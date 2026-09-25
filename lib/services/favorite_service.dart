import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/place.dart';

class FavoriteService extends ChangeNotifier {
  // 🌟 1. 單例模式 (Singleton)
  static final FavoriteService _instance = FavoriteService._internal();
  factory FavoriteService() => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSubscription;

  // 本地快取清單（供 UI 快速讀取與即時渲染）
  final List<Place> _favorites = [];

  FavoriteService._internal() {
    // 🌟 全域監聽登入/登出狀態（實現第二種架構：登出自動 Flash 清空記憶體快取）
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        // 登入時：自動從雲端載入該帳號收藏並通知 UI
        fetchFavoritesFromCloud();
      } else if (event == AuthChangeEvent.signedOut) {
        // 登出時：立即清空本地快取並廣播通知 UI
        _favorites.clear();
        notifyListeners();
      }
    });
  }

  List<Place> getFavorites() => List.unmodifiable(_favorites);

  // 比對 id 或 name 判斷是否已收藏
  bool isFavorite(Place place) {
    return _favorites.any((item) => item.id == place.id || item.name == place.name);
  }

  // 🌟 2. 從 Supabase 雲端載入當前使用者的收藏清單
  Future<void> fetchFavoritesFromCloud() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _favorites.clear();
      notifyListeners();
      return;
    }

    try {
      final response = await _supabase
          .from('favorites')
          .select('place_id, places(*)') // 關聯抓取 places 表完整資料[cite: 1]
          .eq('user_id', user.id);

      final List<dynamic> data = response as List<dynamic>;
      _favorites.clear();

      for (var item in data) {
        if (item['places'] != null && item['places'] is Map) {
          // 🛡️ 安全轉型為 Map<String, dynamic>，避免 TypeError[cite: 1]
          _favorites.add(
            Place.fromJson(Map<String, dynamic>.from(item['places'] as Map)),
          );
        }
      }
      notifyListeners(); // 刷新所有監聽的頁面[cite: 1]
    } catch (e) {
      debugPrint('❌ 載入雲端收藏失敗: $e');
    }
  }

  // 🌟 3. 切換收藏狀態（純同步樂觀更新：毫秒級變色，背景默默非同步寫入 Supabase）
  bool toggleFavorite(Place place) {
    final user = _supabase.auth.currentUser;
    final int? placeIdInt = int.tryParse(place.id);
    final bool currentlyFav = isFavorite(place);

    if (currentlyFav) {
      // 樂觀移除（本地陣列先移出並廣播）[cite: 1]
      _favorites.removeWhere((item) => item.id == place.id || item.name == place.name);
      notifyListeners();

      // 已登入則背景刪除雲端資料庫
      if (user != null && placeIdInt != null && placeIdInt > 0) {
        _supabase
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('place_id', placeIdInt)
            .catchError((e) => debugPrint('❌ 雲端刪除收藏失敗: $e'));
      }
      return false; // 已取消
    } else {
      // 樂觀加入（本地陣列先加入並廣播）[cite: 1]
      _favorites.add(place);
      notifyListeners();

      // 已登入則背景寫入雲端資料庫
      if (user != null && placeIdInt != null && placeIdInt > 0) {
        _supabase.from('favorites').upsert({
          'user_id': user.id,
          'place_id': placeIdInt,
        }).catchError((e) => debugPrint('❌ 雲端寫入收藏失敗: $e'));
      }
      return true; // 已加入
    }
  }

  // 提供給選單直接呼叫的刪除方法
  void removeFavorite(Place place) {
    toggleFavorite(place);
  }

  // 手動清除快取並廣播
  void clearFavorites() {
    _favorites.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}