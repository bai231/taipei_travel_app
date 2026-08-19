import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../services/map_service.dart';
import '../models/route_day.dart';

class TripMapPanel extends StatefulWidget {
  final RouteDay day;

  const TripMapPanel({super.key, required this.day});

  @override
  State<TripMapPanel> createState() => _TripMapPanelState();
}

class _TripMapPanelState extends State<TripMapPanel> {
  final MapService _mapService = const MapService();
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(covariant TripMapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day.day != widget.day.day) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusRoute());
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
    return GoogleMap(
      initialCameraPosition: _mapService.initialCameraPosition(
        target: coordinates.first,
      ),
      markers: _markers,
      polylines: coordinates.length < 2
          ? const {}
          : {
              _mapService.routePolylineForCoordinates(coordinates),
            },
      onMapCreated: (controller) {
        _controller = controller;
        _focusRoute();
      },
    );
  }

  List<LatLng> get _coordinates => [
    LatLng(widget.day.origin.latitude, widget.day.origin.longitude),
    ...widget.day.visits.map(
      (visit) => LatLng(
        visit.place.latitude,
        visit.place.longitude,
      ),
    ),
  ];

  Set<Marker> get _markers => {
    Marker(
      markerId: MarkerId('day-${widget.day.day}-origin'),
      position: LatLng(
        widget.day.origin.latitude,
        widget.day.origin.longitude,
      ),
      infoWindow: InfoWindow(title: '起點：${widget.day.origin.name}'),
      icon: BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueAzure,
      ),
    ),
    ...widget.day.visits.map(
      (visit) => Marker(
        markerId: MarkerId('day-${widget.day.day}-${visit.place.id}'),
        position: LatLng(
          visit.place.latitude,
          visit.place.longitude,
        ),
        infoWindow: InfoWindow(
          title: '${visit.sequence}. ${visit.place.name}',
          snippet: visit.place.address,
        ),
      ),
    ),
  };

  Future<void> _focusRoute() async {
    final controller = _controller;
    if (controller == null) return;
    final coordinates = _coordinates;
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
