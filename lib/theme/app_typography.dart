import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  // 🌟 一級大標題（如：我的收藏、行程安排、個人空間）
  static TextStyle headline({Color? color}) => TextStyle(
        fontFamily: 'Nunito',
        fontFamilyFallback: const ['jf-openhunround', 'NotoSansTC'],
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: color ?? AppColors.textPrimary,
        letterSpacing: 0.5,
      );

  // 🌟 二級分區標題（如：景點、行程、景點推薦）
  static TextStyle sectionTitle({Color? color}) => TextStyle(
        fontFamily: 'Nunito',
        fontFamilyFallback: const ['jf-openhunround', 'NotoSansTC'],
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: color ?? AppColors.textPrimary,
        letterSpacing: 0.3,
      );

  // 🌟 卡片標題（如：景點名稱、自訂資料夾名稱）
  static TextStyle cardTitle({Color? color}) => TextStyle(
        fontFamily: 'Nunito',
        fontFamilyFallback: const ['jf-openhunround', 'NotoSansTC'],
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: color ?? AppColors.textPrimary,
      );
}
