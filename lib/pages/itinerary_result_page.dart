import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/saved_itinerary_service.dart';
import '../features/route_planning/pages/itinerary_result_page.dart' as planner;
import '../features/route_planning/models/route_itinerary.dart';
import '../features/route_planning/services/itinerary_planning_service.dart';
import '../widgets/trip/planner_item_picker.dart';
import '../widgets/trip/planner_favorite_picker_dialog.dart';
import '../models/place.dart';
import '../algorithm/route_optimizer.dart';


import '../features/route_planning/models/route_itinerary.dart';
import '../features/route_planning/models/route_day.dart';
import '../features/route_planning/models/route_visit.dart';
import '../features/route_planning/models/route_travel_mode.dart';
import '../features/route_planning/models/travel_leg.dart';

import '../models/trip_place_constraint.dart';


class ItineraryResultPage extends StatefulWidget {
  final String tripTitle;
  final Map<String, dynamic>? initialSnapshot;

  const ItineraryResultPage({
    super.key,
    required this.tripTitle,
    this.initialSnapshot,
  });

  @override
  State<ItineraryResultPage> createState() => _ItineraryResultPageState();
}

class _ItineraryResultPageState extends State<ItineraryResultPage> {
  // 色彩配置
  static const Color primaryBg = Color(0xFFC7DEC8);
  static const Color dayColumnBg = Colors.white; // 珍珠白大底欄
  static const Color cardColor = Color(0xFFF4F8F5);
  static const Color textDark = Color(0xFF1E3A2F);
  static const Color textSub = Color(0xFF5A7265);
  static const Color accentBrown = Color(0xFF8C7355);

  List<Map<String, dynamic>> _daysData = [];
  final Set<String> _expandedReasons = {};
  bool _isExporting = false;
  

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
      // 1. 還原強型別 RouteItinerary 物件
      final itineraryObj = RouteItinerary.fromSnapshot(widget.initialSnapshot!);

      // 2. 開啟編輯器，並補上隊友要求的回呼功能
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => planner.ItineraryResultPage(
            itinerary: itineraryObj,
            // 🎯 1. 精確對齊 RecalculateItinerary 簽名 (3 個參數)
          onRecalculate: (
            List<TripPlaceConstraint> constraints,
            Map<RouteLegKey, RouteTravelMode> travelModeOverrides,
            RouteItinerary previousItinerary,
          ) async {
          debugPrint("排程重算：約束條件數 = ${constraints.length}");

          try {
            final updatedDays = previousItinerary.days.map((day) {
            final newVisits = <RouteVisit>[];
            int currentSeq = 1;
            int currentMinutes = 540; // 預設早上 09:00

            // 篩選屬於當天的約束站點（若 c.day 為 null 則預設排入當前天數）
            final dayConstraints = constraints.where(
              (c) => c.day == null || c.day == day.day,
            );

            for (final c in dayConstraints) {
            // 🌟 1. 取得開始時間：優先使用使用者鎖定/指定的 c.startMinutes
            final start = c.startMinutes ?? currentMinutes;
        
            // 🌟 2. 取得停留時長：直接呼叫 c.stayMinutes (由 preferences.durationFor 計算)
            final stay = c.stayMinutes > 0 ? c.stayMinutes : (c.place.stayTime > 0 ? c.place.stayTime : 60);
            final end = start + stay;

            newVisits.add(
              RouteVisit(
                place: c.place,
                sequence: currentSeq++,
                arrivalMinutes: start,
                startMinutes: start,
                endMinutes: end,
                waitingMinutes: 0,
                stayMinutes: stay,
                requestedStartMinutes: c.startMinutes,
                locked: c.locked, // 🌟 3. 使用真實的 c.locked 屬性
                information: const [],
              ),
            );

            // 如果該站點不是手動鎖定固定時間，自動為下一站推遲（加上 30 分鐘交通緩衝）
            currentMinutes = end + 30;
          }

          return RouteDay(
            day: day.day,
            date: day.date,
            origin: day.origin,
            visits: newVisits.isNotEmpty ? newVisits : day.visits,
            travelLegs: day.travelLegs,
            isValid: true,
            warnings: day.warnings,
          );
        }).toList();

        return RouteItinerary(
          request: previousItinerary.request,
          origin: previousItinerary.origin,
          days: updatedDays,
          generatedAt: DateTime.now(),
          warnings: previousItinerary.warnings,
          travelModeOverrides: travelModeOverrides,
        );
      } catch (e) {
      debugPrint("重算處理失敗: $e");
      return previousItinerary;
    }
  },
            onAddPlace: (BuildContext ctx, Set<String> selectedPlaceIds) async {
  List<Place> pickedPlaces = <Place>[];

  // 彈出「從收藏 / 資料夾加入景點」的磨砂彈窗
  await showDialog<void>(
    context: ctx,
    builder: (dialogCtx) => PlannerFavoritePickerDialog(
      onPlacesConfirmed: (List<Place> selected) {
        pickedPlaces = selected; // 取得使用者勾選的景點物件清單
      },
    ),
  );

  // 🌟 必須將選到的 List<Place> 回傳給編輯器
  return pickedPlaces;
},
            // 🌟 3. 頂部編輯筆按鈕
            onEdit: () {
              debugPrint("點擊了編輯行程資訊");
            },

            // 🌟 4. 頂部匯出按鈕（可直接連動原有的儲存/匯出功能）
            onExport: () {
              _exportItinerary();
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

  // ☁️ 匯出行程至 Supabase
  Future<void> _exportItinerary() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入帳號以儲存行程 🌿')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final savedService = SavedItineraryService(Supabase.instance.client);
      final String snapshotId = DateTime.now()
          .millisecondsSinceEpoch
          .toRadixString(16)
          .padLeft(32, '0');

      await savedService.save(
        userId: user.id,
        id: snapshotId,
        title: widget.tripTitle,
        snapshot: widget.initialSnapshot ?? {},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${widget.tripTitle}」已成功儲存至個人紀錄！🎉')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
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
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textDark),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.tripTitle,
                      style: const TextStyle(
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
                    bgColor: const Color(0xFF8C7355).withValues(alpha: 0.15),
                    textColor: textDark,
                    onTap: _backToEditPage,
                  ),
                  const SizedBox(width: 8),
                  // 🌟 匯出儲存按鈕
                  _isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: textDark),
                        )
                      : _buildCapsuleButton(
                          label: "匯出",
                          icon: Icons.bookmark_add_outlined,
                          bgColor: const Color(0xFF70B19B),
                          textColor: Colors.white,
                          onTap: _exportItinerary,
                        ),
                ],
              ),
            ),

            // 橫向滑動多日行程（純瀏覽）
            Expanded(
              child: _daysData.isEmpty
                  ? const Center(
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
            style: const TextStyle(
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
                    style: const TextStyle(
                      color: accentBrown,
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
                          style: const TextStyle(
                            color: textDark,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "建議停留 ${spot["stayTime"]} 分鐘",
                          style: const TextStyle(color: textSub, fontSize: 12),
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
                        style: const TextStyle(color: accentBrown, fontSize: 12),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 16,
                        color: accentBrown,
                      ),
                    ],
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 6),
                  Text(
                    spot["reason"],
                    style: const TextStyle(color: textDark, fontSize: 12, height: 1.4),
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
                const Icon(Icons.directions_bus_rounded, size: 15, color: accentBrown),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    transit,
                    style: const TextStyle(color: textSub, fontSize: 11),
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