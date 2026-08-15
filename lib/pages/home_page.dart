import 'package:flutter/material.dart';

import '../models/place.dart';
import '../services/place_service.dart';
import '../widgets/place_card.dart';
import '../services/favorite_service.dart';
import 'login_screen.dart';
import 'guide_overlay_screen.dart';


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
      appBar: AppBar(
  automaticallyImplyLeading: false,
  backgroundColor: Colors.transparent, // 若有底圖或背景色可設為透明
  elevation: 0,
  // 移除原本的 title，改將所有按鈕都放在 actions
  actions: [
    // 1. 使用指南按鈕（帶書本圖示）
    TextButton.icon(
      onPressed: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false, // 關鍵：設為 false 才能保留背景半透明效果
            barrierDismissible: false,
            pageBuilder: (BuildContext context, _, __) {
              return const GuideOverlayScreen();
            },
          ),
        ); 
      },
      icon: const Icon(
        Icons.menu_book_outlined,
        size: 20,
        color: Colors.black87,
      ),
      label: const Text(
        "使用指南",
        style: TextStyle(
          color: Colors.black87,
          fontSize: 15,
        ),
      ),
    ),

    const SizedBox(width: 4), // 按鈕之間的微調間距

    // 2. 登入按鈕（點擊跳轉至 LoginScreen）
    TextButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      },
      child: const Text(
        "登入",
        style: TextStyle(
          color: Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    const SizedBox(width: 8), // 右側邊緣留白
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
          const SizedBox(height: 24), // 區塊間距

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
                      backgroundColor: Colors.white,      // 白色背景
                      foregroundColor: Colors.black,      // 黑色文字
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
