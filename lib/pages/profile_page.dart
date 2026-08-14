import 'package:flutter/material.dart';

import '../services/favorite_service.dart';
import '../models/place.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FavoriteService _favoriteService = FavoriteService();
  List<Place> _favorites = [];

  @override
  Widget build(BuildContext context) {
    _favorites = _favoriteService.getFavorites();

    return Scaffold(
      backgroundColor: Colors.white, // 純白背景
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 頂部列：使用指南 & 登入
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.menu_book, color: Colors.black, size: 20),
                    label: const Text(
                      "使用指南",
                      style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      "登入",
                      style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. 標題：⭐ 我的收藏
              const Row(
                children: [
                  Icon(Icons.star_border, size: 26, color: Colors.black),
                  SizedBox(width: 8),
                  Text(
                    "我的收藏",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: -0.5),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 3. 景點區塊
              const Text("景點", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 12),
              SizedBox(
                height: 130,
                child: _favorites.isEmpty
                    ? _buildEmptyPlaceholder("尚未收藏任何景點")
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _favorites.length,
                        itemBuilder: (context, index) {
                          final place = _favorites[index];
                          return _buildFavoritePlaceCard(context, place);
                        },
                      ),
              ),

              const SizedBox(height: 24),

              // 4. 行程區塊
              const Text("行程", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 12),
              SizedBox(
                height: 130,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 2,
                  itemBuilder: (context, index) {
                    return _buildSimpleCard(
                      title: "行程名稱 ${index + 1}",
                      showImage: false,
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // 5. 我的資料夾區塊
              const Text("我的資料夾", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 12),
              SizedBox(
                height: 130,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 2,
                  itemBuilder: (context, index) {
                    return _buildSimpleCard(
                      title: "類別名稱 ${index + 1}",
                      showImage: true,
                    );
                  },
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // 💡 黑底白字 / 細邊框的極簡卡片
  Widget _buildFavoritePlaceCard(BuildContext context, Place place) {
    return Container(
      width: 125,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.black, // 純黑背景
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_outlined, size: 30, color: Colors.white70),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    place.name,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.white),
                  onSelected: (value) {},
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(value: 'add_to_itinerary', child: Text('加入行程')),
                    const PopupMenuItem(value: 'cancel_favorite', child: Text('取消收藏')),
                    const PopupMenuItem(value: 'create_folder', child: Text('建立資料夾')),
                    const PopupMenuItem(value: 'view_info', child: Text('查看資訊')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 💡 極簡白底線條卡片
  Widget _buildSimpleCard({required String title, required bool showImage}) {
    return Container(
      width: 125,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6), // 極淺灰背景
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showImage) ...[
            const Icon(Icons.image_outlined, size: 30, color: Colors.black54),
            const SizedBox(height: 8),
          ],
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder(String text) {
    return Container(
      width: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(text, style: const TextStyle(color: Colors.black45, fontSize: 12)),
    );
  }
}