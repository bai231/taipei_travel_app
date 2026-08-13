import 'package:flutter/material.dart';
import 'services/tdx_service.dart';
import 'models/tdx_route.dart';
import 'pages/route_detail_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TDX Route App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const RouteHomePage(),
    );
  }
}

class RouteHomePage extends StatefulWidget {
  const RouteHomePage({super.key});

  @override
  State<RouteHomePage> createState() => _RouteHomePageState();
}

class _RouteHomePageState extends State<RouteHomePage> {
  late Future<List<TdxRoute>> _routesFuture;
  final TdxService _tdxService = TdxService();

  @override
  void initState() {
    super.initState();
    _routesFuture = _tdxService.getRoutingOptions(
      origin: '25.016335,121.299596',      // 桃園藝文特區
      destination: '25.047808,121.517068', // 台北車站
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('TDX 路線規劃結果', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: FutureBuilder<List<TdxRoute>>(
        future: _routesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('載入失敗: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('查無路線'));
          }

          final routes = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: routes.length,
            itemBuilder: (context, index) {
              final route = routes[index];
              return _buildRouteCard(context, route);
            },
          );
        },
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, TdxRoute route) {
    final firstSec = route.sections.firstWhere((s) => s.departureTime != null, orElse: () => route.sections.first);
    final lastSec = route.sections.lastWhere((s) => s.arrivalTime != null, orElse: () => route.sections.last);
    
    final startTime = firstSec.departureTime ?? '--:--';
    final endTime = lastSec.arrivalTime ?? '--:--';
    final totalMinutes = (route.travelTime / 60).round();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RouteDetailPage(route: route),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 時間與總花費時間
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$startTime — $endTime',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$totalMinutes 分',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 運具流程標籤列
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: route.sections.expand((section) {
                  final List<Widget> widgets = [];
                  final isWalk = section.mode == 'WALKING';

                  if (isWalk) {
                    widgets.add(const Icon(Icons.directions_walk, size: 18, color: Colors.grey));
                  } else if (section.mode == 'METRO' || section.mode == 'SUBWAY') {
                    widgets.add(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        section.lineName ?? '捷運',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ));
                  } else {
                    // BUS 或其他
                    widgets.add(const Icon(Icons.directions_bus, size: 18, color: Colors.blue));
                    if (section.lineName != null) {
                      widgets.add(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          section.lineName!,
                          style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ));
                    }
                  }

                  widgets.add(const Icon(Icons.chevron_right, size: 16, color: Colors.grey));
                  return widgets;
                }).toList()..removeLast(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}