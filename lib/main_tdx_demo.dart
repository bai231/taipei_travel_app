import 'package:flutter/material.dart';

import 'pages/tdx_route_demo_page.dart';

void main() {
  runApp(const TdxDemoApp());
}

class TdxDemoApp extends StatelessWidget {
  const TdxDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TDX Route App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TdxRouteDemoPage(),
    );
  }
}
