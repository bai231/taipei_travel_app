import 'package:flutter/material.dart';
import '../models/place.dart';

class PlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback onDetailPressed;
  final VoidCallback onFavoritePressed;

  const PlaceCard({
    super.key,
    required this.place,
    required this.onDetailPressed,
    required this.onFavoritePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              place.name,

              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(place.category),

            const SizedBox(height: 8),

            Text(place.description),

            const SizedBox(height: 8),

            Text("⭐ ${place.rating}"),

            Text("停留時間：${place.stayTime} 分鐘"),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDetailPressed,

                  child: const Text("詳細資訊"),
                ),

                const SizedBox(width: 8),

                ElevatedButton.icon(
                  onPressed: onFavoritePressed,

                  icon: const Icon(Icons.favorite_border),

                  label: const Text("收藏景點"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
