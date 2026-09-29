import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/place.dart';
import '../services/favorite_service.dart';
import '../theme/app_colors.dart';
import '../utils/map_launcher.dart';

class PlaceDetailPage extends StatefulWidget {
  final Place place;

  const PlaceDetailPage({super.key, required this.place});

  @override
  State<PlaceDetailPage> createState() => _PlaceDetailPageState();
}

class _PlaceDetailPageState extends State<PlaceDetailPage> {
  final FavoriteService _favoriteService = FavoriteService();

  @override
  void initState() {
    super.initState();
    // 監聽收藏變更，確保首頁或個人頁變動時愛心即時同步
    _favoriteService.addListener(_onFavoritesChanged);
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

  Future<void> _openPhone(String phone) async {
    await _launchExternal(Uri(scheme: 'tel', path: phone), '無法開啟電話功能');
  }

  Future<void> _openWebsite(String website) async {
    final normalized =
        website.startsWith('http://') || website.startsWith('https://')
        ? website
        : 'https://$website';
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      _showLaunchError('網站網址格式不正確');
      return;
    }
    await _launchExternal(uri, '無法開啟網站');
  }

  Future<void> _launchExternal(Uri uri, String errorMessage) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) _showLaunchError(errorMessage);
    } catch (_) {
      _showLaunchError(errorMessage);
    }
  }

  void _showLaunchError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final isFav = _favoriteService.isFavorite(place);

    // 取得文字與主色（若尚未設定 textPrimary 則自動使用 primaryDark 兜底）
    final Color textColor = AppColors.primaryDark;
    final Color subTextColor = AppColors.primaryDark.withValues(alpha: 0.65);
    final typeLabel = switch (place.type) {
      PlaceType.attraction => '景點',
      PlaceType.restaurant => '餐廳',
      PlaceType.accommodation => '住宿',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          place.name,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? Colors.redAccent : textColor,
              size: 26,
            ),
            onPressed: () {
              try {
                final added = _favoriteService.toggleFavorite(place);

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 1),
                    content: Text(
                      added
                          ? '已將「${place.name}」加入收藏 ⭐️'
                          : '已將「${place.name}」移出收藏',
                    ),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 景點圖片展示（220px 圓角滿版圖）
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: place.image.isNotEmpty
                  ? Image.network(
                      place.image,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildImagePlaceholder(),
                    )
                  : _buildImagePlaceholder(),
            ),

            const SizedBox(height: 20),

            // 2. 標籤與評分資訊
            Row(
              children: [
                // 類別膠囊標籤
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    place.category,
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.star_rounded, color: AppColors.accent, size: 22),
                const SizedBox(width: 4),
                Text(
                  place.rating.toStringAsFixed(1),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Icon(Icons.schedule_rounded, size: 18, color: subTextColor),
                const SizedBox(width: 4),
                Text(
                  "建議 ${place.stayTime} 分鐘",
                  style: TextStyle(color: subTextColor, fontSize: 13),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 3. 介紹區塊（手帳便籤卡片容器，支援自動換行與舒適行距）
            Text(
              "$typeLabel介紹",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: textColor.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                place.description.trim().isEmpty ? "暫無詳細介紹" : place.description,
                softWrap: true, // 自動換行
                style: TextStyle(
                  fontSize: 15,
                  height: 1.65, // 行距舒適易讀
                  color: textColor,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 4. 地址資訊
            if (place.address.isNotEmpty) ...[
              Text(
                "$typeLabel地址",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: textColor.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primaryDark,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        place.address,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    ElevatedButton.icon(
                      onPressed: () => MapLauncher.openGoogleMaps(place),
                      icon: const Icon(Icons.navigation_rounded, size: 14),
                      label: const Text(
                        "導航",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (place.phone.isNotEmpty ||
                place.website.isNotEmpty ||
                place.openingHours.isNotEmpty ||
                place.openingHoursRaw.trim().isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                '詳細資訊',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: textColor.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (place.website.isNotEmpty)
                      _buildDetailRow(
                        icon: Icons.language_rounded,
                        child: Text(
                          place.website,
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primaryDark,
                          ),
                        ),
                        onTap: () => _openWebsite(place.website),
                      ),
                    if (place.website.isNotEmpty &&
                        (place.phone.isNotEmpty ||
                            place.openingHours.isNotEmpty ||
                            place.openingHoursRaw.trim().isNotEmpty))
                      const Divider(height: 1),
                    if (place.phone.isNotEmpty)
                      _buildDetailRow(
                        icon: Icons.phone_outlined,
                        child: Text(
                          place.phone,
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primaryDark,
                          ),
                        ),
                        onTap: () => _openPhone(place.phone),
                      ),
                    if (place.phone.isNotEmpty &&
                        (place.openingHours.isNotEmpty ||
                            place.openingHoursRaw.trim().isNotEmpty))
                      const Divider(height: 1),
                    if (place.openingHours.isNotEmpty ||
                        place.openingHoursRaw.trim().isNotEmpty)
                      _buildOpeningHours(place, textColor),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primaryDark, size: 22),
            const SizedBox(width: 12),
            Expanded(child: child),
            if (onTap != null)
              Icon(
                Icons.open_in_new_rounded,
                color: AppColors.textSecondary,
                size: 17,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpeningHours(Place place, Color textColor) {
    final hours = place.openingHours.isNotEmpty
        ? place.openingHours
        : [place.openingHoursRaw.trim()];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule_outlined, color: AppColors.primaryDark, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                for (var index = 0; index < hours.length; index++) ...[
                  _buildOpeningHourLine(hours[index], textColor),
                  if (index != hours.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpeningHourLine(String value, Color textColor) {
    final separator = value.indexOf(RegExp('[:：]'));
    if (separator <= 0) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(value, style: TextStyle(color: textColor, height: 1.35)),
      );
    }
    final day = value.substring(0, separator).trim();
    final hours = value.substring(separator + 1).trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(day, style: TextStyle(color: textColor, height: 1.35)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            hours,
            textAlign: TextAlign.end,
            style: TextStyle(color: textColor, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 220,
      width: double.infinity,
      color: AppColors.primaryLight.withValues(alpha: 0.3),
      child: Center(
        child: Icon(
          Icons.landscape_rounded,
          size: 60,
          color: AppColors.primaryDark.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
