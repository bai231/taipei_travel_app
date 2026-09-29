import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/place.dart';
import '../../services/user_data_service.dart';
import '../../services/favorite_service.dart';

/// 從「我的收藏 / 資料夾」選擇景點加入行程的磨砂風格彈窗
class PlannerFavoritePickerDialog extends StatefulWidget {
  final Function(List<Place> selectedPlaces) onPlacesConfirmed;

  const PlannerFavoritePickerDialog({
    super.key,
    required this.onPlacesConfirmed,
  });

  @override
  State<PlannerFavoritePickerDialog> createState() =>
      _PlannerFavoritePickerDialogState();
}

class _PlannerFavoritePickerDialogState
    extends State<PlannerFavoritePickerDialog> {
  final UserDataService _userDataService = UserDataService();
  final FavoriteService _favoriteService = FavoriteService();

  // 主題配色（清新水彩綠調）
  static const Color primaryDark = Color(0xFF1E3A2F);
  static const Color cardBg = Color(0xFF70B19B);
  static const Color lightBg = Color(0xFFF2F6F3);

  bool _isLoading = true;
  List<Map<String, dynamic>> _folders = [];
  List<Place> _allFavorites = [];

  // 目前選中的資料夾 ID（null 代表「全部收藏」）
  int? _selectedFolderId;
  // 已勾選準備加入行程的景點
  final Set<String> _selectedPlaceIds = {};

  @override
  void initState() {
    super.initState();
    _loadFavoritesAndFolders();
  }

  Future<void> _loadFavoritesAndFolders() async {
    setState(() => _isLoading = true);
    try {
      // 1. 確保雲端收藏與資料夾載入
      await _favoriteService.fetchFavoritesFromCloud();
      final folders = await _userDataService.fetchFolders();

      if (mounted) {
        setState(() {
          _allFavorites = _favoriteService.getFavorites();
          _folders = folders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 根據選中的資料夾，過濾要顯示的景點清單
  List<Place> get _currentDisplayPlaces {
    if (_selectedFolderId == null) {
      return _allFavorites;
    }
    // 找出所選資料夾內符合條件的景點
    final folder = _folders.firstWhere(
      (f) => f['id'] == _selectedFolderId,
      orElse: () => {'places': <Place>[]},
    );
    final folderPlaces = List<Place>.from(folder['places'] ?? []);
    // 依契約：目錄 ∩ favorites ∩ folder_places
    return folderPlaces.where((p) => _favoriteService.isFavorite(p)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.88,
        height: 520,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 頂部標題與關閉按鈕
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bookmark_add_rounded, color: primaryDark, size: 22),
                    SizedBox(width: 8),
                    Text(
                      "從收藏加入景點",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryDark,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. 資料夾切換膠囊橫條
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFolderChip(
                    label: "全部收藏 (${_allFavorites.length})",
                    isSelected: _selectedFolderId == null,
                    onTap: () => setState(() => _selectedFolderId = null),
                  ),
                  ..._folders.map((folder) {
                    final int fId = folder['id'];
                    final String title = folder['title'] ?? '資料夾';
                    final places = List<Place>.from(folder['places'] ?? []);
                    return _buildFolderChip(
                      label: "$title (${places.length})",
                      isSelected: _selectedFolderId == fId,
                      onTap: () => setState(() => _selectedFolderId = fId),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. 景點多選列表
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _currentDisplayPlaces.isEmpty
                      ? const Center(
                          child: Text(
                            "此分類暫無可加入的景點",
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _currentDisplayPlaces.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final place = _currentDisplayPlaces[index];
                            final isChecked = _selectedPlaceIds.contains(place.id);

                            return CheckboxListTile(
                              value: isChecked,
                              activeColor: cardBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                              title: Text(
                                place.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryDark,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                "${place.category} · ⭐ ${place.rating}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: primaryDark.withValues(alpha: 0.6),
                                ),
                              ),
                              onChanged: (bool? val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedPlaceIds.add(place.id);
                                  } else {
                                    _selectedPlaceIds.remove(place.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
            ),

            const SizedBox(height: 12),

            // 4. 底部確認加入按鈕
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  elevation: 0,
                ),
                onPressed: _selectedPlaceIds.isEmpty
                    ? null
                    : () {
                        // 挑出選中的景點物件
                        final selectedPlaces = _allFavorites
                            .where((p) => _selectedPlaceIds.contains(p.id))
                            .toList();
                        widget.onPlacesConfirmed(selectedPlaces);
                        Navigator.pop(context);
                      },
                child: Text(
                  "加入行程 (${_selectedPlaceIds.length})",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 橫向資料夾標籤
  Widget _buildFolderChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryDark : lightBg,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : primaryDark,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}