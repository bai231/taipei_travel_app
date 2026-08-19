import 'package:flutter/material.dart';

import '../pages/main_page.dart'; 
import '../pages/home_page.dart';
import '../pages/search_page.dart';
// import '../pages/map_page.dart';
import '../pages/trip_page.dart';
import '../pages/profile_page.dart';
import '../pages/setting_page.dart';

class AppRoutes {
  static const String home = '/';
  static const String search = '/search';
  static const String trip = '/trip';
  static const String profile = '/profile';
  static const String setting = '/setting';

  static final Map<String, WidgetBuilder> routes = {
    home: (context) => const MainPage(),

    search: (context) => const SearchPage(),

    // map: (context) => const MapPage(),

    trip: (context) => const TripPage(),

    profile: (context) => const ProfilePage(),

    setting: (context) => const SettingsPage(),
  };
}