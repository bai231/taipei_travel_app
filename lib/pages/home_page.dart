import 'package:flutter/material.dart';

import '../models/place.dart';
import '../services/place_service.dart';
import '../widgets/place_card.dart';
import '../services/favorite_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PlaceService placeService = PlaceService();

  final List<String> photoList = const [
    'assets/test1.jpg',
    'assets/test2.jpg',
    'assets/test3.jpg',
  ];

  List<Place> places = [];

  bool isLoading = true;

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadPlaces();
  }

  Future<void> loadPlaces() async {
    try {
      final result = await placeService.getPlaces();

      if (!mounted) return;

      setState(() {
        places = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("使用指南"),
        actions: [
          TextButton(
            onPressed: () {
              // 之後接 LoginPage
            },
            child: const Text("登入"),
          ),
        ],
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "網上大家都在玩的行程",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),

          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: photoList.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    photoList[index],
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text(
              "景點推薦",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),

          if (isLoading)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (errorMessage != null)
            SizedBox(
              height: 200,
              child: Center(child: Text("讀取景點失敗：$errorMessage")),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: places.length,
                itemBuilder: (context, index) {
                  final place = places[index];

                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: PlaceCard(
                      place: place,

                      onDetailPressed: () {
                        print("詳細資訊：${place.name}");
                      },

                      onFavoritePressed: () async {
                        final service = FavoriteService();

                        bool success = service.addFavorite(place);

                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("${place.name} 已收藏")),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton(
                  onPressed: () {
                    print("點擊了手動排程");
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    "手動排程",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
