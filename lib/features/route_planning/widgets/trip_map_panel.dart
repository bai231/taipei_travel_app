import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../models/route_geometry_segment.dart';
import '../../../services/google_route_geometry_service.dart';
import '../../../services/map_service.dart';
import '../../../services/route_geometry_gateway.dart';
import '../../../services/route_geometry_normalizer.dart';
import '../models/route_day.dart';
import '../models/route_visit.dart';
import '../models/route_travel_mode.dart';

class TripMapPanel extends StatefulWidget {
  final RouteDay day;
  final RouteGeometryGateway? routeGeometryGateway;

  const TripMapPanel({super.key, required this.day, this.routeGeometryGateway});

  @override
  State<TripMapPanel> createState() => _TripMapPanelState();
}

class _TripMapPanelState extends State<TripMapPanel> {
  final MapService _mapService = const MapService();
  final RouteGeometryNormalizer _geometryNormalizer =
      const RouteGeometryNormalizer();
  late final RouteGeometryGateway _routeGeometryGateway;
  GoogleMapController? _controller;
  List<RouteGeometrySegment> _routeSegments = const [];
  List<RouteGeometryTransfer> _routeTransfers = const [];
  bool _isLoadingRoute = true;
  final Map<int, String> _failedLegs = {};
  final Set<int> _loadedLegs = {};
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _routeGeometryGateway =
        widget.routeGeometryGateway ?? const GoogleRouteGeometryService();
    _loadRouteGeometry();
  }

  @override
  void didUpdateWidget(covariant TripMapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.day, widget.day)) {
      _loadRouteGeometry();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coordinates = _coordinates;
    final routePolylines = _mapService.routePolylinesForSegments(
      _routeSegments,
    );
    for (final index in _failedLegs.keys) {
      final leg = widget.day.travelLegs[index];
      routePolylines.add(
        Polyline(
          polylineId: PolylineId('unavailable-$index'),
          points: [
            LatLng(leg.origin.latitude, leg.origin.longitude),
            LatLng(leg.destination.latitude, leg.destination.longitude),
          ],
          color: const Color(0xFFD32F2F),
          width: 3,
          patterns: [PatternItem.dash(4), PatternItem.gap(12)],
        ),
      );
    }
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: _mapService.initialCameraPosition(
            target: coordinates.first,
          ),
          markers: _markers,
          polylines: routePolylines,
          onMapCreated: (controller) {
            _controller = controller;
            _focusRoute();
          },
        ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapMessage(
                icon: Icons.info_outline,
                showProgress: _isLoadingRoute,
                label: [
                  '${_loadedLegs.length} 段已載入，${_failedLegs.length} 段無法取得路徑${_isLoadingRoute ? '（載入中）' : ''}',
                  if (widget.day.travelLegs.any(
                    (leg) => leg.travelMode == RouteTravelMode.transit,
                  ))
                    'Google 參考路線，可能與 TDX 班次不同。',
                  if (_failedLegs.isNotEmpty) '紅色虛線為示意連線，不代表可行走道路。',
                ].join('\n'),
              ),
              if (_failedLegs.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _showFailures,
                      child: const Text('查看原因'),
                    ),
                    FilledButton(
                      onPressed: _isLoadingRoute
                          ? null
                          : () => _loadRouteGeometry(retryOnly: true),
                      child: const Text('重試失敗路段'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const Positioned(left: 12, bottom: 12, child: _RouteLegend()),
      ],
    );
  }

  void _showFailures() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('無法取得路徑'),
        content: SingleChildScrollView(
          child: Text(
            _failedLegs.entries
                .map((entry) {
                  final leg = widget.day.travelLegs[entry.key];
                  return '${leg.origin.name} → ${leg.destination.name}\n${entry.value}';
                })
                .join('\n\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadRouteGeometry({bool retryOnly = false}) async {
    final requestVersion = ++_requestVersion;
    final day = widget.day;
    final indices = retryOnly
        ? _failedLegs.keys.toList()
        : List.generate(day.travelLegs.length, (index) => index);
    setState(() {
      _isLoadingRoute = true;
      if (!retryOnly) {
        _failedLegs.clear();
        _loadedLegs.clear();
        _routeSegments = [];
        _routeTransfers = [];
      }
    });

    for (final index in indices) {
      if (!mounted || requestVersion != _requestVersion) return;
      final leg = day.travelLegs[index];
      try {
        final routeGeometry = _geometryNormalizer.normalize(
          await _routeGeometryGateway.getRoute(
            originLatitude: leg.origin.latitude,
            originLongitude: leg.origin.longitude,
            destinationLatitude: leg.destination.latitude,
            destinationLongitude: leg.destination.longitude,
            departureTime: leg.requestedDeparture,
            travelMode: leg.travelMode,
          ),
        );
        if (!mounted || requestVersion != _requestVersion) return;
        if (routeGeometry.segments.isEmpty) {
          throw StateError('指定日期與交通方式沒有可用路徑。');
        }
        setState(() {
          _routeSegments.addAll(routeGeometry.segments);
          _routeTransfers.addAll(routeGeometry.transfers);
          _loadedLegs.add(index);
          _failedLegs.remove(index);
        });
      } catch (error) {
        if (!mounted || requestVersion != _requestVersion) return;
        setState(() => _failedLegs[index] = error.toString());
      }
    }
    if (!mounted || requestVersion != _requestVersion) return;
    setState(() => _isLoadingRoute = false);
    await _focusRoute();
  }

  List<LatLng> get _displayCoordinates {
    if (_routeSegments.isEmpty) return _coordinates;
    return [
      ..._coordinates,
      ..._routeSegments.expand(
        (segment) => segment.points.map(
          (point) => LatLng(point.latitude, point.longitude),
        ),
      ),
    ];
  }

  bool get _originIsFirstVisit =>
      widget.day.visits.isNotEmpty &&
      widget.day.origin.id == widget.day.visits.first.place.id;

  Iterable<RouteVisit> get _visitsAfterOrigin =>
      _originIsFirstVisit ? widget.day.visits.skip(1) : widget.day.visits;

  List<LatLng> get _coordinates => [
    LatLng(widget.day.origin.latitude, widget.day.origin.longitude),
    ..._visitsAfterOrigin.map(
      (visit) => LatLng(visit.place.latitude, visit.place.longitude),
    ),
  ];

  Set<Marker> get _markers => {
    Marker(
      markerId: MarkerId('day-${widget.day.day}-origin'),
      position: LatLng(widget.day.origin.latitude, widget.day.origin.longitude),
      infoWindow: InfoWindow(title: '起點：${widget.day.origin.name}'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    ),
    ..._visitsAfterOrigin.map(
      (visit) => Marker(
        markerId: MarkerId('day-${widget.day.day}-${visit.occurrenceId}'),
        position: LatLng(visit.place.latitude, visit.place.longitude),
        infoWindow: InfoWindow(
          title: '${visit.sequence}. ${visit.label}',
          snippet: visit.place.address,
        ),
      ),
    ),
    ..._routeTransfers.indexed.map(
      (entry) => Marker(
        markerId: MarkerId('day-${widget.day.day}-transfer-${entry.$1}'),
        position: LatLng(entry.$2.point.latitude, entry.$2.point.longitude),
        infoWindow: InfoWindow(
          title: entry.$2.label,
          snippet: '路線端點相距約 ${entry.$2.gapMeters.round()} 公尺',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      ),
    ),
  };

  Future<void> _focusRoute() async {
    final controller = _controller;
    if (controller == null) return;
    final coordinates = _displayCoordinates;
    if (coordinates.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(coordinates.first, 14),
      );
      return;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        _mapService.boundsForCoordinates(coordinates),
        48,
      ),
    );
  }
}

class _MapMessage extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool showProgress;

  const _MapMessage({
    required this.icon,
    required this.label,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showProgress)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class _RouteLegend extends StatelessWidget {
  const _RouteLegend();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Wrap(
          spacing: 10,
          runSpacing: 6,
          children: const [
            _LegendItem(color: Color(0xFF616161), label: '步行'),
            _LegendItem(color: Color(0xFFF57C00), label: '公車'),
            _LegendItem(color: Color(0xFF1565C0), label: '捷運'),
            _LegendItem(color: Color(0xFF7B1FA2), label: '台鐵'),
            _LegendItem(color: Color(0xFFC2185B), label: '高鐵'),
            _LegendItem(color: Color(0xFF2E7D32), label: '汽車'),
            _LegendItem(color: Color(0xFFD32F2F), label: '示意連線（虛線）'),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 18, height: 4, color: color),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
