import '../pages/home_page.dart';
import '../pages/search_page.dart';
//import '../pages/map_page.dart';
import '../pages/trip_page.dart';
import '../pages/profile_page.dart';
import '../pages/setting_page.dart';

class AppRoutes {
  static final pages = [
    const HomePage(),

    const SearchPage(),

    //const MapPage(),
    const TripPage(),

    const ProfilePage(),

    const SettingPage(),
  ];
}
