import 'package:flutter/material.dart';
import 'pages/main_page.dart';
import 'theme/app_theme.dart';

class TravelApp extends StatelessWidget {
  const TravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Taipei Travel",

      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,

      home: const MainPage(),
    );
  }
}
