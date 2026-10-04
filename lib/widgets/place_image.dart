import 'package:flutter/material.dart';

import '../models/place.dart';
import '../theme/app_colors.dart';

/// A consistent category illustration for place cards and saved-place tiles.
class PlaceImage extends StatelessWidget {
  final Place place;

  const PlaceImage({super.key, required this.place});

  IconData get _categoryIcon {
    // Classify only from the database category. Names and tags can contain
    // incidental words and should not change the category illustration.
    final category = place.category.trim().toLowerCase();

    if (_categoryIs(category, const ['生態類', '生態場館類', '自然生態', 'ecology'])) {
      return Icons.eco_rounded;
    }
    if (_categoryIs(category, const [
      '國家自然公園類',
      '國家公園類',
      '都會公園類',
      '公園綠地類',
      '森林遊樂區類',
      '平地森林園區類',
      'park',
    ])) {
      return Icons.park_rounded;
    }
    if (_categoryIs(category, const ['宗教廟宇類', 'religious', 'temple'])) {
      return Icons.temple_buddhist_rounded;
    }
    if (_categoryIs(category, const ['文化資產類', '古蹟', '歷史人文', 'heritage'])) {
      return Icons.account_balance_rounded;
    }
    if (_categoryIs(category, const [
      '藝文場館類',
      '藝術類',
      '博物館',
      '美術館',
      'museum',
      'art',
    ])) {
      return Icons.museum_rounded;
    }
    if (_categoryIs(category, const ['文化類', '原住民文化類', '客家文化類'])) {
      return Icons.theater_comedy_rounded;
    }
    if (_categoryIs(category, const ['水域環境類'])) {
      return Icons.water_rounded;
    }
    if (_categoryIs(category, const ['自然風景類', '國家風景區類'])) {
      return Icons.landscape_rounded;
    }
    if (_categoryIs(category, const ['商圈商店類', 'market', 'shopping'])) {
      return Icons.storefront_rounded;
    }
    if (_categoryIs(category, const ['休閒農業類', 'farm', 'agriculture'])) {
      return Icons.agriculture_rounded;
    }
    if (_categoryIs(category, const ['觀光工廠類', 'factory'])) {
      return Icons.factory_rounded;
    }
    if (_categoryIs(category, const ['遊憩類', '娛樂場館類', '觀光遊樂業類'])) {
      return Icons.attractions_rounded;
    }
    if (_categoryIs(category, const ['咖啡', '咖啡廳', 'cafe', 'coffee'])) {
      return Icons.local_cafe_rounded;
    }
    if (_categoryIs(category, const ['餐廳', '餐飲', '美食', 'restaurant', 'food'])) {
      return Icons.restaurant_rounded;
    }
    if (_categoryIs(category, const ['飯店', '旅館', '住宿', 'hotel', 'accommodation'])) {
      return Icons.hotel_rounded;
    }
    if (place.type == PlaceType.restaurant) return Icons.restaurant_rounded;
    if (place.type == PlaceType.accommodation) return Icons.hotel_rounded;
    return Icons.landscape_rounded;
  }

  bool _categoryIs(String category, List<String> values) =>
      values.any((value) => category == value || category.contains(value));

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryLight.withValues(alpha: 0.45),
              AppColors.background,
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: const Alignment(0.78, -0.72),
              child: Icon(
                Icons.circle,
                size: 74,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
            Center(
              child: Icon(
                _categoryIcon,
                size: 42,
                color: AppColors.primaryDark.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
