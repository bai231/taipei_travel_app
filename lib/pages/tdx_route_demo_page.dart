import 'package:flutter/material.dart';

import '../models/tdx_route.dart';
import '../services/tdx_service.dart';
import 'route_detail_page.dart';

class TdxRouteDemoPage extends StatefulWidget {
  const TdxRouteDemoPage({super.key});

  @override
  State<TdxRouteDemoPage> createState() => _TdxRouteDemoPageState();
}

class _TdxRouteDemoPageState extends State<TdxRouteDemoPage> {
  final TdxService _tdxService = TdxService();
  late Future<List<TdxRoute>> _routesFuture;

  @override
  void initState() {
    super.initState();
    _routesFuture = _loadRoutes();
  }

  Future<List<TdxRoute>> _loadRoutes() {
    return _tdxService.getRoutingOptions(
      origin: '25.016335,121.299596',
      destination: '25.047808,121.517068',
    );
  }

  void _reload() {
    setState(() => _routesFuture = _loadRoutes());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text(
          'TDX 路線規劃結果',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<TdxRoute>>(
        future: _routesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('載入失敗：${snapshot.error}'));
          }
          final routes = snapshot.data ?? const [];
          if (routes.isEmpty) {
            return const Center(child: Text('查無路線'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: routes.length,
            itemBuilder: (context, index) => _buildRouteCard(routes[index]),
          );
        },
      ),
    );
  }

  Widget _buildRouteCard(TdxRoute route) {
    final startTime = route.sections.isEmpty
        ? '--:--'
        : route.sections.first.departureTime ?? '--:--';
    final endTime = route.sections.isEmpty
        ? '--:--'
        : route.sections.last.arrivalTime ?? '--:--';
    final totalMinutes = (route.travelTime / 60).round();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        title: Text('$startTime — $endTime'),
        subtitle: Text(_routeSummary(route)),
        trailing: Text('$totalMinutes 分'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RouteDetailPage(route: route),
            ),
          );
        },
      ),
    );
  }

  String _routeSummary(TdxRoute route) {
    final labels = route.sections.map((section) {
      final mode = section.mode.toLowerCase();
      if (mode.contains('pedestrian') || mode == 'walking') return '步行';
      return section.lineName ?? section.mode;
    }).toList();
    return labels.join(' → ');
  }
}
