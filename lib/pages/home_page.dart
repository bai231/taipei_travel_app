import 'package:flutter/material.dart';

import '../models/place.dart';
import '../services/place_service.dart';
import '../widgets/place_card.dart';
import '../services/favorite_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final PlaceService placeService = PlaceService();

    final List<Place> places = placeService.getPlaces();

    return Scaffold(
      appBar: AppBar(title: const Text("台北旅遊")),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "熱門景點",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),

          SizedBox(
            height: 250, // PlaceCard 的高度，可自行調整
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: places.length,

              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: PlaceCard(
                    place: places[index],

                    onDetailPressed: () {
                      print("詳細資訊：${places[index].name}");
                    },

                    onFavoritePressed: () async {
                      final service = FavoriteService();

                      bool success = service.addFavorite(places[index]);

                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("${places[index].name} 已收藏")),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
