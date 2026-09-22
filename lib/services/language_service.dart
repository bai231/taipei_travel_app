// lib/services/language_service.dart
import 'package:flutter/material.dart';

class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  // 監聽目前語系（預設繁體中文 zh_TW）
  final ValueNotifier<Locale> currentLocale = ValueNotifier(const Locale('zh', 'TW'));

  // 取得當前語言名稱
  String get currentLanguageName {
    return currentLocale.value.languageCode == 'en' ? 'English' : '繁體中文';
  }

  // 切換語言
  void changeLanguage(String langName) {
    if (langName == 'English') {
      currentLocale.value = const Locale('en', 'US');
    } else {
      currentLocale.value = const Locale('zh', 'TW');
    }
  }

  // 查表翻譯輔助函式
  static String tr(BuildContext context, String key) {
    final langCode = Localizations.localeOf(context).languageCode;
    return _localizedStrings[langCode]?[key] ?? _localizedStrings['zh']?[key] ?? key;
  }

  // 行程外主要頁面之多語系對照字典
  static const Map<String, Map<String, String>> _localizedStrings = {
    'zh': {
      // 全域與頂部導航
      'guide': '使用指南',
      'login': '登入',
      'account_center': '帳號中心',
      'logout': '登出帳號',
      'logout_success': '已安全登出 🌿',
      'guest_traveler': '訪客旅人',
      'login_prompt': '登入以同步自訂行程與收藏',

      // 底部導航
      'nav_home': '首頁',
      'nav_trip': '行程安排',
      'nav_profile': '個人',
      'nav_inspiration': '靈感',
      'nav_settings': '設定',

      // 首頁 (HomePage)
      'popular_trips': '網上大家都在玩的行程',
      'view_trip': '查看行程',
      'spot_recommendations': '景點推薦',
      'view_detail': '詳細資訊',
      'manual_schedule': '手動排程',
      'min': '分鐘',

      // 個人收藏頁 (ProfilePage)
      'my_favorites': '我的收藏',
      'spots': '景點',
      'itinerary': '行程',
      'my_folders': '我的資料夾',
      'create_folder': '建立資料夾',
      'add_to_folder': '加入資料夾',
      'add_to_trip': '加入行程',
      'cancel_fav': '取消收藏',

      // 設定頁 (SettingsPage)
      'settings_title': '設定',
      'account_settings': '個人帳號設置',
      'edit_profile': '編輯個人資料',
      'edit_profile_sub': '修改頭像、暱稱與個人簡介',
      'travel_pref': '旅遊偏好設定',
      'travel_pref_sub': '海島放鬆、戶外探險、人文美食',
      'notifications': '行程與推播通知',
      'notifications_sub': '接收景點時間提醒與優惠資訊',
      'system_settings': '頁面與系統設定',
      'dark_mode': '深色模式',
      'dark_mode_sub': '降低低光源環境下的視覺刺眼感',
      'language_setting': '語言設定',
      'clear_cache': '清除暫存資料',
      'clear_cache_sub': '已使用 48.5 MB 空間',
      'clear_cache_title': '清除暫存資料',
      'clear_cache_content': '將清除暫存的景點圖片與離線資料，這不會影響你的收藏或自訂行程。',
      'clear_cache_confirm': '確認清除',
      'clear_cache_cancel': '取消',
      'clear_cache_success': '已成功清除暫存檔案 🧹',
      'review_guide': '重新檢視使用指南',
      'about_app': '關於陪伴旅伴 App',
      'select_language': '選擇語言',
    },
    'en': {
      // Global & Top Bar
      'guide': 'Guide',
      'login': 'Login',
      'account_center': 'Account Center',
      'logout': 'Log Out',
      'logout_success': 'Successfully logged out 🌿',
      'guest_traveler': 'Guest Traveler',
      'login_prompt': 'Sign in to sync your trips and favorites',

      // Bottom Navigation
      'nav_home': 'Home',
      'nav_trip': 'Itinerary',
      'nav_profile': 'Profile',
      'nav_inspiration': 'Inspiration',
      'nav_settings': 'Settings',

      // HomePage
      'popular_trips': 'Popular Community Trips',
      'view_trip': 'View Trip',
      'spot_recommendations': 'Recommended Spots',
      'view_detail': 'Details',
      'manual_schedule': 'Manual Planning',
      'min': 'mins',

      // ProfilePage
      'my_favorites': 'My Favorites',
      'spots': 'Attractions',
      'itinerary': 'Trips',
      'my_folders': 'My Folders',
      'create_folder': 'Create Folder',
      'add_to_folder': 'Add to Folder',
      'add_to_trip': 'Add to Trip',
      'cancel_fav': 'Remove Favorite',

      // SettingsPage
      'settings_title': 'Settings',
      'account_settings': 'Account Settings',
      'edit_profile': 'Edit Profile',
      'edit_profile_sub': 'Change avatar, nickname & bio',
      'travel_pref': 'Travel Preferences',
      'travel_pref_sub': 'Island leisure, adventure, gourmet',
      'notifications': 'Notifications',
      'notifications_sub': 'Receive spot alerts and promotions',
      'system_settings': 'Page & App Settings',
      'dark_mode': 'Dark Mode',
      'dark_mode_sub': 'Reduce glare in low-light environments',
      'language_setting': 'Language',
      'clear_cache': 'Clear Cache',
      'clear_cache_sub': '48.5 MB used',
      'clear_cache_title': 'Clear Cache',
      'clear_cache_content': 'Will clear cached images and offline data. Your favorites will not be affected.',
      'clear_cache_confirm': 'Clear Now',
      'clear_cache_cancel': 'Cancel',
      'clear_cache_success': 'Cache cleared successfully 🧹',
      'review_guide': 'Review User Guide',
      'about_app': 'About App',
      'select_language': 'Select Language',
    },
  };
}
