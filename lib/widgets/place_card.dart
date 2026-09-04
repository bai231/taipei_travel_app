import 'package:flutter/material.dart';
import '../models/place.dart';
import '../services/favorite_service.dart';
import '../theme/app_colors.dart';
import '../pages/place_detail_page.dart';

class PlaceCard extends StatefulWidget {
  final Place place;
  final VoidCallback? onDetailPressed;

  const PlaceCard({
    super.key,
    required this.place,
    this.onDetailPressed,
  });

  @override
  State<PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<PlaceCard> {
  final FavoriteService _favoriteService = FavoriteService();

  void _navigateToDetail() {
    if (widget.onDetailPressed != null) {
      widget.onDetailPressed!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaceDetailPage(place: widget.place),
        ),
      ).then((_) {
        if (mounted) setState(() {}); // 從詳細頁返回時刷新愛心
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 當前是否收藏
    final bool isFav = _favoriteService.isFavorite(widget.place);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _navigateToDetail, // 👈 點擊整張卡片即可進入詳細頁
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 圖片 + 右上角愛心
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    color: AppColors.primaryLight.withValues(alpha: 0.35),
                    child: widget.place.image != null && widget.place.image!.isNotEmpty
                        ? Image.network(
                            widget.place.image!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                ),
                // 愛心點擊
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async{
                      // 🌟 關鍵：當下立刻切換變色，不用等網路！
                      final added = await _favoriteService.toggleFavorite(widget.place);
                      setState(() {}); // 局部刷新自身，瞬間變色

                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 1),
                          content: Text(
                            added
                                ? '已將「${widget.place.name}」加入收藏 ⭐️'
                                : '已將「${widget.place.name}」移出收藏',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 18,
                        color: isFav ? Colors.redAccent : AppColors.primaryDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 2. 景點簡要標籤資訊（不放長段落介紹）
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.place.category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.star_rounded, size: 16, color: AppColors.accent),
                      const SizedBox(width: 2),
                      Text(
                        widget.place.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.landscape_rounded,
        size: 36,
        color: AppColors.primaryDark.withValues(alpha: 0.5),
      ),
    );
  }
}