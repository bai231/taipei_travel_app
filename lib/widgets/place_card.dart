import 'package:flutter/material.dart';
import '../models/place.dart';
import '../services/favorite_service.dart';

class PlaceCard extends StatefulWidget {
  final Place place;
  final VoidCallback onDetailPressed;

  const PlaceCard({
    super.key,
    required this.place,
    required this.onDetailPressed,
  });

  @override
  State<PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<PlaceCard> {
  final FavoriteService _favoriteService = FavoriteService();

  @override
  Widget build(BuildContext context) {
    // 每次 build 時檢查當前景點是否已被收藏
    final bool isFav = _favoriteService.isFavorite(widget.place);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.place.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(widget.place.category),
            const SizedBox(height: 2),
            //Text(widget.place.description),
            const SizedBox(height: 2),
            Text("⭐ ${widget.place.rating}"),
            Text("停留時間：${widget.place.stayTime} 分鐘"),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onDetailPressed,
                  child: const Text("詳細資訊"),
                ),
                const SizedBox(width: 8),
                // 收藏按鈕
                ElevatedButton.icon(
                  onPressed: () {
                    // 1. 切換收藏狀態（加入 / 移出）
                    final isAdded = _favoriteService.toggleFavorite(
                      widget.place,
                    );

                    // 2. 局部刷新卡片自己，讓愛心圖示與文字即時變色！
                    setState(() {});

                    // 3. 彈出操作提示
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 1),
                        content: Text(
                          isAdded
                              ? "${widget.place.name} 已加入收藏 ⭐️"
                              : "${widget.place.name} 已取消收藏",
                        ),
                      ),
                    );
                  },
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? Colors.redAccent : null,
                  ),
                  label: Text(isFav ? "已收藏" : "收藏景點"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
