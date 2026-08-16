import 'package:flutter/material.dart';

import 'home_page.dart';
import 'search_page.dart';
import 'trip_page.dart';
import 'profile_page.dart';
import 'setting_page.dart';

import 'guide_overlay_screen.dart'; // 使用指南
import 'login_screen.dart';         // 登入頁面

import '../widgets/bottom_nav.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const TripPage(),
    const ProfilePage(),
    const SearchPage(),
    const SettingsPage(),
  ];

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
            onPressed: () => showUserGuide(context), // 呼叫指南疊層
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

  
