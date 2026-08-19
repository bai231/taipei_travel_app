import 'package:flutter/material.dart';

import '../models/place.dart';
import '../services/place_service.dart';
import '../widgets/place_card.dart';
import '../services/favorite_service.dart';
import '../theme/app_theme.dart'; // 引入色彩系統

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
                

          SizedBox(
  height: 210, // PlaceCard 的高度，可自行調整
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
        ),
      );
    },
  ),
);
              },
            ),
          ),
            const SizedBox(height: 32), // 底部留白，避免被底部導覽列遮擋
        ],
      ),
    );
  }
}
