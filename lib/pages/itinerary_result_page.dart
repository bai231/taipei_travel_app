import 'package:flutter/material.dart';
import 'place_detail_page.dart';
import '../models/place.dart';

class ItineraryResultPage extends StatefulWidget {
  final String tripTitle;

  const ItineraryResultPage({
    super.key,
    this.tripTitle = "台北文藝慢活之旅",
  });

  @override
  State<ItineraryResultPage> createState() => _ItineraryResultPageState();
}

class _ItineraryResultPageState extends State<ItineraryResultPage> {
  // 色彩配置：高透白手帳卡片底色與水彩綠
  static const Color pageBgColor = Color(0xFFC7DEC8);       // 淺水彩綠底色[cite: 1]
  static final Color dayColumnBg = Colors.white.withValues(alpha: 0.88); // 高透白天數底色
  static const Color cardBg = Color(0xFF70B19B);           // 景點卡片青綠色[cite: 1]
  static const Color dividerColor = Color(0xFF5A9B85);     // 卡片內部分隔線
  static const Color textDark = Color(0xFF1E3A2F);         // 墨綠主文字[cite: 1]

  final TextEditingController _promptController = TextEditingController();

  // 追蹤展開推薦理由的狀態（以 spot['id'] 識別，避免拖曳換順序時展開錯亂）
  final Set<String> _expandedSpotIds = {};

  // 多日排程資料（每個景點加上唯一 id 供 Reorderable Key 與展開使用）
  final List<Map<String, dynamic>> _daysData = [
    {
      "dayTitle": "day1",
      "spots": [
        {
          "id": "s1_1",
          "name": "故宮博物院",
          "category": "文藝展覽",
          "time": "09:00",
          "stayTime": 120,
          "transit": "搭乘紅30公車約 15 分鐘",
          "reason": "館藏豐富，早晨人潮相對少，非常適合安排為第一站靜心品味歷史底蘊。"
        },
        {
          "id": "s1_2",
          "name": "士林官邸",
          "category": "歷史古蹟",
          "time": "11:30",
          "stayTime": 60,
          "transit": "搭乘捷運淡水信義線約 25 分鐘",
          "reason": "中西合璧的花園造景，平緩步道非常適合放慢腳步散步拍照。"
        },
        {
          "id": "s1_3",
          "name": "台北 101 景觀台",
          "category": "現代地標",
          "time": "14:30",
          "stayTime": 90,
          "transit": "步行約 15 分鐘",
          "reason": "俯瞰整個台北盆地的絕佳制高點，午後光線透亮很適合眺望市景。"
        },
        {
          "id": "s1_4",
          "name": "象山步道夕陽",
          "category": "自然步道",
          "time": "17:00",
          "stayTime": 75,
          "transit": "",
          "reason": "傍晚登頂正好能捕捉夕陽餘暉灑落 101 大樓的經典光影。"
        },
      ]
    },
    {
      "dayTitle": "day2",
      "spots": [
        {
          "id": "s2_1",
          "name": "華山1914文創園區",
          "category": "文創生活",
          "time": "10:00",
          "stayTime": 90,
          "transit": "步行約 12 分鐘",
          "reason": "老倉庫改建的藝文展區，充滿特色選品店與香醇咖啡香。"
        },
        {
          "id": "s2_2",
          "name": "永康街商圈",
          "category": "在地美食",
          "time": "12:00",
          "stayTime": 75,
          "transit": "捷運轉乘約 20 分鐘",
          "reason": "品嚐經典小籠包與芒果冰，享受愜意又具質感的午間漫遊。"
        },
        {
          "id": "s2_3",
          "name": "中正紀念堂",
          "category": "歷史地標",
          "time": "14:30",
          "stayTime": 60,
          "transit": "搭乘捷運約 15 分鐘",
          "reason": "壯闊的白牆藍瓦與整點衛兵交接，感受宏偉的都市建築景觀。"
        },
        {
          "id": "s2_4",
          "name": "師大夜市散策",
          "category": "夜市小吃",
          "time": "18:00",
          "stayTime": 90,
          "transit": "",
          "reason": "巷弄中的異國美食與平價服飾店，輕鬆體驗台北青春夜生活。"
        },
      ]
    },
    {
      "dayTitle": "day3",
      "spots": [
        {
          "id": "s3_1",
          "name": "淡水老街漫遊",
          "category": "老街懷舊",
          "time": "10:30",
          "stayTime": 90,
          "transit": "步行約 10 分鐘",
          "reason": "漫步在淡水河畔，邊吹海風邊品嚐阿給與魚酥。"
        },
        {
          "id": "s3_2",
          "name": "紅毛城古蹟群",
          "category": "歷史建築",
          "time": "13:00",
          "stayTime": 60,
          "transit": "公車約 15 分鐘",
          "reason": "磚紅色荷蘭城堡外觀，沉浸在淡水的百年歷史回憶中。"
        },
        {
          "id": "s3_3",
          "name": "漁人碼頭情人橋",
          "category": "浪漫夕陽",
          "time": "16:30",
          "stayTime": 90,
          "transit": "",
          "reason": "著名的落日勝地，橋上眺望出海口晚霞格外浪漫動人。"
        },
      ]
    }
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  // 🌟 核心拖曳調換邏輯
  void _onReorderSpots(int dayIndex, int oldIndex, int newIndex) {
    setState(() {
      final List<Map<String, dynamic>> spots =
          _daysData[dayIndex]["spots"] as List<Map<String, dynamic>>;

      if (newIndex > oldIndex) {
        newIndex -= 1; // 修正 Flutter Reorderable 下移時的偏移
      }
      final item = spots.removeAt(oldIndex);
      spots.insert(newIndex, item);
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(milliseconds: 900),
        content: Text('景點順序已即時更新 🔄'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 頂部退出/返回列 + AI 提示輸入框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: textDark.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: textDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // AI 膠囊輸入框
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: textDark.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _promptController,
                              style: const TextStyle(color: textDark, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: "想怎麼調整？加入景點？(輸入prompt)",
                                hintStyle: TextStyle(
                                  color: textDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.send_rounded, color: textDark, size: 18),
                            onPressed: () {
                              if (_promptController.text.trim().isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('已收到調整指令：「${_promptController.text}」')),
                                );
                                _promptController.clear();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // 2. 行程標題與動作列 (路線圖、匯出、編輯紀錄)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.tripTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('開啟路線地圖模式 🗺️')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.map_outlined, size: 14, color: textDark),
                          SizedBox(width: 4),
                          Text(
                            "路線圖",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildActionCapsule("匯出", onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('行程已匯出分享 📤')),
                    );
                  }),
                  const SizedBox(width: 6),
                  _buildActionCapsule("編輯\n紀錄", isMultiline: true, onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('開啟編輯紀錄 📝')),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 3. 核心：橫向滑動天數欄位（內部支援長按自由拖曳排序！）
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: _daysData.length,
                itemBuilder: (context, dayIndex) {
                  final day = _daysData[dayIndex];
                  final List<Map<String, dynamic>> spots =
                      day["spots"] as List<Map<String, dynamic>>;

                  return Container(
                    width: 230, // 給予拖曳足夠舒適的操作寬度
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: dayColumnBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: textDark.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 天數標題與長按拖曳小提示
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: cardBg.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                day["dayTitle"],
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // 🌟🌟 關鍵更換：ReorderableListView.builder 自由拖曳調換順序 🌟🌟
                        Expanded(
                          child: ReorderableListView.builder(
                            buildDefaultDragHandles: false, // 自訂手柄，長按整張卡片或手柄皆可拖曳
                            itemCount: spots.length,
                            onReorder: (oldIndex, newIndex) =>
                                _onReorderSpots(dayIndex, oldIndex, newIndex),
                            itemBuilder: (context, spotIndex) {
                              final spot = spots[spotIndex];
                              final String spotId = spot["id"];
                              final bool isLast = spotIndex == spots.length - 1;
                              final bool isExpanded = _expandedSpotIds.contains(spotId);

                              return Container(
                                key: ValueKey(spotId), // 👈 必須提供唯一 Key 供拖曳追蹤
                                child: Column(
                                  children: [
                                    // 景點卡片（包覆 ReorderableDelayedDragStartListener 達成按住拖曳）
                                    ReorderableDelayedDragStartListener(
                                      index: spotIndex,
                                      child: _buildSpotCard(
                                        spot: spot,
                                        stepIndex: spotIndex + 1,
                                        isExpanded: isExpanded,
                                        onToggleExpand: () {
                                          setState(() {
                                            if (isExpanded) {
                                              _expandedSpotIds.remove(spotId);
                                            } else {
                                              _expandedSpotIds.add(spotId);
                                            }
                                          });
                                        },
                                        onTapCard: () {
                                          final placeObj = Place(
                                            id: spotId,
                                            name: spot['name'],
                                            category: spot['category'] ?? '景點',
                                            description: spot['reason'] ?? '',
                                            address: '台北市推薦景點',
                                            latitude: 25.033,
                                            longitude: 121.565,
                                            image: '',
                                            stayTime: spot['stayTime'] ?? 60,
                                            rating: 4.8,
                                            tags: ['熱門', '推薦'],
                                            priceLevel: 1,
                                            estimatedCost: 100,
                                            openMinutes: 540,
                                            closeMinutes: 1080,
                                          );

                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => PlaceDetailPage(place: placeObj),
                                            ),
                                          );
                                        },
                                      ),
                                    ),

                                    // 站點之間的交通連線提示（自動依照新順序顯示）
                                    if (!isLast) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 1.5,
                                            height: 10,
                                            color: textDark.withValues(alpha: 0.25),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            spot['transit']?.isNotEmpty == true
                                                ? spot['transit']
                                                : "搭乘交通工具前往",
                                            style: TextStyle(
                                              color: textDark.withValues(alpha: 0.6),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // 頂部小膠囊按鈕
  Widget _buildActionCapsule(String text, {required VoidCallback onTap, bool isMultiline = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: isMultiline ? 2 : 5),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: textDark,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  // 單一景點卡片：時間軸 + 拖曳手柄圖示 + 青綠色展開卡片
  Widget _buildSpotCard({
    required Map<String, dynamic> spot,
    required int stepIndex,
    required bool isExpanded,
    required VoidCallback onToggleExpand,
    required VoidCallback onTapCard,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左側時間軸與站點編號
        Padding(
          padding: const EdgeInsets.only(top: 8.0, right: 6),
          child: Column(
            children: [
              Text(
                spot['time'] ?? '09:00',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: textDark,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  "$stepIndex",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 右側青綠景點卡片本體
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: textDark.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 上半部：景點名稱 + 右上角拖曳抓手提示 (drag handle)
                InkWell(
                  onTap: onTapCard,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "(${spot['name']})",
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ),
                        // 拖曳圖示提示使用者「這裡可以長按拖曳」
                        Icon(
                          Icons.drag_indicator_rounded,
                          size: 16,
                          color: textDark.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                ),

                // 分隔線
                Container(height: 1, color: dividerColor),

                // 下半部：推薦理由按鈕
                InkWell(
                  onTap: onToggleExpand,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isExpanded ? "收合推薦理由" : "查看推薦理由\n(向下展開)",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: textDark,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: textDark,
                        ),
                      ],
                    ),
                  ),
                ),

                // 展開內容
                if (isExpanded)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                    child: Text(
                      spot['reason'] ?? "暫無推薦說明",
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: textDark,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}