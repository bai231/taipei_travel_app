import 'package:flutter/material.dart';
import '../models/place.dart';
import '../services/favorite_service.dart';
import '../theme/app_colors.dart';

class PlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback onDetailPressed;

  const PlaceCard({
    super.key,
    required this.place,
    required this.onDetailPressed,
  });

  @override
  Widget build(BuildContext context) {
    final service = FavoriteService();
    final isFav = service.isFavorite(place);

    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 景點名稱與收藏愛心
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  service.toggleFavorite(place);
                },
                child: Icon(
                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFav ? Colors.redAccent : AppColors.textSecondary,
                  size: 22,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // 類別標籤
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              place.category,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const Spacer(),

          // 評分與停留時間
          Row(
            children: [
              Icon(Icons.star_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 4),
              Text(
                place.rating.toStringAsFixed(1),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                "${place.stayTime} 分鐘",
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 「詳細資訊」按鈕
          SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton(
              onPressed: onDetailPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                elevation: 0,
                padding: EdgeInsets.zero,
              ),
              child: const Text("詳細資訊", style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}