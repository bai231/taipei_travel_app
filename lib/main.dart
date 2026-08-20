import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import 'models/place.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hvncnzimkefaqsngtykd.supabase.co',
    anonKey: 'sb_publishable_gS2PlPMA2sUxe7eOu3DXZA_-jaYiwPN',
  );

  await testSupabase();

  runApp(const TravelApp());
}

class TravelApp extends StatelessWidget {
  const TravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Travel App',

      theme: AppTheme.lightTheme,

      initialRoute: AppRoutes.home,

      routes: AppRoutes.routes,
    );
  }
}

Future<void> testSupabase() async {
  try {
    final List<dynamic> data = await Supabase.instance.client
        .from('places')
        .select();

    // 1. 將 JSON List 轉成 Place 物件 List
    final List<Place> places = data
        .map((json) => Place.fromJson(json))
        .toList();

    print('成功轉成物件，筆數：${places.length}');

    if (places.isNotEmpty) {
      final firstPlace = places.first;

      // 2. 檢查型別是否確實為 Place 物件
      print('物件型別：${firstPlace.runtimeType}'); // 應顯示 Place

      // 3. 印出關鍵屬性，檢查是「真實資料」還是「預設值」
      print('地點 ID：${firstPlace.id}');
      print('地點名稱：${firstPlace.name}');
      print('緯度：${firstPlace.latitude}');
      print('經度：${firstPlace.longitude}');
      print('標籤：${firstPlace.tags}');
    }
  } catch (e) {
    print('轉換失敗或發生錯誤：$e');
  }
}
