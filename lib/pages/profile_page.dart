import 'package:flutter/material.dart';

import '../services/favorite_service.dart';
import '../models/place.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final favoriteService = FavoriteService();

    final favorites = favoriteService.getFavorites();

    return Scaffold(
      appBar: AppBar(title: const Text("我的")),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Padding(
            padding: EdgeInsets.all(16),

            child: Text(
              "景點收藏區",

              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(
            child: favorites.isEmpty
                ? const Center(child: Text("尚未收藏景點"))
                : ListView.builder(
                    itemCount: favorites.length,

                    itemBuilder: (context, index) {
                      Place place = favorites[index];

                      return ListTile(
                        leading: const Icon(Icons.favorite),

                        title: Text(place.name),

                        subtitle: Text(place.category),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
