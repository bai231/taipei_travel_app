import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import 'models/place.dart';
import 'services/language_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

SupabaseClient get supabase => Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hvncnzimkefaqsngtykd.supabase.co',
    anonKey: 'sb_publishable_gS2PlPMA2sUxe7eOu3DXZA_-jaYiwPN',
  );

  runApp(const TravelApp());
}

class TravelApp extends StatelessWidget {
  const TravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 🌟 在外層監聽 LanguageService 的語系變化
    return ValueListenableBuilder<Locale>(
      valueListenable: LanguageService().currentLocale,
      builder: (context, currentLocale, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Travel App',

          // 🌟 動態切換當前語言（zh_TW / en_US）
          locale: currentLocale,

          // 🌟 註冊支援的語系
          supportedLocales: const [
            Locale('zh', 'TW'),
            Locale('en', 'US'),
          ],

          // 🌟 註冊 Flutter 內建元件（如彈窗、文字選單）的多語言支援
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          theme: AppTheme.lightTheme,

          initialRoute: AppRoutes.home,

          routes: AppRoutes.routes,
        );
      },
    );
  }
}
