import 'package:flutter/material.dart';

class AppColors {
  // 🌿 1. 當前預設：綠色水彩質感色系 (草圖標準色)
  static const Color primary = Color(0xFF70B19B);       // 卡片綠 / 核心主色
  static const Color primaryDark = Color(0xFF1E3A2F);   // 深墨綠 (標題大字、圖示)
  static const Color primaryLight = Color(0xFFA1C6B4);  // 淡綠色 (分隔線、裝飾)
  static const Color background = Color(0xFFC7DEC8);    // 淺綠水彩底色
  static const Color surface = Colors.white;            // 純白容器
  static const Color navHighlight = Color(0xFFE5ECE8);  // 底部導航選中膠囊色
  static const Color accent = Color(0xFFE89A5D);        // 暖陽橘 (亮點點綴/星級評分)

  // 文字顏色
  static const Color textPrimary = Color(0xFF1E3A2F);   // 深墨綠 (正文/標題)
  static const Color textSecondary = Color(0xFF4A6B5D); // 灰綠色 (次要提示文字)

  // ============================================================
  // 💡 未來換色核心：只要傳入任意 primary 顏色，自動計算相對色階！
  // ============================================================
  static DynamicPalette fromPrimary(Color primaryColor) {
    final hsl = HSLColor.fromColor(primaryColor);

    return DynamicPalette(
      primary: primaryColor,
      // 底色：拉高亮度(0.85)、降低飽和度，產生柔和透氣的水彩底
      background: hsl
          .withLightness(0.85)
          .withSaturation((hsl.saturation * 0.4).clamp(0.0, 1.0))
          .toColor(),
      // 標題深色文字：大幅降低亮度(0.18)、增加飽和度，確保高對比清晰度
      textDark: hsl
          .withLightness(0.18)
          .withSaturation((hsl.saturation * 1.1).clamp(0.0, 1.0))
          .toColor(),
      // 分隔線/輔助色：比主色更淡更柔
      divider: hsl
          .withLightness(0.72)
          .withSaturation((hsl.saturation * 0.5).clamp(0.0, 1.0))
          .toColor(),
      // 導航選中膠囊色：極淡色調
      navHighlight: hsl.withLightness(0.92).withSaturation(0.15).toColor(),
    );
  }
}

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
      scaffoldBackgroundColor: AppColors.background,

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