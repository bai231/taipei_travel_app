import 'dart:ui';
import 'package:flutter/material.dart';

import '../services/favorite_service.dart';
import '../models/place.dart';
import 'guide_overlay_screen.dart'; // 引入使用指南
import 'login_screen.dart';         // 引入登入頁面

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FavoriteService _favoriteService = FavoriteService();
  List<Place> _favorites = [];

  // 色彩配置（草圖綠色系主題）
  static const Color bgColor = Color(0xFFC7DEC8);         // 淺綠水彩底色
  static const Color cardColor = Color(0xFF70B19B);       // 卡片綠色
  static const Color textDark = Color(0xFF1E3A2F);        // 深墨綠文字
  static const Color dividerColor = Color(0xFFA1C6B4);     // 分隔線淡綠色

  @override
  Widget build(BuildContext context) {
    _favorites = _favoriteService.getFavorites();

    return Scaffold(
      backgroundColor: bgColor,
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
                  GestureDetector(
                    onTap: () => showUserGuide(context), // 開啟使用指南
                    child: const Row(
                      children: [
                        Icon(Icons.menu_book_outlined, color: textDark, size: 22),
                        SizedBox(width: 6),
                        Text(
                          "使用指南",
                          style: TextStyle(
                            color: textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      "登入",
                      style: TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 2. 標題：⭐ 我的收藏
              const Row(
                children: [
                  Icon(Icons.star_border_rounded, size: 28, color: textDark),
                  SizedBox(width: 8),
                  Text(
                    "我的收藏",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 3. 景點區塊
              const Text(
                "景點",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 135,
                child: _favorites.isEmpty
                    ? _buildEmptyPlaceholder("尚未收藏任何景點")
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _favorites.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final place = _favorites[index];
                          return _buildFavoritePlaceCard(context, place);
                        },
                      ),
              ),
              _buildSectionDivider(),

              // 4. 行程區塊
              const Text(
                "行程",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 135,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    return _buildTripCard(title: "行程名 ${index + 1}");
                  },
                ),
              ),
              _buildSectionDivider(),

              // 5. 我的資料夾區塊
              const Text(
                "我的資料夾",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 135,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    return _buildFolderCard(
                      context,
                      title: "類別名稱 ${index + 1}",
                    );
                  },
                ),
              ),
              _buildSectionDivider(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // 區塊居中淡色分隔線
  Widget _buildSectionDivider() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        height: 3,
        width: 180,
        decoration: BoxDecoration(
          color: dividerColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // 景點收藏卡片（上方圖片預留、下方文字與 ... 選單）
  Widget _buildFavoritePlaceCard(BuildContext context, Place place) {
    return Container(
      width: 110,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: Text(
              "圖片",
              style: TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    place.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showFrostedMenu(place.name, onCancelFavorite: () {
                    setState(() {
                      _favoriteService.removeFavorite(place);
                    });
                  }),
                  child: const Icon(Icons.more_vert, size: 16, color: textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 行程卡片（純色中央置中文字）
  Widget _buildTripCard({required String title}) {
    return Container(
      width: 110,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
      ),
    );
  }

  // 我的資料夾卡片
  Widget _buildFolderCard(BuildContext context, {required String title}) {
    return Container(
      width: 110,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: Text(
              "圖片",
              style: TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showFrostedMenu(title),
                  child: const Icon(Icons.more_vert, size: 16, color: textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 💡 半透明磨砂選單（取代死板的實色 PopupMenu）
  void _showFrostedMenu(String title, {VoidCallback? onCancelFavorite}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2), // 輕量遮罩
      builder: (BuildContext context) {
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), // 模糊濾鏡
              child: Container(
                width: 180,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85), // 半透明微透底色
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: textDark.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMenuItem(
                      title: '加入行程',
                      icon: Icons.add_circle_outline_rounded,
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已將「$title」加入行程！')),
                        );
                      },
                    ),
                    _buildMenuItem(
                      title: '取消收藏',
                      icon: Icons.delete_outline_rounded,
                      textColor: Colors.redAccent,
                      iconColor: Colors.redAccent,
                      onTap: () {
                        Navigator.pop(context);
                        onCancelFavorite?.call();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已取消收藏「$title」')),
                        );
                      },
                    ),
                    _buildMenuItem(
                      title: '建立資料夾',
                      icon: Icons.create_new_folder_outlined,
                      onTap: () => Navigator.pop(context),
                    ),
                    _buildMenuItem(
                      title: '查看資訊',
                      icon: Icons.info_outline_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color textColor = textDark,
    Color iconColor = textDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  // 空狀態卡片
  Widget _buildEmptyPlaceholder(String text) {
    return Container(
      width: 160,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}