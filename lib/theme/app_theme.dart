import 'package:flutter/material.dart';

class AppColors {
  // 頁面與卡片底色 (低飽和透氣底色)
  static const Color background = Color(0xFFF2F6F9);       // 冰川米白底色
  static const Color surface = Colors.white;                // 卡片純白色

  // 藍色系品牌主調
  static const Color primary = Color(0xFF2E6B8E);          // 沉穩海藍 (主按鈕、重點)
  static const Color primaryLight = Color(0xFF8BB7D0);     // 柔和淺天藍 (輸入框填色)
  static const Color primaryDark = Color(0xFF1B435A);      // 深海軍藍 (標題大字)
  static const Color accent = Color(0xFFE89A5D);           // 暖陽橘 (亮點點綴/通知)

  // 文字顏色
  static const Color textPrimary = Color(0xFF1E3340);      // 深墨藍灰 (正文)
  static const Color textSecondary = Color(0xFF6C8796);    // 柔霧灰藍 (次要提示文字)
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,

      // 全域按鈕：膠囊造型、親切圓潤
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      // 全域輸入框：膠囊狀微透底色、無生硬框線
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.primaryLight.withValues(alpha: 0.25),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
      ),
    );
  }
}