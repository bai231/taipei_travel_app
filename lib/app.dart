import 'package:flutter/material.dart';
import 'pages/main_page.dart';

class TravelApp extends StatelessWidget {
  const TravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Taipei Travel",

      debugShowCheckedModeBanner: false,

      theme: ThemeData(colorSchemeSeed: Colors.blue),

      home: const MainPage(),
    );
  }
}
