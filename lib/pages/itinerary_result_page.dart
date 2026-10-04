import 'package:flutter/material.dart';
import '../features/route_planning/pages/itinerary_result_page.dart' as planner;
import '../features/route_planning/models/route_itinerary.dart';
import '../features/route_planning/services/itinerary_planning_service.dart';
import '../features/route_planning/services/itinerary_place_resolver.dart';
import '../services/place_service.dart';
import '../widgets/trip/planner_favorite_picker_dialog.dart';
import '../models/place.dart';
import '../features/route_planning/models/route_place_input.dart';
import '../theme/app_colors.dart';



class ItineraryResultPage extends StatefulWidget {
  final String tripTitle;
  final Map<String, dynamic>? initialSnapshot;
  final String? savedItineraryId;
  final String? savedItineraryUserId;

  const ItineraryResultPage({
    super.key,
    required this.tripTitle,
    this.initialSnapshot,
    this.savedItineraryId,
    this.savedItineraryUserId,
  });

  @override
  State<ItineraryResultPage> createState() => _ItineraryResultPageState();
}

class _ItineraryResultPageState extends State<ItineraryResultPage> {
  // 色彩配置
  static Color get primaryBg => AppColors.background;
  static const Color dayColumnBg = Colors.white; // 珍珠白大底欄
  static Color get cardColor => AppColors.surface;
  static Color get textDark => AppColors.textPrimary;
  static Color get textSub => AppColors.textSecondary;
  static Color get accentColor => AppColors.primary;

  List<Map<String, dynamic>> _daysData = [];
  final Set<String> _expandedReasons = {};
  

  @override
  void initState() {
    super.initState();
    if (widget.initialSnapshot != null && widget.initialSnapshot!['days'] != null) {
      _daysData = _convertSnapshotToDaysData(widget.initialSnapshot!);
    }
  }

  // 🔄 精準解析 Snapshot v2 快照
  List<Map<String, dynamic>> _convertSnapshotToDaysData(Map<String, dynamic> snapshot) {
    final rawDays = (snapshot['days'] as List<dynamic>? ?? []);

    return rawDays.map<Map<String, dynamic>>((day) {
      final dayMap = day as Map<String, dynamic>;
      final int dayNumber = dayMap['day'] ?? 1;
      final String dayTitle = "Day $dayNumber";

      final rawVisits = (dayMap['visits'] as List<dynamic>? ?? []);
      final rawLegs = (dayMap['travelLegs'] as List<dynamic>? ?? []);

      final spots = rawVisits.asMap().entries.map((entry) {
        final index = entry.key;
        final visit = entry.value as Map<String, dynamic>;
        final place = (visit['place'] as Map<String, dynamic>? ?? {});

        // 將分鐘數轉成 HH:mm 格式
        final int minutes = visit['startMinutes'] ?? visit['arrivalMinutes'] ?? 540;
        final int hour = (minutes ~/ 60) % 24;
        final int minute = minutes % 60;
        final String formattedTime =
            "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";

        // 交通連線文字
        String transitText = "";
        if (index < rawLegs.length) {
          final leg = rawLegs[index] as Map<String, dynamic>;
          final String mode = leg['travelMode']?.toString() ?? '';
          final route = leg['route'] as Map<String, dynamic>?;

          if (route != null && route['travelTime'] != null) {
            transitText = "$mode 約 ${route['travelTime']} 分鐘";
          } else {
            transitText = mode.isNotEmpty ? "搭乘 $mode 前往" : "搭乘大眾運輸前往";
          }
        }

        final String spotName = place['name']?.toString() ?? "未命名景點";
        final String category = place['category']?.toString() ?? "精選地標";
        final String reason = (visit['information']?.toString().isNotEmpty == true)
            ? visit['information'].toString()
            : (place['description']?.toString() ?? "推薦參訪景點");

        return {
          "id": "spot_${dayNumber}_$index",
          "placeId": place['id'] ?? index,
          "name": spotName,
          "category": category,
          "time": formattedTime,
          "stayTime": visit['stayMinutes'] ?? place['stayTime'] ?? 60,
          "transit": transitText,
          "reason": reason,
        };
      }).toList();

      return {
        "dayTitle": dayTitle,
        "spots": spots,
      };
    }).toList();
  }

  void _backToEditPage() {
    if (widget.initialSnapshot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無行程快照資料可編輯')),
      );
      return;
    }

    try {
      final itinerary = RouteItinerary.fromSnapshot(widget.initialSnapshot!);
      final planningService = ItineraryPlanningService();
      final placeService = PlaceService();
      const placeResolver = ItineraryPlaceResolver();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => planner.ItineraryResultPage(
            itinerary: itinerary,
            savedItineraryId: widget.savedItineraryId,
            savedItineraryUserId: widget.savedItineraryUserId,
            initialMapVisible: true,
            onRecalculate: (constraints, travelModeOverrides, previous) {
              final inputs = constraints
                  .map((constraint) => RoutePlaceInput(
                        place: constraint.place,
                        day: constraint.day,
                        startMinutes: constraint.startMinutes,
                        locked: constraint.locked,
                        kind: constraint.kind,
                        suggestedMealType: constraint.suggestedMealType,
                        preferences: constraint.preferences,
                      ))
                  .toList();
              return planningService.generate(
                request: previous.request,
                places: inputs,
                travelModeOverrides: travelModeOverrides,
                reusableItinerary: previous,
              );
            },
            onResolvePlaceQuery: (query, excludedPlaceIds) async {
              final catalog = await placeService.getTripCatalog();
              return placeResolver.search(
                query: query,
                places: catalog,
                excludedPlaceIds: excludedPlaceIds,
                preferredLocations: itinerary.request.locations,
              );
            },
            onAddPlace: (ctx, selectedPlaceIds) async {
              var pickedPlaces = <Place>[];
              await showDialog<void>(
                context: ctx,
                builder: (dialogCtx) => PlannerFavoritePickerDialog(
                  onPlacesConfirmed: (selected) => pickedPlaces = selected,
                ),
              );
              return pickedPlaces;
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('轉檔或開啟編輯器失敗: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('開啟排程編輯器失敗：$e')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            // 頂部導覽列
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: textDark),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.tripTitle,
                      style: TextStyle(
                        color: textDark,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 🌟 編輯行程按鈕
                  _buildCapsuleButton(
                    label: "編輯",
                    icon: Icons.edit_note_rounded,
                    bgColor: AppColors.primary.withValues(alpha: 0.15),
                    textColor: textDark,
                    onTap: _backToEditPage,
                  ),
                ],
              ),
            ),

            // 橫向滑動多日行程（純瀏覽）
            Expanded(
              child: _daysData.isEmpty
                  ? Center(
                      child: Text(
                        "查無行程內容",
                        style: TextStyle(color: textSub, fontSize: 16),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      scrollDirection: Axis.horizontal,
                      itemCount: _daysData.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, dayIndex) {
                        return _buildDayColumn(dayIndex);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 單天直欄容器
  Widget _buildDayColumn(int dayIndex) {
    final day = _daysData[dayIndex];
    final spots = day["spots"] as List<dynamic>;

    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: dayColumnBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: textDark.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day["dayTitle"],
            style: TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // 景點列表（純展示 ListView，移除 Reorderable）
          Expanded(
            child: ListView.builder(
              itemCount: spots.length,
              itemBuilder: (context, spotIndex) {
                final spot = spots[spotIndex];
                return _buildSpotItem(spot, spotIndex, spots.length);
              },
            ),
          ),
        ],
      ),
    );
  }

  // 景點卡片項目（純閱讀 + 展開推薦理由）
  Widget _buildSpotItem(Map<String, dynamic> spot, int index, int total) {
    final bool isExpanded = _expandedReasons.contains(spot["id"]);
    final String transit = spot["transit"] ?? "";

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 時間標籤（純文字展示）
                  Text(
                    spot["time"] ?? "",
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 景點名稱與停留時間
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spot["name"] ?? "",
                          style: TextStyle(
                            color: textDark,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "建議停留 ${spot["stayTime"]} 分鐘",
                          style: TextStyle(color: textSub, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // 查看推薦理由（手帳展開）
              if ((spot["reason"] ?? "").toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedReasons.remove(spot["id"]);
                      } else {
                        _expandedReasons.add(spot["id"]);
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        isExpanded ? "收起推薦理由" : "查看推薦理由",
                        style: TextStyle(color: accentColor, fontSize: 13),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 16,
                        color: accentColor,
                      ),
                    ],
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 6),
                  Text(
                    spot["reason"],
                    style: TextStyle(color: textDark, fontSize: 13, height: 1.4),
                  ),
                ],
              ],
            ],
          ),
        ),
        // 景點之間的交通銜接
        if (transit.isNotEmpty && index < total - 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.directions_bus_rounded, size: 15, color: accentColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    transit,
                    style: TextStyle(color: textSub, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // 頂部小膠囊按鈕
  Widget _buildCapsuleButton({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
