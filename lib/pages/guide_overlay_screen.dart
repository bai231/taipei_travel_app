import 'package:flutter/material.dart';

class GuideOverlayScreen extends StatefulWidget {
  final VoidCallback? onFinish;

  const GuideOverlayScreen({super.key, this.onFinish});

  @override
  State<GuideOverlayScreen> createState() => _GuideOverlayScreenState();
}

class _GuideOverlayScreenState extends State<GuideOverlayScreen> {
  int _currentStep = 0;

  // ============================================================
  // 📍 座標與步驟設定區（你可以在這裡自由調整數值與文案）
  // ============================================================
  final List<Map<String, dynamic>> _steps = [
    {
      'title': '使用指南與設定',
      'desc': '點擊這裡可以隨時再次開啟這份按鍵使用導引。',
      // 目標框位置: Rect.fromLTWH(左, 上, 寬, 高)
      'targetRect': const Rect.fromLTWH(210, 42, 95, 40),
      // 直線起點與終點: Offset(X, Y)
      'lineStart': const Offset(255, 85),
      'lineEnd': const Offset(255, 145),
      // 懸浮文字位置 (直接漂浮無邊框)
      'textTop': 155.0,
      'textLeft': 150.0,
      'textWidth': 210.0,
    },
    {
      'title': '一鍵智慧排程',
      'desc': '懶得手動排行程？點這裡輸入偏好，AI 立即為你自動規劃路線！',
      'targetRect': const Rect.fromLTWH(50, 480, 150, 50),
      'lineStart': const Offset(125, 480),
      'lineEnd': const Offset(125, 410),
      'textTop': 310.0,
      'textLeft': 40.0,
      'textWidth': 260.0,
    },
    {
      'title': '底部切換導航',
      'desc': '隨時在「首頁」、「行程安排」、「我的收藏」與「靈感搜尋」之間切換。',
      'targetRect': const Rect.fromLTWH(20, 740, 350, 60),
      'lineStart': const Offset(195, 740),
      'lineEnd': const Offset(195, 670),
      'textTop': 570.0,
      'textLeft': 40.0,
      'textWidth': 290.0,
    },
  ];

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      if (widget.onFinish != null) {
        widget.onFinish!();
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final Rect target = step['targetRect'];
    final Offset p1 = step['lineStart'];
    final Offset p2 = step['lineEnd'];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _nextStep, // 點擊螢幕任意處切換下一步
        child: Stack(
          children: [
            // 1. 半透明背景遮罩（保持背景清晰度）
            Container(
              color: const Color(0xFF1E3340).withValues(alpha: 0.45),
            ),

            // 2. 繪製純直線與目標按鍵外框（無圓點）
            CustomPaint(
              size: Size.infinite,
              painter: PureLineGuidePainter(
                targetRect: target,
                start: p1,
                end: p2,
                color: Colors.white,
              ),
            ),

            // 3. 純文字直接懸浮在畫面上（無 Card、無白框）
            Positioned(
              top: step['textTop'],
              left: step['textLeft'],
              width: step['textWidth'],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    step['title'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 6,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    step['desc'],
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.white.withValues(alpha: 0.95),
                      height: 1.45,
                      shadows: const [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 6,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _currentStep == _steps.length - 1 ? '點擊完成 ❯' : '點擊下一步 ❯',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8BB7D0), // 藍色系高亮提示字
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 4,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 4. 右上角「略過」按鈕
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '略過導引',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 繪製純線條與圓角目標框（已移除端點圓點）
class PureLineGuidePainter extends CustomPainter {
  final Rect targetRect;
  final Offset start;
  final Offset end;
  final Color color;

  PureLineGuidePainter({
    required this.targetRect,
    required this.start,
    required this.end,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final boxPaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // 1. 繪製按鈕的圓角外框
    final RRect rrect = RRect.fromRectAndRadius(
      targetRect.inflate(4),
      const Radius.circular(24),
    );
    canvas.drawRRect(rrect, boxPaint);

    // 2. 繪製純淨的延伸直線
    canvas.drawLine(start, end, linePaint);
  }

  @override
  bool shouldRepaint(covariant PureLineGuidePainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.start != start ||
        oldDelegate.end != end;
  }
}

/// 呼叫使用指南覆蓋層函式
void showUserGuide(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (BuildContext context, _, __) {
        return const GuideOverlayScreen();
      },
    ),
  );
}