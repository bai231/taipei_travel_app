import 'package:flutter/material.dart';
import 'app_colors.dart';

// 相對色彩包實體類別
class DynamicPalette {
  final Color primary;
  final Color background;
  final Color textDark;
  final Color divider;
  final Color navHighlight;

  DynamicPalette({
    required this.primary,
    required this.background,
    required this.textDark,
    required this.divider,
    required this.navHighlight,
  });
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      fontFamily: 'NotoSansTC',
      fontFamilyFallback: const ['NotoSansTC'],
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        titleTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontFamilyFallback: ['jf-openhunround', 'NotoSansTC'],
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'Nunito',
          fontFamilyFallback: ['jf-openhunround', 'NotoSansTC'],
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Nunito',
          fontFamilyFallback: ['jf-openhunround', 'NotoSansTC'],
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Nunito',
          fontFamilyFallback: ['jf-openhunround', 'NotoSansTC'],
        ),
        titleLarge: TextStyle(
          fontFamily: 'Nunito',
          fontFamilyFallback: ['jf-openhunround', 'NotoSansTC'],
        ),
        titleMedium: TextStyle(
          fontFamily: 'Nunito',
          fontFamilyFallback: ['jf-openhunround', 'NotoSansTC'],
        ),
        titleSmall: TextStyle(
          fontFamily: 'Nunito',
          fontFamilyFallback: ['jf-openhunround', 'NotoSansTC'],
        ),
      ),

      // 全域按鈕：膠囊造型、綠色調重點按鈕
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

      // 全域輸入框：膠囊狀微透底色、聚焦時呈現主色邊框
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.8),
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
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 15),
      ),
    );
  }
}
