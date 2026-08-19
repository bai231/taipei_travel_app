import 'package:flutter/material.dart';

import 'home_page.dart';
import 'search_page.dart';
import 'trip_page.dart';
import 'profile_page.dart';
import 'setting_page.dart';

import 'guide_overlay_screen.dart'; // 引入動態使用指南
import 'login_screen.dart';         // 登入頁面

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  // 📍 1. 宣告常駐元件的 GlobalKey
  final GlobalKey _guideBtnKey = GlobalKey(); // 頂部使用指南按鈕
  final GlobalKey _bottomNavKey = GlobalKey(); // 底部導航欄容器

  final List<Widget> _pages = [
    const HomePage(),
    const TripPage(),
    const ProfilePage(),
    const SearchPage(),
    const SettingsPage(),
  ];

  // 📍 2. 輔助函式：動態轉換 RenderBox 為螢幕實際 Rect 座標
  Rect? _getWidgetRect(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    final position = renderBox.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      renderBox.size.width,
      renderBox.size.height,
    );
  }

  // 📍 3. 動態取得座標並啟動導引
  void _startDynamicGuide() {
    final guideRect = _getWidgetRect(_guideBtnKey);
    final navRect = _getWidgetRect(_bottomNavKey);

    final List<GuideStep> steps = [];

    // 步驟 1：頂部使用指南
    if (guideRect != null) {
      steps.add(GuideStep(
        title: '使用指南與設定',
        desc: '點擊這裡可以隨時再次開啟這份按鍵使用導引說明。',
        targetRect: guideRect,
        isUpwards: false, // 向下展開說明文字
      ));
    }

    // 步驟 2：底部導航列
    if (navRect != null) {
      steps.add(GuideStep(
        title: '底部切換導航',
        desc: '隨時在「首頁」、「行程安排」、「我的收藏」與「靈感搜尋」之間自由切換。',
        targetRect: navRect,
        isUpwards: true, // 向上展開說明文字，避免被切掉
      ));
    }

    if (steps.isEmpty) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (context, _, __) => GuideOverlayScreen(steps: steps),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, // 透明背景，露出底色
        elevation: 0,                        // 去除陰影
        automaticallyImplyLeading: false,    // 不顯示預設返回按鈕
        actions: [
          // 左側/右側：使用指南按鈕
          TextButton.icon(
            key: _guideBtnKey, // 👈 綁定使用指南 Key
            onPressed: _startDynamicGuide, // 👈 點擊呼叫動態導引
            icon: const Icon(
              Icons.menu_book_outlined,
              size: 20,
              color: Color(0xFF1E3A2F),
            ),
            label: const Text(
              "使用指南",
              style: TextStyle(
                color: Color(0xFF1E3A2F),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 登入按鈕
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text(
              "登入",
              style: TextStyle(
                color: Color(0xFF1E3A2F),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        key: _bottomNavKey, // 👈 綁定底部導航 Key
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.black54,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: '首頁',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.auto_fix_high),
                label: '行程安排',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: '個人',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: '靈感',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: '設定',
              ),
            ],
          ),
        ),
      ),
    );
  }
}