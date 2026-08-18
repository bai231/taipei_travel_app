import 'package:flutter/material.dart';

// 📍 1. 定義 GuideStep 類別（放在檔案最上方）
class GuideStep {
  final String title;
  final String desc;
  final Rect targetRect;
  final bool isUpwards;

  const GuideStep({
    required this.title,
    required this.desc,
    required this.targetRect,
    this.isUpwards = false,
  });
}

// 📍 2. 讓 GuideOverlayScreen 接收 steps 參數
class GuideOverlayScreen extends StatefulWidget {
  final List<GuideStep> steps;
  final VoidCallback? onFinish;

  const GuideOverlayScreen({
    super.key,
    required this.steps,
    this.onFinish,
  });

  @override
  State<GuideOverlayScreen> createState() => _GuideOverlayScreenState();
}

class _GuideOverlayScreenState extends State<GuideOverlayScreen> {
  int _currentStep = 0;

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
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
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    final step = widget.steps[_currentStep];
    final Rect target = step.targetRect;
    final bool isUpwards = step.isUpwards;
    final screenSize = MediaQuery.of(context).size;

    // 動態計算直線起點與終點
    final Offset p1 = isUpwards
        ? Offset(target.center.dx, target.top)
        : Offset(target.center.dx, target.bottom);

    final Offset p2 = isUpwards
        ? Offset(target.center.dx, target.top - 50)
        : Offset(target.center.dx, target.bottom + 50);

    // 動態計算文字懸浮位置
    final double textWidth = 240.0;
    final double textLeft = (target.center.dx - (textWidth / 2))
        .clamp(20.0, screenSize.width - textWidth - 20.0);

    final double textTop = isUpwards
        ? (p2.dy - 120).clamp(40.0, screenSize.height - 180.0)
        : (p2.dy + 10.0).clamp(40.0, screenSize.height - 180.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _nextStep,
        child: Stack(
          children: [
            // 半透明背景
            Container(
              color: const Color(0xFF1E3340).withValues(alpha: 0.45),
            ),

            // 繪製目標框與直線
            CustomPaint(
              size: Size.infinite,
              painter: PureLineGuidePainter(
                targetRect: target,
                start: p1,
                end: p2,
                color: Colors.white,
              ),
            ),

            // 懸浮文字說明
            Positioned(
              top: textTop,
              left: textLeft,
              width: textWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    step.title,
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
                    step.desc,
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
                    _currentStep == widget.steps.length - 1 ? '點擊完成 ❯' : '點擊下一步 ❯',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8BB7D0),
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

            // 右上角略過按鈕
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

    final RRect rrect = RRect.fromRectAndRadius(
      targetRect.inflate(4),
      const Radius.circular(24),
    );
    canvas.drawRRect(rrect, boxPaint);
    canvas.drawLine(start, end, linePaint);
  }

  @override
  bool shouldRepaint(covariant PureLineGuidePainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.start != start ||
        oldDelegate.end != end;
  }
}

/// 全域呼叫使用指南函式（供註冊完成或無特定錨點時直接呼叫）
void showUserGuide(BuildContext context) {
  // 建立預設導引步驟
  final screenSize = MediaQuery.of(context).size;
  final defaultSteps = [
    GuideStep(
      title: '歡迎來到旅行旅伴！',
      desc: '點擊任意處開始探索你的專屬行程，右上角可隨時再次開啟導引。',
      targetRect: Rect.fromLTWH(screenSize.width - 110, 40, 95, 40),
      isUpwards: false,
    ),
    GuideStep(
      title: '底部切換導航',
      desc: '隨時在「首頁」、「行程安排」、「我的收藏」與「靈感搜尋」之間切換。',
      targetRect: Rect.fromLTWH(20, screenSize.height - 70, screenSize.width - 40, 50),
      isUpwards: true,
    ),
  ];

  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (context, _, __) => GuideOverlayScreen(steps: defaultSteps),
    ),
  );
}