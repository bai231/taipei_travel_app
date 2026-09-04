import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/favorite_service.dart';
import '../models/place.dart';
import 'itinerary_result_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FavoriteService _favoriteService = FavoriteService();

  // 模擬行程與資料夾資料（指定明確型別避免轉型錯誤）
  final List<String> _itineraries = ["台北一日遊", "九份文化之旅"];
  final List<Map<String, dynamic>> _folders = [
    {"title": "必去美食", "places": <Place>[]},
    {"title": "拍照打卡", "places": <Place>[]},
  ];

  @override
  void initState() {
    super.initState();
    // 1. 監聽收藏狀態變化（首頁或詳情頁按愛心時，這裡自動同步刷新）
    _favoriteService.addListener(_onFavoritesChanged);
    // 🌟 關鍵修復：進入頁面時主動向 Supabase 撈取雲端收藏！
    _favoriteService.fetchFavoritesFromCloud();
  }

  @override
  void dispose() {
    _favoriteService.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // 1. 三個點點的磨砂選單
  void _showFrostedMenu(BuildContext parentContext, Place place) {
    showDialog(
      context: parentContext,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.2),
      builder: (dialogCtx) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: 190,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.surface.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. 加入行程
                      _buildDialogOption(
                        icon: Icons.add_circle_outline_rounded,
                        label: '加入行程',
                        onTap: () {
                          Navigator.pop(dialogCtx);
                          _showAddToTripDialog(parentContext, place);
                        },
                      ),

                      // 2. 加入資料夾
                      _buildDialogOption(
                        icon: Icons.folder_open_rounded,
                        label: '加入資料夾',
                        onTap: () {
                          Navigator.pop(dialogCtx);
                          _showSelectFolderDialog(parentContext, place);
                        },
                      ),

                      // 3. 取消收藏（安全呼叫 toggleFavorite）
                      _buildDialogOption(
                        icon: Icons.favorite_border_rounded,
                        label: '取消收藏',
                        textColor: Colors.redAccent,
                        iconColor: Colors.redAccent,
                        onTap: () async {
                          Navigator.pop(dialogCtx);
                          await _favoriteService.toggleFavorite(place);
                          if (parentContext.mounted) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(content: Text('已取消收藏「${place.name}」')),
                            );
                          }
                        },
                      ),

                      // 4. 查看資訊
                      _buildDialogOption(
                        icon: Icons.info_outline_rounded,
                        label: '查看資訊',
                        onTap: () {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(content: Text('查看「${place.name}」詳細資訊')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    final effectiveTextColor = textColor ?? AppColors.textPrimary;
    final effectiveIconColor = iconColor ?? AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: effectiveIconColor),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: effectiveTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. 點開查看「資料夾內容」的彈窗視窗
  void _showFolderContentDialog(BuildContext parentContext, Map<String, dynamic> folder) {
    showDialog(
      context: parentContext,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final List<Place> places = List<Place>.from(folder["places"] as Iterable);

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.folder_open_rounded, color: AppColors.primaryDark, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      folder["title"].toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    "(${places.length})",
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: places.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: Text(
                            "資料夾內尚無景點\n可在景點右下角選單選擇「加入資料夾」",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
                          ),
                        ),
                      )
                    : ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: places.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.black12),
                          itemBuilder: (context, index) {
                            final place = places[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.place_outlined, color: AppColors.textPrimary, size: 20),
                              ),
                              title: Text(
                                place.name,
                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                tooltip: "移出資料夾",
                                onPressed: () {
                                  setModalState(() {
                                    places.removeAt(index);
                                    folder["places"] = places;
                                  });
                                  setState(() {});
                                },
                              ),
                            );
                          },
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("關閉", style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 3. 選擇資料夾彈窗
  void _showSelectFolderDialog(BuildContext parentContext, Place place) {
    showDialog(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "加入資料夾",
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_folders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    "目前尚無任何資料夾",
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _folders.length,
                    itemBuilder: (context, index) {
                      final folder = _folders[index];
                      return ListTile(
                        leading: const Icon(Icons.folder_outlined, color: AppColors.textPrimary),
                        title: Text(
                          folder["title"].toString(),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(Icons.add, color: AppColors.textPrimary),
                        onTap: () {
                          setState(() {
                            final List<Place> list = List<Place>.from(folder["places"] as Iterable);
                            list.add(place);
                            folder["places"] = list;
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(content: Text("已將「${place.name}」加入資料夾「${folder["title"]}」！")),
                          );
                        },
                      );
                    },
                  ),
                ),
              const Divider(),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showCreateFolderDialog(parentContext, place);
                },
                icon: const Icon(Icons.create_new_folder_outlined, color: AppColors.primaryDark),
                label: const Text(
                  "建立新資料夾",
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 4. 建立資料夾彈窗
  void _showCreateFolderDialog(BuildContext parentContext, Place place) {
    final TextEditingController folderController = TextEditingController();
    showDialog(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "建立資料夾",
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: folderController,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: "請輸入資料夾名稱",
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.surface,
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              final folderName = folderController.text.trim();
              if (folderName.isNotEmpty) {
                setState(() {
                  _folders.add({
                    "title": folderName,
                    "places": <Place>[place],
                  });
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(content: Text("已建立「$folderName」並將「${place.name}」移入！")),
                );
              }
            },
            child: const Text("建立", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 5. 加入行程彈窗
  void _showAddToTripDialog(BuildContext parentContext, Place place) {
    showDialog(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "加入行程",
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _itineraries.length,
            itemBuilder: (context, index) {
              final trip = _itineraries[index];
              return ListTile(
                title: Text(
                  trip,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                ),
                trailing: const Icon(Icons.add, color: AppColors.textPrimary),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(content: Text("已將「${place.name}」加入「$trip」！")),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = _favoriteService.getFavorites();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題：我的收藏
              const Row(
                children: [
                  Icon(Icons.star_border_rounded, size: 28, color: AppColors.textPrimary),
                  SizedBox(width: 8),
                  Text(
                    "我的收藏",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 景點區塊
              const Text(
                "景點",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 130,
                child: favorites.isEmpty
                    ? _buildEmptyState("尚未收藏任何景點")
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: favorites.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final place = favorites[index];
                          return _buildPlaceCard(place);
                        },
                      ),
              ),

              const SizedBox(height: 28),

              // 行程區塊
              const Text(
                "行程",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _itineraries.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    return _buildTripCard(_itineraries[index]);
                  },
                ),
              ),

              const SizedBox(height: 28),

              // 我的資料夾區塊
              const Text(
                "我的資料夾",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 130,
                child: _folders.isEmpty
                    ? _buildEmptyState("尚未建立任何資料夾")
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _folders.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final folder = _folders[index];
                          return _buildFolderCard(folder);
                        },
                      ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // 景點卡片
  Widget _buildPlaceCard(Place place) {
    return Container(
      width: 110,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 28),
            child: Text(
              '圖片',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showFrostedMenu(context, place),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.more_vert, size: 18, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 行程卡片
  Widget _buildTripCard(String title) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque, // 確保整張卡片區域都能被點擊
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ItineraryResultPage(tripTitle: title),
        ),
      );
    },
    child: Container(
      width: 110,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        title,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

  // 資料夾卡片
  Widget _buildFolderCard(Map<String, dynamic> folder) {
    final title = folder["title"].toString();
    final places = List<Place>.from(folder["places"] as Iterable);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showFolderContentDialog(context, folder),
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.folder_open_rounded, size: 30, color: AppColors.textPrimary),
                  if (places.isNotEmpty)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryDark,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "${places.length}",
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Center(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 空狀態
  Widget _buildEmptyState(String text) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 8.0),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }
}
