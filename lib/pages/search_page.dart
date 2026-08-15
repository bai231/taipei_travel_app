import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();

  // 模擬熱門行程資料
  final List<Map<String, dynamic>> _popularTrips = [
    {
      "name": "台北文青一日遊",
      "count": 1280,
      "spots": ["華山文創", "松菸", "誠品南西", "赤峰街"]
    },
    {
      "name": "陽明山夜景之旅",
      "count": 950,
      "spots": ["擎天崗", "冷水坑", "文化後山", "士林夜市"]
    },
    {
      "name": "淡水老街休閒遊",
      "count": 820,
      "spots": ["紅毛城", "漁人碼頭", "淡水老街", "八里左岸"]
    },
    {
      "name": "信義區美食血拼",
      "count": 640,
      "spots": ["台北101", "微風南山", "象山步道", "臨江夜市"]
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD3E4DA), // 草圖的水綠色背景
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 頂部列：使用指南 & 登入
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.menu_book, color: Colors.black87, size: 20),
                    label: const Text(
                      "使用指南",
                      style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      "登入",
                      style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 2. 搜尋列 (草圖中的圓角搜尋框)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF7CB8A3), // 深綠色搜尋框背景
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: "搜尋行程...",
                    hintStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.search, color: Colors.white),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),

              const SizedBox(height: 20),

              // 3. 標題與排序按鈕：熱門行程 (排序方式) ⚙️
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "你可能會喜歡......",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  InkWell(
                    onTap: () {
                      // 點擊選擇排序方式
                    },
                    child: const Row(
                      children: [
                        Text(
                          "(排序方式)",
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.tune, size: 20, color: Colors.black87),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 4. 熱門行程卡片列表 (橫向滾動或網格雙排)
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _popularTrips.length,
                  itemBuilder: (context, index) {
                    final trip = _popularTrips[index];
                    return _buildTripTimelineCard(
                      name: trip["name"],
                      count: trip["count"],
                      spots: List<String>.from(trip["spots"]),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // 💡 草圖風格：帶有時間軸連接線的行程卡片
  Widget _buildTripTimelineCard({
    required String name,
    required int count,
    required List<String> spots,
  }) {
    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE5EFE9), // 稍微淺一點的綠白色卡片底色
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 行程名稱與使用次數
          Text(
            name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "(使用次數: $count)",
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),

          const SizedBox(height: 16),

          // 虛線 / 實線連接的景點時間軸
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(), // 停用內部滾動
              itemCount: spots.length,
              itemBuilder: (context, index) {
                final isLast = index == spots.length - 1;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左側時間軸圓點與連接線
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFF7CB8A3),
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 28,
                            color: const Color(0xFF7CB8A3).withOpacity(0.6),
                          ),
                      ],
                    ),

                    const SizedBox(width: 8),

                    // 右側景點名稱
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 0),
                        child: Text(
                          spots[index],
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}