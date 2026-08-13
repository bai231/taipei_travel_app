import 'package:flutter/material.dart';

import 'home_page.dart';
import 'search_page.dart';
import 'trip_page.dart';
import 'profile_page.dart';
import 'setting_page.dart';
import 'map_page.dart';

import '../widgets/bottom_nav.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int currentIndex = 0;

  final List<Widget> pages = [
    const HomePage(),
    const TripPage(),
    const ProfilePage(),
    const SearchPage(),
    const MapPage(),
    const SettingPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],

      bottomNavigationBar: BottomNav(
        currentIndex: currentIndex,

        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
      ),
    );
  }
}
