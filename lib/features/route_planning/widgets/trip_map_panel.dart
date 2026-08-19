import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../models/route_geometry_segment.dart';
import '../../../services/google_route_geometry_service.dart';
import '../../../services/map_service.dart';
import '../../../services/route_geometry_gateway.dart';
import '../../../services/route_geometry_normalizer.dart';
import '../models/route_day.dart';

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
  String? _routeError;
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
    if (oldWidget.day.day != widget.day.day) {
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
    final routePolylines = _routeSegments.isEmpty
        ? coordinates.length < 2
              ? <Polyline>{}
              : {_mapService.routePolylineForCoordinates(coordinates)}
        : _mapService.routePolylinesForSegments(_routeSegments);
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
        if (_isLoadingRoute)
          const Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _MapMessage(
              icon: Icons.alt_route,
              label: '正在載入實際交通路線…',
              showProgress: true,
            ),
          )
        else if (_routeError != null)
          const Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _MapMessage(
              icon: Icons.warning_amber,
              label: '實際路線載入失敗，暫以景點直線顯示。',
            ),
          )
        else
          const Positioned(left: 12, bottom: 12, child: _RouteLegend()),
      ],
    );
  }

  Future<void> _loadRouteGeometry() async {
    final requestVersion = ++_requestVersion;
    setState(() {
      _isLoadingRoute = true;
      _routeError = null;
      _routeSegments = const [];
      _routeTransfers = const [];
    });

    try {
      final segments = <RouteGeometrySegment>[];
      final transfers = <RouteGeometryTransfer>[];
      for (final leg in widget.day.travelLegs) {
        final routeGeometry = _geometryNormalizer.normalize(
          await _routeGeometryGateway.getTransitRoute(
            originLatitude: leg.origin.latitude,
            originLongitude: leg.origin.longitude,
            destinationLatitude: leg.destination.latitude,
            destinationLongitude: leg.destination.longitude,
            departureTime: leg.requestedDeparture,
          ),
        );
        segments.addAll(routeGeometry.segments);
        transfers.addAll(routeGeometry.transfers);
      }
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _routeSegments = segments;
        _routeTransfers = transfers;
        _isLoadingRoute = false;
        if (segments.isEmpty && widget.day.travelLegs.isNotEmpty) {
          _routeError = 'Google Routes 沒有回傳可用路徑。';
        }
      });
      await _focusRoute();
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _isLoadingRoute = false;
        _routeError = error.toString();
      });
      await _focusRoute();
    }
  }

  List<LatLng> get _displayCoordinates {
    if (_routeSegments.isEmpty) return _coordinates;
    return _routeSegments
        .expand(
          (segment) => segment.points.map(
            (point) => LatLng(point.latitude, point.longitude),
          ),
        )
        .toList();
  }

  List<LatLng> get _coordinates => [
    LatLng(widget.day.origin.latitude, widget.day.origin.longitude),
    ...widget.day.visits.map(
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
    ...widget.day.visits.map(
      (visit) => Marker(
        markerId: MarkerId('day-${widget.day.day}-${visit.place.id}'),
        position: LatLng(visit.place.latitude, visit.place.longitude),
        infoWindow: InfoWindow(
          title: '${visit.sequence}. ${visit.place.name}',
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _LegendItem(color: Color(0xFF616161), label: '步行'),
            SizedBox(width: 10),
            _LegendItem(color: Color(0xFFF57C00), label: '公車'),
            SizedBox(width: 10),
            _LegendItem(color: Color(0xFF1565C0), label: '捷運'),
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
