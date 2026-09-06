import 'package:flutter/material.dart';
import '../models/place.dart';
import '../services/favorite_service.dart';
import '../theme/app_colors.dart';

class PlaceDetailPage extends StatefulWidget {
  final Place place;

  const PlaceDetailPage({super.key, required this.place});

  @override
  State<PlaceDetailPage> createState() => _PlaceDetailPageState();
}

class _PlaceDetailPageState extends State<PlaceDetailPage> {
  final FavoriteService _favoriteService = FavoriteService();

  @override
  void initState() {
    super.initState();
    // 監聽收藏變更，確保首頁或個人頁變動時愛心即時同步
    _favoriteService.addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    _favoriteService.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final isFav = _favoriteService.isFavorite(place);

    // 取得文字與主色（若尚未設定 textPrimary 則自動使用 primaryDark 兜底）
    final Color textColor = AppColors.primaryDark;
    final Color subTextColor = AppColors.primaryDark.withValues(alpha: 0.65);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          place.name,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? Colors.redAccent : textColor,
              size: 26,
            ),
            onPressed: () async {
              try {
                // 1. 支援非同步雲端同步 (await)
                final added = await _favoriteService.toggleFavorite(place);

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 1),
                    content: Text(
                      added
                          ? '已將「${place.name}」加入收藏 ⭐️'
                          : '已將「${place.name}」移出收藏',
                    ),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 景點圖片展示（220px 圓角滿版圖）
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: place.image != null && place.image!.isNotEmpty
                  ? Image.network(
                      place.image!,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                    )
                  : _buildImagePlaceholder(),
            ),

            const SizedBox(height: 20),

            // 2. 標籤與評分資訊
            Row(
              children: [
                // 類別膠囊標籤
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    place.category,
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.star_rounded, color: AppColors.accent, size: 22),
                const SizedBox(width: 4),
                Text(
                  place.rating.toStringAsFixed(1),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Icon(Icons.schedule_rounded, size: 18, color: subTextColor),
                const SizedBox(width: 4),
                Text(
                  "建議 ${place.stayTime} 分鐘",
                  style: TextStyle(color: subTextColor, fontSize: 13),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 3. 景點介紹區塊（手帳便籤卡片容器，支援自動換行與舒適行距）
            Text(
              "景點介紹",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: textColor.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                place.description.trim().isEmpty ? "暫無詳細介紹" : place.description,
                softWrap: true, // 自動換行
                style: TextStyle(
                  fontSize: 15,
                  height: 1.65, // 行距舒適易讀
                  color: textColor,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 4. 地址資訊
            if (place.address.isNotEmpty) ...[
              Text(
                "景點地址",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: textColor.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primaryDark,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        place.address,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 220,
      width: double.infinity,
      color: AppColors.primaryLight.withValues(alpha: 0.3),
      child: Center(
        child: Icon(
          Icons.landscape_rounded,
          size: 60,
          color: AppColors.primaryDark.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}