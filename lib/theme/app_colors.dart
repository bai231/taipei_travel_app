import 'package:flutter/material.dart';

/// 🎨 動態色彩包實體（儲存 HSL 推導後的各階顏色）
class DynamicPalette {
  final Color primary;       // 主色（按鈕、選中狀態、卡片）
  final Color background;    // 自動推導：透氣柔和底色
  final Color primaryDark;   // 自動推導：高對比深色文字/標題
  final Color primaryLight;  // 自動推導：淡色分隔線/次要容器/圖片佔位底色
  final Color textPrimary;   // 主要文字（對應 primaryDark）
  final Color textSecondary; // 輔助灰階文字
  final Color surface;       // 卡片/彈窗純白底色
  final Color accent;        // 暖橘點綴色 (評分星級)

  DynamicPalette({
    required this.primary,
    required this.background,
    required this.primaryDark,
    required this.primaryLight,
    required this.textPrimary,
    required this.textSecondary,
    this.surface = Colors.white,
    this.accent = const Color(0xFFE89A5D),
  });
}

/// 🌟 全域色彩管理中心
class AppColors {
  // -------------------------------------------------------------
  // 1. 預設主題候選色（供使用者在設定頁挑選）
  // -------------------------------------------------------------
  static const Color defaultGreen  = Color(0xFF70B19B); // 自然森林綠（預設）
  static const Color defaultBlue   = Color(0xFF2E6B8E); // 沉穩海灣藍
  static const Color defaultOrange = Color(0xFFE89A5D); // 暖陽落日橘
  static const Color defaultPurple = Color(0xFF8E6BBE); // 薰衣草雅紫

  // -------------------------------------------------------------
  // 2. 靜態屬性轉發（👉 補齊所有頁面呼叫需要的指示變數）
  // -------------------------------------------------------------
  static Color get primary       => current.primary;
  static Color get background    => current.background;
  static Color get primaryDark   => current.primaryDark;
  static Color get primaryLight  => current.primaryLight; // 👈 支援 AppColors.primaryLight.withValues(...)
  static Color get textPrimary   => current.textPrimary;
  static Color get textSecondary => current.textSecondary;
  static Color get surface       => current.surface;
  static Color get accent        => current.accent;

  // -------------------------------------------------------------
  // 3. 💡 HSL 相對色階核心推導公式
  // -------------------------------------------------------------
  static DynamicPalette fromPrimary(Color primaryColor) {
    final hsl = HSLColor.fromColor(primaryColor);

    // 透氣水彩底色：拉高明度(0.88)、降低飽和度
    final Color bg = hsl
        .withLightness(0.88)
        .withSaturation((hsl.saturation * 0.35).clamp(0.0, 1.0))
        .toColor();

    // 深色標題與圖示：大幅降低明度(0.18)、微升飽和度保證清晰對比
    final Color dark = hsl
        .withLightness(0.18)
        .withSaturation((hsl.saturation * 1.1).clamp(0.0, 1.0))
        .toColor();

    // 淺色裝飾/佔位/分隔線：明度 0.75 + 中飽和度
    final Color light = hsl
        .withLightness(0.75)
        .withSaturation((hsl.saturation * 0.5).clamp(0.0, 1.0))
        .toColor();

    // 輔助灰階說明文字
    final Color textSec = hsl
        .withLightness(0.35)
        .withSaturation((hsl.saturation * 0.4).clamp(0.0, 1.0))
        .toColor();

    return DynamicPalette(
      primary: primaryColor,
      background: bg,
      primaryDark: dark,
      primaryLight: light,
      textPrimary: dark,
      textSecondary: textSec,
      surface: Colors.white,
      accent: const Color(0xFFE89A5D),
    );
  }

  // -------------------------------------------------------------
  // 4. 全域色彩狀態監聽器（預設為綠色）
  // -------------------------------------------------------------
  static final ValueNotifier<DynamicPalette> currentPalette =
      ValueNotifier<DynamicPalette>(fromPrimary(defaultGreen));

  // 快捷取用當前色彩包
  static DynamicPalette get current => currentPalette.value;

  // 🚀 一鍵切換主題色
  static void switchTheme(Color newPrimaryColor) {
    currentPalette.value = fromPrimary(newPrimaryColor);
  }
}