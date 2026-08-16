import 'package:flutter/material.dart';

import '../models/place.dart';
import '../services/place_service.dart';
import '../widgets/place_card.dart';
import '../services/favorite_service.dart';
import '../theme/app_theme.dart'; // 引入色彩系統

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  final List<String> photoList = const [
            'assets/test1.jpg',
            'assets/test2.jpg',
            'assets/test3.jpg',
          ];

  @override
  Widget build(BuildContext context) {
    final PlaceService placeService = PlaceService();

    final List<Place> places = placeService.getPlaces();

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
                itemCount: photoList.length, // 照片數量
                separatorBuilder: (context, index) => const SizedBox(width: 12), // 自動產生中間間距
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

          

          SizedBox(
            height: 210, // PlaceCard 的高度，可自行調整
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
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16), // 區塊間距

          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 白色圓角「手動排程」按鈕
                  ElevatedButton(
                    onPressed: () {
                      // 點擊手動排程按鈕後要執行的動作（例如跳轉到排程頁面）
                      print("點擊了手動排程");
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.background,     // 白色背景
                      foregroundColor: AppColors.textPrimary,      // 文字
                      elevation: 2,                       // 微陰影
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24), // 圓角外觀
                      ),
                    ),
                    child: const Text(
                      "手動排程",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16), // 按鈕與說明的間距
                  
                ],
              ),
            ),

            const SizedBox(height: 32), // 底部留白，避免被底部導覽列遮擋
        ],
      ),
    );
  }
}
