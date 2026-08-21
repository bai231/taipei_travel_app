import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

final supabase = Supabase.instance.client;

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
    final data = await Supabase.instance.client.from('places').select();

    print('Supabase 連線成功');
    print(data);
  } catch (e) {
    print('Supabase 發生錯誤：$e');
  }
}
