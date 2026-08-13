import 'package:flutter/material.dart';
import '../models/tdx_route.dart';

class RouteDetailPage extends StatefulWidget {
  final TdxRoute route;

  const RouteDetailPage({super.key, required this.route});

  @override
  State<RouteDetailPage> createState() => _RouteDetailPageState();
}

class _RouteDetailPageState extends State<RouteDetailPage> {
  // 記錄哪些路段被展開顯示經過站點
  final Map<int, bool> _expandedSections = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('路線詳細資訊'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 頂部捷徑圖示列
            _buildRouteSummaryHeader(widget.route),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),

            // Google Maps 風格路線時間軸
            _buildDetailedTimeline(widget.route),
          ],
        ),
      ),
    );
  }

  // 頂部路線總覽標籤
  Widget _buildRouteSummaryHeader(TdxRoute route) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: route.sections.expand((section) {
        final List<Widget> widgets = [];
        final isWalk = section.mode == 'pedestrian' || section.mode == 'cycle' || section.mode == 'drive';

        if (isWalk) {
          widgets.add(const Icon(Icons.directions_walk, size: 18, color: Colors.grey));
        } else {
          widgets.add(Icon(
            section.mode.contains('METRO') ? Icons.subway : Icons.directions_bus,
            size: 18,
            color: Colors.blue.shade700,
          ));
          if (section.lineName != null) {
            widgets.add(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  section.lineName!,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }
        }

        widgets.add(const Icon(Icons.chevron_right, size: 16, color: Colors.grey));
        return widgets;
      }).toList()..removeLast(),
    );
  }

  // 核心路線時間軸渲染器
  Widget _buildDetailedTimeline(TdxRoute route) {
    List<Widget> timelineItems = [];

    for (int i = 0; i < route.sections.length; i++) {
      final section = route.sections[i];
      final isWalk = section.mode == 'pedestrian' || section.mode == 'cycle' || section.mode == 'drive';
      final isExpanded = _expandedSections[i] ?? false;

      // 1. 出發站 / 起始點點位
      timelineItems.add(
        _buildStationNode(
          title: section.departureTitle ?? (i == 0 ? '出發點' : '乘車點'),
          time: section.departureTime,
          isOrigin: i == 0,
        ),
      );

      // 2. 移動過程 (步行 or 大眾運輸卡片)
      if (isWalk) {
        timelineItems.add(_buildWalkingSegment(section));
      } else {
        timelineItems.add(_buildTransitSegment(i, section, isExpanded));
      }

      // 3. 到達站 (最後一段路程顯示終點站名)
      if (i == route.sections.length - 1) {
        timelineItems.add(
          _buildStationNode(
            title: section.arrivalTitle ?? '目的地',
            time: section.arrivalTime,
            isDestination: true,
          ),
        );
      } else {
        // 4. 計算並加入「轉乘/等候時間」
        final nextSection = route.sections[i + 1];
        if (section.arrivalTime != null && nextSection.departureTime != null) {
          int waitMinutes = _calculateWaitTime(section.arrivalTime!, nextSection.departureTime!);
          if (waitMinutes > 0) {
            timelineItems.add(_buildWaitSegment(waitMinutes));
          }
        }
      }
    }

    return Column(children: timelineItems);
  }

  // 站點節點 (圓點 + 站名 + 右側時間)
  Widget _buildStationNode({
    required String title,
    String? time,
    bool isOrigin = false,
    bool isDestination = false,
  }) {
    Color nodeColor = Colors.grey.shade600;
    IconData iconData = Icons.circle_outlined;

    if (isOrigin) {
      nodeColor = Colors.green.shade700;
      iconData = Icons.circle;
    } else if (isDestination) {
      nodeColor = Colors.red.shade700;
      iconData = Icons.location_on;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 30,
          child: Icon(iconData, size: isDestination ? 22 : 16, color: nodeColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        if (time != null)
          Text(
            time,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          ),
      ],
    );
  }

  // 步行路段 (左側虛線 + 右側時間獨立計算)
  Widget _buildWalkingSegment(RouteSection section) {
    final int minutes = (section.travelTime / 60).round();
    final String walkDuration = minutes > 0 ? '$minutes 分鐘' : '1 分鐘內';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 左側點線 (Dotted/Dashed Line 效果)
          SizedBox(
            width: 30,
            child: Center(
              child: Container(
                width: 2,
                color: Colors.transparent,
                child: CustomPaint(
                  painter: DashedLinePainter(color: Colors.grey.shade400),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.directions_walk, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('步行', style: TextStyle(fontSize: 15, color: Colors.black87)),
                ],
              ),
            ),
          ),
          // 右側獨立計算的時間
          Text(
            walkDuration,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // 大眾運輸路段 (公車/捷運/火車/高鐵 + 點擊可收合/展開)
  Widget _buildTransitSegment(int index, RouteSection section, bool isExpanded) {
    final int minutes = (section.travelTime / 60).round();
    final String transitDuration = minutes > 0 ? '$minutes 分鐘' : '1 分鐘內';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左側實線
          SizedBox(
            width: 30,
            child: Center(
              child: Container(
                width: 4,
                color: Colors.green.shade600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 路線名稱標籤 + 目的地
                  Row(
                    children: [
                      Icon(
                        section.mode.contains('METRO') ? Icons.subway : Icons.directions_bus,
                        size: 20,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          section.lineName ?? '公車',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (section.destination != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            section.destination!,
                            style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 手動展開按鈕 / 小字提示
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _expandedSections[index] = !isExpanded;
                      });
                    },
                    child: Container(
                      color: Colors.transparent, // 增加點擊範圍
                      child: Row(
                        children: [
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$transitDuration (${section.stopCount} 站)',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 展開後顯示的詳細站點清單
                  if (isExpanded && section.intermediateStops.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: section.intermediateStops.map((stopName) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Icon(Icons.circle, size: 6, color: Colors.grey.shade400),
                                const SizedBox(width: 10),
                                Text(
                                  stopName,
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 右側獨立計算的時間
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Text(
              transitDuration,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  // 等候時間路段 (圖三：等候 XX 分鐘)
  Widget _buildWaitSegment(int waitMinutes) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 30,
            child: Center(
              child: Container(
                width: 2,
                color: Colors.transparent,
                child: CustomPaint(
                  painter: DashedLinePainter(color: Colors.grey.shade400),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 18, color: Colors.black54),
                  const SizedBox(width: 8),
                  Text(
                    '等候 $waitMinutes 分鐘',
                    style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 計算兩時間字串 (HH:mm) 差值的 Helper
  int _calculateWaitTime(String arrivalStr, String nextDepartureStr) {
    try {
      final arrParts = arrivalStr.split(':').map(int.parse).toList();
      final depParts = nextDepartureStr.split(':').map(int.parse).toList();

      final arrMin = arrParts[0] * 60 + arrParts[1];
      final depMin = depParts[0] * 60 + depParts[1];

      int diff = depMin - arrMin;
      return diff > 0 ? diff : 0;
    } catch (_) {
      return 0;
    }
  }
}

// 繪製虛線的 CustomPainter (用於步行與等候路段)
class DashedLinePainter extends CustomPainter {
  final Color color;

  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    double dashHeight = 4, dashSpace = 4, startY = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;

    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}