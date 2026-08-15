import 'package:flutter/foundation.dart';
import '../models/place.dart';

class FavoriteService extends ChangeNotifier {
  // 1. 單例模式 (Singleton)，確保全 App 任何頁面抓到的都是同一個實例
  static final FavoriteService _instance = FavoriteService._internal();
  factory FavoriteService() => _instance;
  FavoriteService._internal();

  // 內部收藏清單
  final List<Place> _favorites = [];

  // 取得所有收藏清單（只讀副本）
  List<Place> getFavorites() {
    return List.unmodifiable(_favorites);
  }

  // 檢查某個景點是否已經被收藏
  bool isFavorite(Place place) {
    return _favorites.any((item) => item.id == place.id);
  }

  // 加入收藏
  void addFavorite(Place place) {
    if (!isFavorite(place)) {
      _favorites.add(place);
      notifyListeners(); // 通知監聽此服務的頁面刷新
    }
  }

  // 移除收藏
  void removeFavorite(Place place) {
    _favorites.removeWhere((item) => item.id == place.id);
    notifyListeners(); // 通知刷新
  }

  // 切換收藏狀態（點一下加入、再點一下取消）
  bool toggleFavorite(Place place) {
    if (isFavorite(place)) {
      removeFavorite(place);
      return false; // 取消收藏
    } else {
      addFavorite(place);
      return true; // 加入收藏
    }
  }
}