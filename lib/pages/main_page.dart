import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page.dart';
//import 'search_page.dart';
import 'trip_page.dart';
import 'profile_page.dart';
import 'setting_page.dart';
import 'guide_overlay_screen.dart';
import 'login_screen.dart';
import '../services/language_service.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  User? _currentUser;
  late final StreamSubscription<AuthState> _authSubscription;

  final GlobalKey _guideBtnKey = GlobalKey();
  final GlobalKey _bottomNavKey = GlobalKey();

  final List<Widget> _pages = const [
    HomePage(),
    TripPage(),
    ProfilePage(),
    // SearchPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentUser = Supabase.instance.client.auth.currentUser;

    // 監聽登入/登出狀態，全域自動刷新右上角按鈕與名片
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _currentUser = data.session?.user;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

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

  void _startDynamicGuide() {
    final guideRect = _getWidgetRect(_guideBtnKey);
    final navRect = _getWidgetRect(_bottomNavKey);

    final List<GuideStep> steps = [];

    if (guideRect != null) {
      steps.add(GuideStep(
        title: LanguageService.tr(context, 'guide_settings_title'),
        desc: LanguageService.tr(context, 'guide_settings_desc'),
        targetRect: guideRect,
        isUpwards: false,
      ));
    }

    if (navRect != null) {
    steps.add(GuideStep(
      title: LanguageService.tr(context, 'guide_nav_title'),
      desc: LanguageService.tr(context, 'guide_nav_desc'),
      targetRect: navRect,
      isUpwards: true,
    ));
    }
    if (steps.isEmpty) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (context, _, _) => GuideOverlayScreen(steps: steps),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC7DEC8), // 淺綠水彩背景
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // 1. 使用指南按鈕
          TextButton.icon(
            key: _guideBtnKey,
            onPressed: _startDynamicGuide,
            icon: const Icon(
              Icons.menu_book_outlined,
              size: 20,
              color: Color(0xFF1E3A2F),
            ),
            label: Text(
              LanguageService.tr(context, 'guide'),
              style: TextStyle(
                color: Color(0xFF1E3A2F),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 2. 右上角：依據登入狀態切換（未登入顯示文字，已登入顯示頭像圖示）
          _currentUser == null
              ? TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: Text(
                    LanguageService.tr(context, 'login'),
                    style: TextStyle(
                      color: Color(0xFF1E3A2F),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1E3A2F), width: 1.5),
                      ),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Color(0xFF70B19B),
                        child: Icon(Icons.person_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _currentIndex = 3; // 點擊直接切換至設定/個人頁
                      });
                    },
                  ),
                ),
          const SizedBox(width: 8),
        ],
      ),
      // 頁面主體：使用 IndexedStack 保持各頁面狀態且不阻擋點擊
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      // 底部導航欄
      bottomNavigationBar: Container(
        key: _bottomNavKey,
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
            selectedItemColor: const Color(0xFF1E3A2F),
            unselectedItemColor: Colors.black38,
            selectedFontSize: 12,
            unselectedFontSize: 12,
  items: [
    BottomNavigationBarItem(
      icon: const Icon(Icons.home_rounded),
      label: LanguageService.tr(context, 'nav_home'),
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.auto_fix_high_rounded),
      label: LanguageService.tr(context, 'nav_trip'),
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.person_rounded),
      label: LanguageService.tr(context, 'nav_profile'),
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.settings_rounded),
      label: LanguageService.tr(context, 'nav_settings'),
    ),
  ],
          ),
        ),
      ),
    );
  }
}
